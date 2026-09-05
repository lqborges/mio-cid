extends Node

const POEM_FORMULAS_PATH := "res://content/locales/poem_formulas.csv"
const STRINGS_PATH := "res://content/locales/strings.csv"
const DEFAULT_LOCALE := "es"

signal locale_changed(code: String)

var locale: String = DEFAULT_LOCALE
var _table: Dictionary = {}


func _ready() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)
	_reload()


func set_locale(code: String) -> void:
	var next := normalize_locale(code)
	if locale == next:
		TranslationServer.set_locale(next)
		return
	locale = next
	TranslationServer.set_locale(next)
	locale_changed.emit(next)


func normalize_locale(code: String) -> String:
	var raw := code.strip_edges().to_lower()
	if raw.begins_with("en"):
		return "en"
	if raw.begins_with("es"):
		return "es"
	return DEFAULT_LOCALE


func text(key: String) -> String:
	return text_in(key, locale)


func text_in(key: String, loc: String) -> String:
	if _table.is_empty():
		_reload()
	if not _table.has(key):
		return key
	var row: Dictionary = _table[key]
	var value := str(row.get(loc, ""))
	if value.is_empty() and loc != DEFAULT_LOCALE:
		value = str(row.get(DEFAULT_LOCALE, ""))
	return value if not value.is_empty() else key


func montaner_verse(key: String) -> String:
	if _table.is_empty():
		_reload()
	if not _table.has(key):
		return ""
	var row: Dictionary = _table[key]
	return str(row.get("montaner_verse", ""))


func _reload() -> void:
	_table.clear()
	_load_csv(POEM_FORMULAS_PATH)
	_load_csv(STRINGS_PATH)


func _load_poem_formulas() -> void:
	_reload()


func _load_csv(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Loc: missing %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Loc: cannot open %s" % path)
		return
	var header: PackedStringArray = file.get_csv_line()
	if header.is_empty() or header[0] != "key":
		push_warning("Loc: %s must start with key,es,en" % path)
		return
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.is_empty() or line[0].is_empty():
			continue
		var row: Dictionary = {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		_table[row["key"]] = row
