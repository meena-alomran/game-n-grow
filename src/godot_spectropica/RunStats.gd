class_name RunStats
extends RefCounted
## Pure helpers that turn run records (from RunLog / Supabase) into numbers and text.
## No state, so the charts step can reuse the same functions.
## Numbers read back from JSON are floats, so integer fields are cast with int().

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


## Totals across runs. Accuracy and first-try rate are -1.0 and avg_time_ms is -1 when
## there is nothing to measure. Average time counts completed runs only (a quit-early
## run's time isn't comparable); accuracy counts every run.
static func summarize(runs: Array) -> Dictionary:
	var completed := 0
	var completed_time_ms := 0
	var correct := 0
	var incorrect := 0
	var first_try := 0
	var orders := 0
	for r in runs:
		correct += int(r.get("correct_attempts", 0))
		incorrect += int(r.get("incorrect_attempts", 0))
		first_try += int(r.get("first_try_correct", 0))
		orders += int(r.get("orders_completed", 0))
		if r.get("completed", false):
			completed += 1
			completed_time_ms += int(r.get("total_time_ms", 0))
	var attempts := correct + incorrect
	return {
		"runs": runs.size(),
		"completed_runs": completed,
		"avg_time_ms": (float(completed_time_ms) / completed) if completed > 0 else -1.0,
		"accuracy": (float(correct) / attempts) if attempts > 0 else -1.0,
		"first_try_rate": (float(first_try) / orders) if orders > 0 else -1.0,
	}


## One summary per (difficulty, stimulation) pair, sorted by difficulty then stimulation.
## Each entry also has "difficulty" and "stimulation".
static func group_by_settings(runs: Array) -> Array:
	var groups := {}
	for r in runs:
		var key := Vector2i(int(r.get("difficulty", 0)), int(r.get("stimulation", 1)))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(r)

	var keys := groups.keys()
	keys.sort()
	var out := []
	for key in keys:
		var summary := summarize(groups[key])
		summary["difficulty"] = key.x
		summary["stimulation"] = key.y
		out.append(summary)
	return out


## e.g. "Nov 26, 2:14 PM · 0: Whole dollars · Normal · 3/3 orders · 41.2s · 1 wrong"
static func run_line(run: Dictionary) -> String:
	var line := "%s · %s · %s · %d/%d orders · %s · %d wrong" % [
		format_started(str(run.get("started_at", ""))),
		difficulty_label(int(run.get("difficulty", 0))),
		stimulation_label(int(run.get("stimulation", 1))),
		int(run.get("orders_completed", 0)),
		int(run.get("orders_target", 3)),
		format_time(int(run.get("total_time_ms", 0))),
		int(run.get("incorrect_attempts", 0)),
	]
	if not run.get("completed", false):
		line += " (quit early)"
	return line


