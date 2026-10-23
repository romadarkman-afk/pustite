class_name DayCheckpoint
extends RefCounted
## Безопасный JSON-снимок начала дня. Сохраняет игровые свойства, а ссылки на
## жителей кодирует их id, чтобы после загрузки они указывали на новые объекты.

const VERSION := 1


static func write(path: String, m: Match, director: Director, session: Dictionary) -> bool:
	if m == null or director == null or m.phase != Match.Phase.DAY:
		return false
	var people: Array[Dictionary] = []
	for v: Villager in m.villagers:
		people.append(_encode_object(v))
	var payload := {
		"version": VERSION,
		"day": m.day,
		"session": _encode(session),
		"match": _encode_object(m, ["rng", "village", "config"]),
		"director": _encode_object(director, ["rng", "m"]),
		"villagers": people,
		"map": m.village.resource_path if m.village != null else "",
		"config": _encode_object(m.config),
		"rng": {"seed": m.rng.seed, "state": m.rng.state},
		"director_rng": {"seed": director.rng.seed, "state": director.rng.state},
	}
	return _write_json(path, payload)


static func read(path: String) -> Dictionary:
	var payload := _read_unchecked(path)
	if valid(payload):
		return payload
	# Если процесс закрылся во время атомарной замены, достаём предыдущий полный снимок.
	payload = _read_unchecked(path + ".bak")
	return payload if valid(payload) else {}


static func valid(payload: Dictionary) -> bool:
	return int(payload.get("version", 0)) == VERSION \
		and int(payload.get("day", 0)) > 0 \
		and payload.get("match", null) is Dictionary \
		and payload.get("director", null) is Dictionary \
		and payload.get("villagers", null) is Array \
		and payload.get("session", null) is Dictionary \
		and payload.get("config", null) is Dictionary \
		and payload.get("rng", null) is Dictionary \
		and payload.get("director_rng", null) is Dictionary \
		and payload.get("map", null) is String


static func _read_unchecked(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var source := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(source)
	return parsed if parsed is Dictionary and valid(parsed) else {}


static func apply(m: Match, director: Director, payload: Dictionary) -> bool:
	if m == null or director == null or not valid(payload):
		return false
	var by_id: Dictionary[int, Villager] = {}
	for v: Villager in m.villagers:
		by_id[v.id] = v
	var saved_people: Array = payload.get("villagers", [])
	if saved_people.size() != m.villagers.size():
		return false
	for person: Variant in saved_people:
		if not person is Dictionary or not person.has("props"):
			return false
		var person_id := int(person.get("props", {}).get("id", -1))
		if not by_id.has(person_id):
			return false
		_apply_object(by_id[person_id], person, by_id)
	_apply_object(m, payload.get("match", {}), by_id)
	_apply_object(director, payload.get("director", {}), by_id)
	_apply_object(m.config, payload.get("config", {}), by_id)
	var rng_data: Dictionary = payload.get("rng", {})
	m.rng.seed = int(rng_data.get("seed", m.rng.seed))
	m.rng.state = int(rng_data.get("state", m.rng.state))
	var director_rng: Dictionary = payload.get("director_rng", {})
	director.rng.seed = int(director_rng.get("seed", director.rng.seed))
	director.rng.state = int(director_rng.get("state", director.rng.state))
	return m.day == int(payload.day) and m.phase == Match.Phase.DAY


static func decode(value: Variant) -> Variant:
	return _decode(value, null, {})


static func apply_resource(resource: Resource, encoded: Variant) -> void:
	_apply_object(resource, encoded, {})


static func clear(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(absolute)


static func _write_json(path: String, payload: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var parent := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not valid(_read_unchecked(temporary)):
		return false
	var backup := path + ".bak"
	var final_absolute := ProjectSettings.globalize_path(path)
	var backup_absolute := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(final_absolute, backup_absolute) != OK:
			return false
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), final_absolute)
	if rename_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup_absolute, final_absolute)
		return false
	return true


static func _encode_object(value: Object, skip: Array[String] = []) -> Dictionary:
	var props: Dictionary = {}
	for prop: Dictionary in value.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key := String(prop.name)
		if skip.has(key) or key == "m" or key == "_match_ref":
			continue
		var encoded: Variant = _encode(value.get(key))
		if encoded is Dictionary and encoded.has("$skip"):
			continue
		props[key] = encoded
	var script := value.get_script() as Script
	return {"$object": script.resource_path if script != null else "", "props": props}


