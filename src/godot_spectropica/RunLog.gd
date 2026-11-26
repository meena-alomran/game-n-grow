extends Node
## Saves game run records locally, then queues them for upload to Supabase (game_runs).
## Game-agnostic: any game can call RunLog.save_run(record).
##
## Local file: user://run_log.json  ->  {"device_id": "...", "runs": [ {..., "synced": bool} ]}
## Sync is retried on app start, after each saved run, and whenever sync_now() is called
## (the CTM screen does this on open). Uploads are idempotent because each run has a
## client-generated id and the request uses "ignore-duplicates".

signal sync_finished(success: bool)

const LOG_PATH := "user://run_log.json"
const LOG_TMP_PATH := "user://run_log.json.tmp"
const LOG_CORRUPT_PATH := "user://run_log.corrupt.json"
const SYNC_TIMEOUT_SEC := 5.0
const SYNC_BATCH_SIZE := 50
const MAX_SYNCED_HISTORY := 200 # unsynced runs are never dropped

## Columns that are integers in the DB. JSON read back from disk turns ints into
## floats ("2.0"), which Postgres rejects for smallint/int, so they're cast before upload.
const INT_FIELDS := [
	"difficulty", "stimulation", "orders_target", "orders_completed",
	"total_time_ms", "correct_attempts", "incorrect_attempts", "first_try_correct",
]

var device_id := ""
var _runs: Array = [] # oldest first
var _is_syncing := false


func _ready() -> void:
	_load()
	sync_now() # not awaited


## Stores a finished (or abandoned) run locally, then tries to upload the queue.
func save_run(record: Dictionary) -> void:
	var run := record.duplicate(true)
	run["id"] = _uuid()
	run["device_id"] = device_id
	run["synced"] = false
	_runs.append(run)
	_save()
	print("RunLog: saved %s run (difficulty=%s, stimulation=%s, %s/%s orders, %s wrong, %.1fs)" % [
		run.get("game_id", "?"), run.get("difficulty"), run.get("stimulation"),
		run.get("orders_completed"), run.get("orders_target"),
		run.get("incorrect_attempts"), float(run.get("total_time_ms", 0)) / 1000.0])
	sync_now() # not awaited


## Local run history, newest first. (Reading from the DB comes with the charts step.)
func get_local_runs() -> Array:
	var copy := _runs.duplicate(true)
	copy.reverse()
	return copy


## Uploads all unsynced runs in batches. Awaitable. Returns true if nothing is left
## queued afterward. Safe to call any time; overlapping calls are ignored because the
## running loop re-checks the queue after each batch.
func sync_now() -> bool:
	if _is_syncing:
		return false
	if not GameSettings.is_remote_configured():
		return false

	_is_syncing = true
	var success := true
	while true:
		var batch := _pending_batch()
		if batch.is_empty():
			break
		success = await _upload(batch)
		if not success:
			break
	_is_syncing = false

	if success:
		_trim_history()
		_save()
	sync_finished.emit(success)
	return success


## Reads the newest runs for the CTM dashboard. Flushes this device's queue first so its
## runs are included. Returns {"ok": bool, "runs": Array}; on failure the caller can fall
## back to get_local_runs(). (Currently all devices' runs; filter by device_id later.)
func fetch_remote_runs(limit: int = 200) -> Dictionary:
	if not GameSettings.is_remote_configured():
		return {"ok": false, "runs": []}

	await sync_now()

	var http := HTTPRequest.new()
	http.timeout = SYNC_TIMEOUT_SEC
	add_child(http)

	var path := "game_runs?select=*&game_id=eq.cashier&order=started_at.desc&limit=%d" % limit
	var err := http.request(GameSettings.remote_url(path), GameSettings.remote_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		push_warning("RunLog: fetch failed to start: %s" % error_string(err))
		http.queue_free()
		return {"ok": false, "runs": []}

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("RunLog: fetch failed (result %d, HTTP %d)." % [result, code])
		return {"ok": false, "runs": []}

	var data = JSON.parse_string(response[3].get_string_from_utf8())
	if not (data is Array):
		push_warning("RunLog: unexpected fetch response.")
		return {"ok": false, "runs": []}
	return {"ok": true, "runs": data}


func _pending_batch() -> Array:
	var batch := []
	for run in _runs:
		if not run.get("synced", false):
			batch.append(run)
			if batch.size() >= SYNC_BATCH_SIZE:
				break
	return batch


func _upload(batch: Array) -> bool:
	var payload := []
	for run in batch:
		var row: Dictionary = run.duplicate(true)
		row.erase("synced") # local-only flag, not a DB column
		for field in INT_FIELDS:
			if row.has(field):
				row[field] = int(row[field])
		payload.append(row)

	var http := HTTPRequest.new()
	http.timeout = SYNC_TIMEOUT_SEC
	add_child(http)

	var headers := GameSettings.remote_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: resolution=ignore-duplicates,return=minimal")

	var err := http.request(
		GameSettings.remote_url("game_runs?on_conflict=id"),
		headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		push_warning("RunLog: upload failed to start: %s" % error_string(err))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		var detail: String = response[3].get_string_from_utf8()
		push_warning("RunLog: upload failed (result %d, HTTP %d) %s. %d run(s) stay queued." % [
			result, code, detail.left(200), batch.size()])
		return false

	for run in batch:
		run["synced"] = true
	_save()
	print("RunLog: synced %d run(s)" % batch.size())
	return true


## Keep every unsynced run; keep only the newest MAX_SYNCED_HISTORY synced ones.
func _trim_history() -> void:
	var kept: Array = []
	var synced_seen := 0
	for i in range(_runs.size() - 1, -1, -1): # newest to oldest
		var run: Dictionary = _runs[i]
		if run.get("synced", false):
			synced_seen += 1
			if synced_seen > MAX_SYNCED_HISTORY:
				continue
		kept.push_front(run)
	_runs = kept


func _load() -> void:
	if FileAccess.file_exists(LOG_PATH):
		var file := FileAccess.open(LOG_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var data = JSON.parse_string(text)
			if data is Dictionary and data.get("runs") is Array:
				_runs = data["runs"]
				device_id = str(data.get("device_id", ""))
			else:
				push_warning("RunLog: run_log.json is corrupt, starting a new log (old copy kept as run_log.corrupt.json).")
				DirAccess.copy_absolute(
					ProjectSettings.globalize_path(LOG_PATH),
					ProjectSettings.globalize_path(LOG_CORRUPT_PATH))
	if device_id.is_empty():
		device_id = _uuid()
		_save()


## Writes to a temp file and renames it into place so a crash can't leave a half-written log.
func _save() -> void:
	var text := JSON.stringify({"device_id": device_id, "runs": _runs})
	var tmp := FileAccess.open(LOG_TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("RunLog: couldn't write log: %s" % error_string(FileAccess.get_open_error()))
		return
	tmp.store_string(text)
	tmp.close()

	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(LOG_TMP_PATH),
		ProjectSettings.globalize_path(LOG_PATH))
	if err != OK:
		# Rename can fail if the target exists on some platforms; fall back to a direct write.
		var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file == null:
			push_error("RunLog: couldn't save log: %s" % error_string(FileAccess.get_open_error()))
			return
		file.store_string(text)
		file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_TMP_PATH))


## Random UUID v4.
func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