## Multi-line breakdown of one run, order by order.
static func run_detail(run: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Started: " + format_started(str(run.get("started_at", ""))))
	lines.append("Difficulty: " + difficulty_label(int(run.get("difficulty", 0))))
	lines.append("Stimulation: " + stimulation_label(int(run.get("stimulation", 1))))
	lines.append("Result: %d/%d orders, %s total, %d wrong attempt(s), %d first-try%s" % [
		int(run.get("orders_completed", 0)),
		int(run.get("orders_target", 3)),
		format_time(int(run.get("total_time_ms", 0))),
		int(run.get("incorrect_attempts", 0)),
		int(run.get("first_try_correct", 0)),
		"" if run.get("completed", false) else " (quit early)",
	])
	lines.append("")

	var orders = run.get("orders", [])
	if not (orders is Array) or orders.is_empty():
		lines.append("No order details recorded.")
		return "\n".join(lines)

	for o in orders:
		var first_input = o.get("time_to_first_input_ms")
		lines.append("Order %d: %d items, total $%.2f, %s, first input after %s, %d attempt(s)" % [
			int(o.get("order_index", 0)) + 1,
			int(o.get("item_count", 0)),
			float(o.get("correct_price", 0.0)),
			format_time(int(o.get("time_ms", 0))),
			"—" if first_input == null else format_time(int(first_input)),
			int(o.get("attempts_count", 0)),
		])
		for a in o.get("attempts", []):
			if a.get("correct", false):
				lines.append("    %s: right" % str(a.get("answer")))
			else:
				lines.append("    %s: wrong (off by %.2f)" % [str(a.get("answer")), float(a.get("error_amount", 0.0))])
	return "\n".join(lines)


# --- Chart helpers ---------------------------------------------------------

## Short chart-axis names (the full names are in GameSettings.*_LABELS).
const SHORT_DIFFICULTY := ["Whole", "50¢", "25¢", "5¢", "Any"]
const SHORT_STIMULATION := ["Low", "Normal", "High"]


## Oldest first. (The DB and RunLog return newest first.)
static func chronological(runs: Array) -> Array:
	var sorted := runs.duplicate()
	sorted.sort_custom(func(a, b):
		return str(a.get("started_at", "")).left(19) < str(b.get("started_at", "")).left(19))
	return sorted


## difficulty/stimulation of -1 mean "any".
static func filter_runs(runs: Array, difficulty: int = -1, stimulation: int = -1) -> Array:
	var out := []
	for r in runs:
		if difficulty >= 0 and int(r.get("difficulty", 0)) != difficulty:
			continue
		if stimulation >= 0 and int(r.get("stimulation", 1)) != stimulation:
			continue
		out.append(r)
	return out


## The newest n runs of an oldest-first list. n <= 0 means all.
static func last_n(runs_chrono: Array, n: int) -> Array:
	if n <= 0 or runs_chrono.size() <= n:
		return runs_chrono.duplicate()
	return runs_chrono.slice(runs_chrono.size() - n)


## The n runs just before the newest n of an oldest-first list (empty for "all" or
## when there are no earlier runs). Used for "vs previous 10" comparisons.
static func previous_window(runs_chrono: Array, n: int) -> Array:
	if n <= 0 or runs_chrono.size() <= n:
		return []
	var end := runs_chrono.size() - n
	return runs_chrono.slice(maxi(0, end - n), end)


## Correct / (correct + wrong) for one run, or -1.0 with no attempts.
static func run_accuracy(run: Dictionary) -> float:
	var correct := int(run.get("correct_attempts", 0))
	var attempts := correct + int(run.get("incorrect_attempts", 0))
	return float(correct) / attempts if attempts > 0 else -1.0


## Per-run chart series from an oldest-first list. Time is NAN for runs quit early
## (their time isn't comparable); accuracy is NAN only when a run has no attempts.
## Returns {"labels", "titles", "time_s", "accuracy"}.
static func run_series(runs_chrono: Array) -> Dictionary:
	var labels := []
	var titles := []
	var time_s := []
	var accuracy := []
	for r in runs_chrono:
		var started := str(r.get("started_at", ""))
		labels.append(format_short_date(started))
		titles.append(format_started(started))
		time_s.append(float(r.get("total_time_ms", 0)) / 1000.0 if r.get("completed", false) else NAN)
		var acc := run_accuracy(r)
		accuracy.append(acc if acc >= 0.0 else NAN)
	return {"labels": labels, "titles": titles, "time_s": time_s, "accuracy": accuracy}


## Summaries bucketed by an integer field ("difficulty" or "stimulation"), one per
## value 0..count-1 (empty buckets give runs = 0 and -1 metrics).
static func group_by_field(runs: Array, field: String, count: int) -> Array:
	var buckets := []
	for i in range(count):
		buckets.append([])
	for r in runs:
		var key := int(r.get(field, 0))
		if key >= 0 and key < count:
			buckets[key].append(r)
	var out := []
	for bucket in buckets:
		out.append(summarize(bucket))
	return out


## How current compares with the previous window: {"time", "accuracy", "first_try"},
## each {"text": String, "good": int} where good is 1 better / -1 worse / 0 neutral.
## Always spelled out in words so color is never the only signal.
static func deltas(current: Dictionary, previous: Dictionary, previous_count: int) -> Dictionary:
	var suffix := " vs previous %d" % previous_count
	return {
		"time": _delta_seconds(current["avg_time_ms"], previous["avg_time_ms"], suffix),
		"accuracy": _delta_points(current["accuracy"], previous["accuracy"], suffix),
		"first_try": _delta_points(current["first_try_rate"], previous["first_try_rate"], suffix),
	}


static func _delta_seconds(current: float, previous: float, suffix: String) -> Dictionary:
	if current < 0.0 or previous < 0.0:
		return {"text": "", "good": 0}
	var diff := (current - previous) / 1000.0
	if absf(diff) < 0.05:
		return {"text": "No change" + suffix, "good": 0}
	# Faster (lower) is better.
	return {"text": "%s %.1fs%s" % ["Up" if diff > 0.0 else "Down", absf(diff), suffix],
		"good": -1 if diff > 0.0 else 1}


static func _delta_points(current: float, previous: float, suffix: String) -> Dictionary:
	if current < 0.0 or previous < 0.0:
		return {"text": "", "good": 0}
	var diff := roundi((current - previous) * 100.0)
	if diff == 0:
		return {"text": "No change" + suffix, "good": 0}
	return {"text": "%s %d pts%s" % ["Up" if diff > 0 else "Down", absi(diff), suffix],
		"good": 1 if diff > 0 else -1}


## Per-order values for one run's bar charts. kind: "time" (seconds),
## "first_input" (seconds, NAN if unknown) or "wrong" (wrong attempts before the right one).
static func order_values(run: Dictionary, kind: String) -> Array:
	var values := []
	var orders = run.get("orders", [])
	if not (orders is Array):
		return values
	for o in orders:
		match kind:
			"time":
				values.append(float(o.get("time_ms", 0)) / 1000.0)
			"first_input":
				var t = o.get("time_to_first_input_ms")
				values.append(NAN if t == null else float(t) / 1000.0)
			"wrong":
				values.append(float(maxi(int(o.get("attempts_count", 1)) - 1, 0)))
	return values


## "Nov 26" in the device's local time.
static func format_short_date(iso: String) -> String:
	if iso.length() < 19:
		return ""
	var utc := Time.get_unix_time_from_datetime_string(iso.left(19))
	var local := utc + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%s %d" % [MONTHS[int(d["month"]) - 1], d["day"]]


static func difficulty_label(value: int) -> String:
	if value >= 0 and value < GameSettings.DIFFICULTY_LABELS.size():
		return GameSettings.DIFFICULTY_LABELS[value]
	return "Difficulty %d" % value


static func stimulation_label(value: int) -> String:
	if value >= 0 and value < GameSettings.STIMULATION_LABELS.size():
		return GameSettings.STIMULATION_LABELS[value]
	return "Stimulation %d" % value


static func format_time(ms: float) -> String:
	if ms < 0:
		return "—"
	return "%.1fs" % (ms / 1000.0)


static func format_percent(fraction: float) -> String:
	if fraction < 0.0:
		return "—"
	return "%d%%" % roundi(fraction * 100.0)


## ISO timestamps are UTC ("...Z" or "...+00:00"), so the first 19 characters are the
## UTC date-time. Converts to the device's local time, e.g. "Nov 26, 2:14 PM".
static func format_started(iso: String) -> String:
	if iso.length() < 19:
		return iso if not iso.is_empty() else "Unknown time"
	var utc := Time.get_unix_time_from_datetime_string(iso.left(19))
	var local := utc + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	var hour12: int = d["hour"] % 12
	if hour12 == 0:
		hour12 = 12
	return "%s %d, %d:%02d %s" % [
		MONTHS[int(d["month"]) - 1], d["day"], hour12, d["minute"],
		"AM" if d["hour"] < 12 else "PM",
	]
