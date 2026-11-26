class_name GroceryCatalog
extends RefCounted
## The cashier's fixed set of grocery items: which 3D model each slug uses, plus the
## default name and a default price for each difficulty. The caretaker can include/exclude,
## rename and re-price items (stored in Supabase game_settings.grocery_items); new items
## can't be added because each needs a 3D model.
##
## One saved item looks like:
##   {"slug": "apple", "name": "Apple", "included": true, "prices": [1.0, 1.5, 1.25, 1.15, 1.19]}
## where prices[d] is the price at difficulty d (0-4).

const PRICE_COUNT := 5
const MAX_NAME_LENGTH := 20
const MIN_PRICE := 0.01
const MAX_PRICE := 999.99
## Price step per difficulty: whole dollars, 50 cents, 25 cents, 5 cents, any cents.
const PRICE_STEPS := [1.0, 0.5, 0.25, 0.05, 0.01]

const _ENTRY_DIR := "res://games/cashier/data/standard_groceries/"

## [slug, default name, default prices for difficulty 0..4]. Order here is the display order.
## The slug matches the resource file name: sg_<slug>.tres
const _DEFAULTS := [
	["apple", "Apple", [1.00, 1.50, 1.25, 1.15, 1.19]],
	["banana", "Banana", [2.00, 2.50, 2.75, 2.35, 2.29]],
	["bread", "Bread", [6.00, 6.50, 6.25, 6.45, 6.49]],
	["cheese_wheel", "Cheese", [8.00, 8.50, 8.75, 8.90, 8.79]],
	["eggs", "Eggs", [7.00, 7.50, 7.50, 7.20, 7.39]],
	["grapes", "Grapes", [5.00, 5.50, 5.25, 5.60, 5.45]],
	["milk", "Milk", [5.00, 5.00, 5.75, 5.10, 5.35]],
	["pear", "Pear", [3.00, 3.50, 3.25, 3.30, 3.17]],
	["orange", "Orange", [2.00, 2.00, 2.50, 2.25, 2.12]],
	["orange_juice", "Juice", [4.00, 4.50, 4.75, 4.95, 4.88]],
]

static var _entry_cache := {}


## All items, all included, with the default names and prices.
static func default_items() -> Array:
	var items := []
	for d in _DEFAULTS:
		items.append({"slug": d[0], "name": d[1], "included": true, "prices": d[2].duplicate()})
	return items


## Turns whatever was saved (null, partial, odd types) into a clean list: every catalog
## slug present once, in catalog order; unknown slugs dropped; missing items/prices
## filled from the defaults; numbers forced to float.
static func normalize(saved) -> Array:
	var by_slug := {}
	if saved is Array:
		for item in saved:
			if item is Dictionary and item.has("slug"):
				by_slug[str(item["slug"])] = item

	var out := []
	for item in default_items():
		var src = by_slug.get(item["slug"])
		if src is Dictionary:
			var saved_name := str(src.get("name", "")).strip_edges().left(MAX_NAME_LENGTH)
			if not saved_name.is_empty():
				item["name"] = saved_name
			item["included"] = bool(src.get("included", true))
			var saved_prices = src.get("prices")
			if saved_prices is Array:
				for i in range(mini(saved_prices.size(), PRICE_COUNT)):
					item["prices"][i] = float(saved_prices[i])
		out.append(item)
	return out


## Returns "" if the items can be saved, otherwise a message for the caretaker.
static func validate(items: Array) -> String:
	var included := 0
	for item in items:
		var item_name := str(item.get("name", "")).strip_edges()
		if item_name.is_empty() or item_name.length() > MAX_NAME_LENGTH:
			return "Every item needs a name of 1 to %d characters." % MAX_NAME_LENGTH
		var prices = item.get("prices", [])
		if not (prices is Array) or prices.size() != PRICE_COUNT:
			return "%s needs a price for every difficulty." % item_name
		for price in prices:
			if float(price) < MIN_PRICE - 0.0001 or float(price) > MAX_PRICE + 0.0001:
				return "%s has a price outside $%.2f to $%.2f." % [item_name, MIN_PRICE, MAX_PRICE]
		if item.get("included", true):
			included += 1
	if included == 0:
		return "Include at least one item."
	return ""


## What the cashier game uses: one GroceryEntry per included item, named as saved and
## priced for this difficulty (the 3D model comes from the item's .tres).
static func to_entries(items: Array, difficulty: int) -> Array[GroceryEntry]:
	var entries: Array[GroceryEntry] = []
	var level := clampi(difficulty, 0, PRICE_COUNT - 1)
	for item in items:
		if not item.get("included", true):
			continue
		var base := _entry_for(str(item["slug"]))
		if base == null:
			continue
		var entry := base.duplicate() as GroceryEntry
		entry.display_name = str(item["name"])
		entry.price = float(item["prices"][level])
		entries.append(entry)
	return entries


static func price_step(difficulty: int) -> float:
	return PRICE_STEPS[clampi(difficulty, 0, PRICE_COUNT - 1)]


static func _entry_for(slug: String) -> GroceryEntry:
	if not _entry_cache.has(slug):
		var path := _ENTRY_DIR + "sg_" + slug + ".tres"
		_entry_cache[slug] = load(path) as GroceryEntry if ResourceLoader.exists(path) else null
	return _entry_cache[slug]
