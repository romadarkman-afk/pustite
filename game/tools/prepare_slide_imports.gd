extends SceneTree

## Создаёт отсутствующие настройки импорта WebP-иллюстраций для CI и Android-сборок.
## Сжатие с потерями ограничивает размер текстур и должно применяться до импорта.

const SLIDE_ROOT := "res://assets/slides"

func _init() -> void:
	var images: Array[String] = []
	_collect_webp(SLIDE_ROOT, images)
	var created := 0
	for image_path: String in images:
		if FileAccess.file_exists(image_path + ".import"):
			continue
		if _write_import(image_path):
			created += 1
		else:
			push_error("Не удалось подготовить настройки импорта для %s" % image_path)
			quit(1)
			return
	print("Настройки импорта иллюстраций: добавлено %d, уже были заданы %d" % [created, images.size() - created])
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

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.93
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
""" % [uid, imported, source, imported]
	var output_path := ProjectSettings.globalize_path(source + ".import")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(sidecar)
	file.close()
	return true
