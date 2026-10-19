extends SceneTree
## godot --headless -s game/tools/check_pair.gd -- day.png night.png

const MAX_MISMATCH := 0.03


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Usage: check_pair.gd -- day.png night.png")
		quit(2)
		return
	var day := Image.new()
	var night := Image.new()
	if day.load(args[0]) != OK or night.load(args[1]) != OK:
		printerr("Could not read image pair")
		quit(2)
		return
	if day.get_size() != night.get_size():
		printerr("Image dimensions differ")
		quit(1)
		return
	var changed := 0
	var union_pixels := 0
	for y in range(day.get_height()):
		for x in range(day.get_width()):
			var a := day.get_pixel(x, y).a >= 0.5
			var b := night.get_pixel(x, y).a >= 0.5
			if a or b:
				union_pixels += 1
			if a != b:
				changed += 1
	var ratio := float(changed) / float(maxi(1, union_pixels))
	print("Mask difference: %.2f%%" % (ratio * 100.0))
	quit(0 if ratio <= MAX_MISMATCH else 1)
