class_name CashierRunTracker
extends RefCounted
## Tracks one cashier run (ORDERS_PER_RUN orders) and builds a record for RunLog.
## Knows nothing about storage or the network.

const ORDERS_PER_RUN := 3

var _difficulty := 0
var _stimulation := 1
var _started_at_unix := 0.0
var _started_ticks := 0
var _orders: Array[Dictionary] = []   # finished orders
var _current: Dictionary = {}         # order in progress, empty if none
var _incorrect_attempts := 0


func begin_run(difficulty: int, stimulation: int) -> void:
	_difficulty = difficulty
	_stimulation = stimulation
	_started_at_unix = Time.get_unix_time_from_system()
	_started_ticks = Time.get_ticks_msec()
	_orders.clear()
	_current = {}
	_incorrect_attempts = 0


## Starting a new order while one is unfinished (e.g. the debug skip key) discards it.
func start_order(item_count: int, correct_price: float) -> void:
	_current = {
		"order_index": _orders.size(),
		"item_count": item_count,
		"correct_price": correct_price,
		"started_ticks": Time.get_ticks_msec(),
		"first_input_ticks": -1,
		"attempts": [],
	}


func note_first_input() -> void:
	if _current.is_empty() or _current["first_input_ticks"] >= 0:
		return
	_current["first_input_ticks"] = Time.get_ticks_msec()


## Returns `correct` unchanged so callers can use it inline.
func record_attempt(answer: float, correct: bool) -> bool:
	if _current.is_empty():
		return correct
	# A submit implies the child entered something, even if no key signal arrived.
	note_first_input()
	_current["attempts"].append({
		"answer": answer,
		"correct": correct,
		"error_amount": absf(answer - _current["correct_price"]),
	})
	if not correct:
		_incorrect_attempts += 1
	return correct


func finish_order() -> void:
	if _current.is_empty():
		return
	var attempts: Array = _current["attempts"]
	var first_input: int = _current["first_input_ticks"]
	var started: int = _current["started_ticks"]
	_orders.append({
		"order_index": _current["order_index"],
		"item_count": _current["item_count"],
		"correct_price": _current["correct_price"],
		"time_ms": Time.get_ticks_msec() - started,
		"time_to_first_input_ms": (first_input - started) if first_input >= 0 else null,
		"attempts_count": attempts.size(),
		"first_try": attempts.size() == 1,
		"attempts": attempts,
	})
	_current = {}


func is_run_complete() -> bool:
	return _orders.size() >= ORDERS_PER_RUN


## True if the child did anything this run (used to save abandoned runs).
func has_progress() -> bool:
	if not _orders.is_empty() or _incorrect_attempts > 0:
		return true
	return not _current.is_empty() and not _current["attempts"].is_empty()


func build_record(completed: bool) -> Dictionary:
	var first_try_correct := 0
	for o in _orders:
		if o["first_try"]:
			first_try_correct += 1
	return {
		"game_id": "cashier",
		"started_at": Time.get_datetime_string_from_unix_time(int(_started_at_unix)) + "Z",
		"ended_at": Time.get_datetime_string_from_system(true) + "Z",
		"difficulty": _difficulty,
		"stimulation": _stimulation,
		"orders_target": ORDERS_PER_RUN,
		"orders_completed": _orders.size(),
		"completed": completed,
		"total_time_ms": Time.get_ticks_msec() - _started_ticks,
		"correct_attempts": _orders.size(),
		"incorrect_attempts": _incorrect_attempts,
		"first_try_correct": first_try_correct,
		"orders": _orders.duplicate(true),
	}
