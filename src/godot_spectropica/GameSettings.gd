extends Node
## Caretaker-controlled game settings. Cached locally so games still work offline.
## Games read these once at game start; they are not applied mid-session.

signal settings_changed
signal remote_refresh_finished(success: bool)

# PLACEHOLDERS: fill these in from Supabase > Project Settings > API.
const SUPABASE_URL := "https://akzvhkqadxbgsjcdoyxc.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_-SY1huPQs4Smo0351x1vMg_js47-Y0Y"

const REMOTE_TIMEOUT_SEC := 2.0
const SAVE_PATH := "user://game_settings.cfg" # separate from Wallet's save.cfg
const MAX_DIFFICULTY := 4
const MAX_STIMULATION := 2

# Display names; the index equals the setting value.
const DIFFICULTY_LABELS := [
	"0: Whole dollars",
	"1: 50¢ steps",
	"2: 25¢ steps",
	"3: 5¢ steps",
	"4: Any cents",
]
const STIMULATION_LABELS := [
	"Low (plain background)",
	"Normal",
	"High",
]

var difficulty: int = 0 ## 0: integers ... 4: all decimals
var stimulation: int = 1 ## 0 low, 1 normal, 2 high
## Grocery items (see GroceryCatalog): included flag, name and a price per difficulty.
var grocery_items: Array = GroceryCatalog.default_items()
## Why the last push_to_remote() was refused before sending (empty if it wasn't).
var last_error := ""

var _is_fetching := false
var _is_writing := false


func _ready() -> void:
	load_data()
	refresh_from_remote() # not awaited: startup isn't blocked, cache is used meanwhile


## Clamps values, saves locally, and notifies listeners. new_items is optional;
## null keeps the current grocery items.
func set_settings(new_difficulty: int, new_stimulation: int, new_items = null) -> void:
	difficulty = clampi(new_difficulty, 0, MAX_DIFFICULTY)
	stimulation = clampi(new_stimulation, 0, MAX_STIMULATION)
	if new_items is Array:
		grocery_items = GroceryCatalog.normalize(new_items)
	save_data()
	settings_changed.emit()


## What the cashier game uses: included items, named as saved, priced for the
## current difficulty.
func get_grocery_entries() -> Array[GroceryEntry]:
	return GroceryCatalog.to_entries(grocery_items, difficulty)


## Fetches the settings row from Supabase. On success, updates values and the local
## cache via set_settings(). On any failure, the cached values are kept.
## Can be awaited: `await GameSettings.refresh_from_remote()`. Returns true on success.
func refresh_from_remote() -> bool:
	if _is_fetching:
		# Another fetch (e.g. from the home screen) is already running: wait for its result.
		return await remote_refresh_finished
	if not is_remote_configured():
		push_warning("GameSettings: Supabase URL/key not set, using cached settings.")
		return false

	_is_fetching = true
	print("GameSettings: fetching from Supabase...")
	var success := await _fetch_remote()
	_is_fetching = false
	print("GameSettings: fetch %s (difficulty=%d, stimulation=%d)" % ["OK" if success else "FAILED, using cache", difficulty, stimulation])
	remote_refresh_finished.emit(success)
	return success


func _fetch_remote() -> bool:
	var http := HTTPRequest.new()
	http.timeout = REMOTE_TIMEOUT_SEC
	add_child(http)

	var url := _settings_url("&select=difficulty,stimulation,grocery_items")
	var err := http.request(url, remote_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		push_warning("GameSettings: request failed to start: %s" % error_string(err))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("GameSettings: remote fetch failed (result %d, HTTP %d), using cache." % [result, code])
		return false

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array) or data.is_empty() or not (data[0] is Dictionary):
		push_warning("GameSettings: unexpected remote response, using cache.")
		return false

	var row: Dictionary = data[0]
	if not row.has("difficulty") or not row.has("stimulation"):
		push_warning("GameSettings: remote row missing fields, using cache.")
		return false

	# A null/invalid grocery_items (column not seeded yet) is not a failure: keep the cache.
	var remote_items = row.get("grocery_items")
	set_settings(int(row["difficulty"]), int(row["stimulation"]),
		remote_items if remote_items is Array else null)
	return true


## Called by the CTM Settings page. Writes difficulty, stimulation and (if given) the
## grocery items to Supabase in ONE request, and only on success updates this device's
## values and cache. Awaitable; returns true on success. If the items fail validation,
## nothing is sent, false is returned and last_error says why.
func push_to_remote(new_difficulty: int, new_stimulation: int, items: Array = []) -> bool:
	last_error = ""
	if _is_writing or not is_remote_configured():
		return false
	if not items.is_empty():
		last_error = GroceryCatalog.validate(items)
		if not last_error.is_empty():
			return false

	_is_writing = true
	var success := await _push_remote(
		clampi(new_difficulty, 0, MAX_DIFFICULTY),
		clampi(new_stimulation, 0, MAX_STIMULATION),
		GroceryCatalog.normalize(items) if not items.is_empty() else [])
	_is_writing = false
	return success


func _push_remote(d: int, s: int, items: Array) -> bool:
	var http := HTTPRequest.new()
	http.timeout = REMOTE_TIMEOUT_SEC
	add_child(http)

	var headers := remote_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: return=representation") # response lists the updated rows
	var payload := {"difficulty": d, "stimulation": s}
	if not items.is_empty():
		payload["grocery_items"] = items
	var body := JSON.stringify(payload)

	var err := http.request(_settings_url(), headers, HTTPClient.METHOD_PATCH, body)
	if err != OK:
		push_warning("GameSettings: write failed to start: %s" % error_string(err))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("GameSettings: remote write failed (result %d, HTTP %d)." % [result, code])
		return false

	# A PATCH that matches no row still returns 200 with an empty array.
	var data = JSON.parse_string(response[3].get_string_from_utf8())
	if not (data is Array) or data.is_empty():
		push_warning("GameSettings: remote write matched no row (is the id=1 row missing?).")
		return false

	set_settings(d, s, items if not items.is_empty() else null)
	return true


func is_remote_configured() -> bool:
	return not (SUPABASE_URL.contains("YOUR-") or SUPABASE_ANON_KEY.contains("YOUR-"))


func _settings_url(extra_query: String = "") -> String:
	return remote_url("game_settings?id=eq.1" + extra_query)


## Full REST URL for a table/query, e.g. remote_url("game_runs?on_conflict=id").
## Shared with RunLog so the project URL and key live in one place.
func remote_url(path: String) -> String:
	return SUPABASE_URL + "/rest/v1/" + path


func remote_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
	])


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("game_settings", "difficulty", difficulty)
	config.set_value("game_settings", "stimulation", stimulation)
	config.set_value("game_settings", "grocery_items", grocery_items)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("GameSettings save failed: %s" % error_string(err))


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		difficulty = clampi(config.get_value("game_settings", "difficulty", 0), 0, MAX_DIFFICULTY)
		stimulation = clampi(config.get_value("game_settings", "stimulation", 1), 0, MAX_STIMULATION)
		grocery_items = GroceryCatalog.normalize(config.get_value("game_settings", "grocery_items", null))
	settings_changed.emit()