static func _encode(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Villager:
		return {"$villager": value.id}
	if value is WorldLog.Event:
		return {"$world_event": _encode_object(value)}
	if value is NightReport.Entry:
		return {"$night_entry": _encode_object(value)}
	if value is Match.Seat:
		return {"$seat": _encode_object(value)}
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_encode(item))
		return {"$array": items}
	if value is Dictionary:
		var pairs: Array = []
		for key: Variant in value:
			pairs.append([_encode(key), _encode(value[key])])
		return {"$dict": pairs}
	if value is PackedInt32Array:
		return {"$packed_int32": Array(value)}
	if value is PackedInt64Array:
		return {"$packed_int64": Array(value)}
	if value is PackedFloat32Array:
		return {"$packed_float32": Array(value)}
	if value is PackedFloat64Array:
		return {"$packed_float64": Array(value)}
	if value is PackedByteArray:
		return {"$packed_byte": Array(value)}
	if value is PackedStringArray:
		return {"$packed_string": Array(value)}
	if value is PackedVector2Array:
		var points: Array = []
		for point: Vector2 in value:
			points.append(_encode(point))
		return {"$packed_vector2": points}
	if value is StringName:
		return {"$string_name": String(value)}
	if value is Vector2:
		return {"$vector2": [value.x, value.y]}
	if value is Vector2i:
		return {"$vector2i": [value.x, value.y]}
	if value is Color:
		return {"$color": [value.r, value.g, value.b, value.a]}
	if typeof(value) == TYPE_OBJECT:
		if value is RandomNumberGenerator or value is WeakRef:
			return {"$skip": true}
		if value is Resource:
			var resource_path: String = value.resource_path
			if not resource_path.is_empty():
				return {"$resource": resource_path, "props": _encode_object(value).props}
		var script := value.get_script() as Script
		if script == null or script.resource_path.is_empty():
			return {"$skip": true}
		return _encode_object(value)
	return value


static func _apply_object(target: Object, encoded: Variant, people: Dictionary) -> void:
	if target == null or not encoded is Dictionary or not encoded.has("props"):
		return
	for key_variant: Variant in encoded.props:
		var key := String(key_variant)
		var raw: Variant = encoded.props[key_variant]
		if raw is Dictionary and raw.has("$skip"):
			continue
		var current: Variant = target.get(key)
		var restored: Variant = _decode(raw, current, people)
		target.set(key, restored)


static func _decode(encoded: Variant, current: Variant, people: Dictionary) -> Variant:
	if not encoded is Dictionary:
		return encoded
	if encoded.has("$skip"):
		return current
	if encoded.has("$villager"):
		return people.get(int(encoded["$villager"]), null)
	if encoded.has("$array"):
		var items: Array = encoded["$array"]
		var result: Array = current if current is Array else []
		var previous := result.duplicate()
		result.clear()
		for i in range(items.size()):
			var old: Variant = previous[i] if i < previous.size() else null
			result.append(_decode(items[i], old, people))
		return result
	if encoded.has("$dict"):
		var result: Dictionary = current if current is Dictionary else {}
		var previous := result.duplicate(true)
		result.clear()
		for pair: Array in encoded["$dict"]:
			var key: Variant = _decode(pair[0], null, people)
			var old: Variant = previous.get(key, null)
			result[key] = _decode(pair[1], old, people)
		return result
	if encoded.has("$packed_int32"):
		return PackedInt32Array(encoded["$packed_int32"])
	if encoded.has("$packed_int64"):
		return PackedInt64Array(encoded["$packed_int64"])
	if encoded.has("$packed_float32"):
		return PackedFloat32Array(encoded["$packed_float32"])
	if encoded.has("$packed_float64"):
		return PackedFloat64Array(encoded["$packed_float64"])
	if encoded.has("$packed_byte"):
		return PackedByteArray(encoded["$packed_byte"])
	if encoded.has("$packed_string"):
		return PackedStringArray(encoded["$packed_string"])
	if encoded.has("$packed_vector2"):
		var points := PackedVector2Array()
		for point: Variant in encoded["$packed_vector2"]:
			points.append(_decode(point, null, people))
		return points
	if encoded.has("$string_name"):
		return StringName(encoded["$string_name"])
	if encoded.has("$vector2"):
		return Vector2(float(encoded["$vector2"][0]), float(encoded["$vector2"][1]))
	if encoded.has("$vector2i"):
		return Vector2i(int(encoded["$vector2i"][0]), int(encoded["$vector2i"][1]))
	if encoded.has("$color"):
		var c: Array = encoded["$color"]
		return Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	if encoded.has("$world_event"):
		var event: WorldLog.Event = current if current is WorldLog.Event else WorldLog.Event.new()
		_apply_object(event, encoded["$world_event"], people)
		return event
	if encoded.has("$night_entry"):
		var entry: NightReport.Entry = current if current is NightReport.Entry else NightReport.Entry.new()
		_apply_object(entry, encoded["$night_entry"], people)
		return entry
	if encoded.has("$seat"):
		var seat: Match.Seat = current if current is Match.Seat else Match.Seat.new()
		_apply_object(seat, encoded["$seat"], people)
		return seat
	if encoded.has("$resource"):
		var path := String(encoded["$resource"])
		var resource: Resource = current if current is Resource and current.resource_path == path else null
		if resource == null:
			var loaded: Resource = load(path) as Resource
			if loaded == null:
				return current
			resource = loaded.duplicate(true) as Resource
		_apply_object(resource, {"props": encoded.get("props", {})}, people)
		return resource
	if encoded.has("$object"):
		var path := String(encoded["$object"])
		var instance: Object = current
		var current_script := instance.get_script() as Script if instance != null else null
		if current_script == null or current_script.resource_path != path:
			var script := load(path) as Script
			if script == null:
				return current
			instance = script.new()
		_apply_object(instance, encoded, people)
		return instance
	return encoded
