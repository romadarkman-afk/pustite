extends SceneTree

## Готовит настройки импорта WebP-иллюстраций для CI и Android-сборок.
## Сжатие с потерями ограничивает размер текстур и должно применяться до импорта.

const SLIDE_ROOT := "res://assets/slides"
const LOSSY_MODE := 1
const LOSSY_QUALITY := 0.93

func _init() -> void:
	var images: Array[String] = []
	_collect_webp(SLIDE_ROOT, images)
	var created := 0
	var updated := 0
	for image_path: String in images:
		var settings_path := image_path + ".import"
		var error := OK
		if FileAccess.file_exists(settings_path):
			var settings := ConfigFile.new()
			error = settings.load(settings_path)
			if error == OK and int(settings.get_value("params", "compress/mode", 0)) != LOSSY_MODE:
				settings.set_value("params", "compress/mode", LOSSY_MODE)
				settings.set_value("params", "compress/lossy_quality", LOSSY_QUALITY)
				error = settings.save(settings_path)
				if error == OK:
					updated += 1
		elif _write_import(image_path):
			created += 1
		else:
			error = ERR_CANT_CREATE
		if error != OK:
			push_error("Не удалось подготовить настройки импорта для %s (%s)" % [image_path, error_string(error)])
			quit(1)
			return
	print("Настройки импорта иллюстраций: добавлено %d, исправлено %d, уже были заданы %d" % [created, updated, images.size() - created - updated])
	quit(0)


func _collect_webp(directory: String, images: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("Не удалось открыть каталог %s" % directory)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory.path_join(entry)
			if dir.current_is_dir():
				_collect_webp(path, images)
			elif entry.to_lower().ends_with(".webp"):
				images.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _write_import(source: String) -> bool:
	var source_md5 := FileAccess.get_md5(ProjectSettings.globalize_path(source))
	if source_md5.is_empty():
		return false
	var stem := source.trim_prefix(SLIDE_ROOT + "/").get_basename().replace("/", "_")
	var imported := "res://.godot/imported/%s-%s.ctex" % [stem, source_md5]
	var uid := ResourceUID.id_to_text(ResourceUID.create_id_for_path(source))
	var sidecar := """[remap]

importer="texture"
type="CompressedTexture2D"
uid="%s"
path="%s"
metadata={
"vram_texture": false
}

[deps]

source_file="%s"
dest_files=["%s"]

[params]

compress/mode=%d
compress/high_quality=false
compress/lossy_quality=%s
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % [uid, imported, source, imported, LOSSY_MODE, str(LOSSY_QUALITY)]
	var output_path := ProjectSettings.globalize_path(source + ".import")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(sidecar)
	file.close()
	return true
