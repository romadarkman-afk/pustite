extends RefCounted
## Профили экранов, перечисленные по моделям в документации проекта.
## Одна строка объединяет модели с одинаковым разрешением, DPI и категорией.

const PHONE_COMPACT := &"PHONE_COMPACT"
const PHONE_STANDARD := &"PHONE_STANDARD"
const PHONE_ULTRA_HIGH_RES := &"PHONE_ULTRA_HIGH_RES"
const FOLDABLE_INNER := &"FOLDABLE_INNER"
const TABLET_COMPACT := &"TABLET_COMPACT"
const TABLET_STANDARD := &"TABLET_STANDARD"
const TABLET_PRO_LARGE := &"TABLET_PRO_LARGE"

## models (через |), width, height, ppi, category
const _ROWS := [
	["Samsung Galaxy S7", 1440, 2560, 577, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S8|Samsung Galaxy S9", 1440, 2960, 570, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S10", 1440, 3040, 550, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S20", 1440, 3200, 563, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S21", 1080, 2400, 421, PHONE_STANDARD],
	["Samsung Galaxy S21 Ultra", 1440, 3200, 515, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S22|Samsung Galaxy S23", 1080, 2340, 425, PHONE_STANDARD],
	["Samsung Galaxy S22 Ultra|Samsung Galaxy S23 Ultra", 1440, 3088, 500, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy S24|Samsung Galaxy S25", 1080, 2340, 416, PHONE_STANDARD],
	["Samsung Galaxy S24 Ultra|Samsung Galaxy S25 Ultra|Samsung Galaxy S26 Ultra", 1440, 3120, 500, PHONE_ULTRA_HIGH_RES],
	["Samsung Galaxy Fold 1", 1536, 2152, 362, FOLDABLE_INNER],
	["Samsung Galaxy Z Fold 3", 1768, 2208, 374, FOLDABLE_INNER],
	["Samsung Galaxy Z Fold 5", 1812, 2176, 373, FOLDABLE_INNER],
	["Samsung Galaxy Z Fold 6|Samsung Galaxy Z Fold 7", 1856, 2160, 374, FOLDABLE_INNER],
	["Samsung Galaxy Z Flip 1", 1080, 2636, 425, FOLDABLE_INNER],
	["Samsung Galaxy Z Flip 5|Samsung Galaxy Z Flip 6|Samsung Galaxy Z Flip 7", 1080, 2640, 425, FOLDABLE_INNER],
	["Samsung Galaxy A50|Samsung Galaxy A54", 1080, 2340, 403, PHONE_STANDARD],
	["Samsung Galaxy A55", 1080, 2340, 390, PHONE_STANDARD],
	["Samsung Galaxy A51|Samsung Galaxy A52", 1080, 2400, 405, PHONE_STANDARD],
	["Samsung Galaxy Note 20 Ultra", 1440, 3088, 496, PHONE_ULTRA_HIGH_RES],
	["Apple iPhone SE (2016)", 640, 1136, 326, PHONE_COMPACT],
	["Apple iPhone 7|Apple iPhone 8|Apple iPhone SE (2020)|Apple iPhone SE (2022)", 750, 1334, 326, PHONE_COMPACT],
	["Apple iPhone 7 Plus|Apple iPhone 8 Plus", 1080, 1920, 401, PHONE_STANDARD],
	["Apple iPhone XR|Apple iPhone 11", 828, 1792, 326, PHONE_STANDARD],
	["Apple iPhone X|Apple iPhone XS|Apple iPhone 11 Pro", 1125, 2436, 458, PHONE_STANDARD],
	["Apple iPhone XS Max|Apple iPhone 11 Pro Max", 1242, 2688, 458, PHONE_ULTRA_HIGH_RES],
	["Apple iPhone 12 mini|Apple iPhone 13 mini", 1080, 2340, 476, PHONE_COMPACT],
	["Apple iPhone 12|Apple iPhone 12 Pro|Apple iPhone 13|Apple iPhone 13 Pro|Apple iPhone 14", 1170, 2532, 460, PHONE_STANDARD],
	["Apple iPhone 12 Pro Max|Apple iPhone 13 Pro Max|Apple iPhone 14 Plus", 1284, 2778, 458, PHONE_ULTRA_HIGH_RES],
	["Apple iPhone 14 Pro|Apple iPhone 15|Apple iPhone 15 Pro|Apple iPhone 16", 1179, 2556, 460, PHONE_STANDARD],
	["Apple iPhone 14 Pro Max|Apple iPhone 15 Plus|Apple iPhone 15 Pro Max|Apple iPhone 16 Plus", 1290, 2796, 460, PHONE_ULTRA_HIGH_RES],
	["Apple iPhone 16 Pro|Apple iPhone 17", 1206, 2622, 460, PHONE_ULTRA_HIGH_RES],
	["Apple iPhone 16 Pro Max|Apple iPhone 17 Pro Max", 1320, 2868, 460, PHONE_ULTRA_HIGH_RES],
	["Xiaomi Mi 6", 1080, 1920, 428, PHONE_STANDARD],
	["Xiaomi Mi 8", 1080, 2248, 402, PHONE_STANDARD],
	["Xiaomi Mi 9", 1080, 2340, 403, PHONE_STANDARD],
	["Xiaomi 13", 1080, 2400, 414, PHONE_STANDARD],
	["Xiaomi 14|Xiaomi 15|Xiaomi 16", 1200, 2670, 460, PHONE_ULTRA_HIGH_RES],
	["Xiaomi 13 Ultra|Xiaomi 14 Ultra|Xiaomi 15 Pro|Xiaomi 15 Ultra", 1440, 3200, 522, PHONE_ULTRA_HIGH_RES],
	["Xiaomi MIX Fold 3", 1916, 2160, 360, FOLDABLE_INNER],
	["Redmi Note 4", 1080, 1920, 401, PHONE_STANDARD],
	["Redmi Note 8 Pro", 1080, 2340, 395, PHONE_STANDARD],
	["Redmi Note 10 Pro|Redmi Note 12 Pro|POCO F3|POCO F5|POCO X3 Pro|POCO X4 Pro|POCO X5 Pro", 1080, 2400, 395, PHONE_STANDARD],
	["Redmi Note 13 Pro|Redmi Note 14 Pro|Redmi Note 15 Pro|POCO F6|POCO X6|POCO X6 Pro", 1220, 2712, 446, PHONE_ULTRA_HIGH_RES],
	["POCO F1", 1080, 2246, 403, PHONE_STANDARD],
	["POCO F5 Pro|POCO F6 Pro", 1440, 3200, 526, PHONE_ULTRA_HIGH_RES],
	["Oppo Find X3 Pro|Oppo Find X5 Pro|OnePlus 9 Pro|OnePlus 10 Pro|OnePlus 11", 1440, 3216, 525, PHONE_ULTRA_HIGH_RES],
	["Oppo Find X6 Pro|Oppo Find X7 Ultra|OnePlus 8 Pro|OnePlus 12|OnePlus 13", 1440, 3168, 510, PHONE_ULTRA_HIGH_RES],
	["Oppo Find X8 Pro", 1264, 2780, 450, PHONE_ULTRA_HIGH_RES],
	["Oppo Find N2", 1792, 1920, 370, FOLDABLE_INNER],
	["Oppo Find N3", 2268, 2440, 426, FOLDABLE_INNER],
	["Oppo Reno 2|Oppo Reno 3 Pro|OnePlus Nord", 1080, 2400, 402, PHONE_STANDARD],
	["Oppo Reno 11|Oppo Reno 12", 1080, 2412, 394, PHONE_STANDARD],
	["Oppo Reno 13", 1256, 2760, 460, PHONE_ULTRA_HIGH_RES],
	["OnePlus 7 Pro", 1440, 3120, 516, PHONE_ULTRA_HIGH_RES],
	["OnePlus Nord 4", 1240, 2772, 450, PHONE_ULTRA_HIGH_RES],
	["Vivo X50 Pro|Vivo X60 Pro", 1080, 2376, 398, PHONE_STANDARD],
	["Vivo X70 Pro+|Vivo X80 Pro|Vivo X90 Pro+|Vivo X100 Ultra", 1440, 3200, 517, PHONE_ULTRA_HIGH_RES],
	["Vivo X100 Pro|Vivo X200 Pro|Vivo V30|Vivo V40", 1260, 2800, 453, PHONE_ULTRA_HIGH_RES],
	["Vivo X Fold 3", 2200, 2480, 412, FOLDABLE_INNER],
	["Vivo V20|Vivo V21|Vivo V25|Vivo V27", 1080, 2400, 400, PHONE_STANDARD],
	["Google Pixel 1|Google Pixel 2", 1080, 1920, 441, PHONE_STANDARD],
	["Google Pixel 3a", 1080, 2220, 441, PHONE_STANDARD],
	["Google Pixel 4a", 1080, 2340, 443, PHONE_STANDARD],
	["Google Pixel 5a|Google Pixel 6|Google Pixel 7|Google Pixel 8|Google Pixel 6a|Google Pixel 7a|Google Pixel 8a", 1080, 2400, 420, PHONE_STANDARD],
	["Google Pixel 9", 1080, 2424, 422, PHONE_STANDARD],
	["Google Pixel 6 Pro|Google Pixel 7 Pro", 1440, 3120, 512, PHONE_ULTRA_HIGH_RES],
	["Google Pixel 8 Pro|Google Pixel 9 Pro XL", 1344, 2992, 488, PHONE_ULTRA_HIGH_RES],
	["Google Pixel 9 Pro", 1280, 2856, 495, PHONE_ULTRA_HIGH_RES],
	["Google Pixel Fold", 1840, 2208, 378, FOLDABLE_INNER],
	["Google Pixel 9 Pro Fold", 2076, 2152, 373, FOLDABLE_INNER],
	["Honor Magic 4 Pro|Honor Magic 5 Pro", 1312, 2848, 460, PHONE_ULTRA_HIGH_RES],
	["Honor Magic 6 Pro|Honor Magic 7 Pro", 1280, 2800, 453, PHONE_ULTRA_HIGH_RES],
	["Honor Magic V2|Honor Magic V3", 2156, 2344, 402, FOLDABLE_INNER],
	["Honor 90|Honor 100|Honor 200", 1200, 2664, 436, PHONE_ULTRA_HIGH_RES],
	["Honor X9b", 1200, 2652, 429, PHONE_ULTRA_HIGH_RES],
	["Honor X7|Motorola Moto G50", 720, 1600, 265, PHONE_COMPACT],
	["Huawei P20 Pro", 1080, 2240, 408, PHONE_STANDARD],
	["Huawei P30 Pro|Huawei Nova 9", 1080, 2340, 395, PHONE_STANDARD],
	["Huawei Mate 20 Pro", 1440, 3120, 538, PHONE_ULTRA_HIGH_RES],
	["Huawei Mate 60 Pro|Huawei Mate 70 Pro", 1260, 2720, 440, PHONE_ULTRA_HIGH_RES],
	["Huawei Pura 70 Pro|Huawei Pura 80 Pro", 1260, 2844, 460, PHONE_ULTRA_HIGH_RES],
	["Huawei Mate X3|Huawei Mate X5", 2224, 2496, 426, FOLDABLE_INNER],
	["Huawei Mate XT", 2232, 3184, 382, FOLDABLE_INNER],
	["Motorola Razr 40 Ultra|Motorola Razr 50 Ultra", 1080, 2640, 413, FOLDABLE_INNER],
	["Motorola Edge 50 Ultra", 1220, 2712, 446, PHONE_ULTRA_HIGH_RES],
	["Infinix Note 30|Infinix Hot 40 Pro|Tecno Spark 20 Pro", 1080, 2460, 396, PHONE_STANDARD],
	["Infinix Note 40 Pro|Infinix Zero 40|Tecno Camon 30 Pro", 1080, 2436, 393, PHONE_STANDARD],
	["Tecno Phantom V Fold", 2000, 2296, 388, FOLDABLE_INNER],
	["Apple iPad 9.7-inch (2018)|ASUS ZenPad 3S 10", 1536, 2048, 264, TABLET_STANDARD],
	["Apple iPad mini 5", 1536, 2048, 326, TABLET_COMPACT],
	["Apple iPad mini 6|Apple iPad mini 7", 1488, 2266, 326, TABLET_COMPACT],
	["Apple iPad 10.2-inch Gen 7|Apple iPad 10.2-inch Gen 8|Apple iPad 10.2-inch Gen 9", 1620, 2160, 264, TABLET_STANDARD],
	["Apple iPad 10.9-inch Gen 10|Apple iPad 10.9-inch Gen 11|Apple iPad Air 10.9-inch M1|Apple iPad Air 11-inch M2|Apple iPad Air 11-inch M3|Apple iPad Air 11-inch M4", 1640, 2360, 264, TABLET_STANDARD],
	["Apple iPad Pro 11-inch M1|Apple iPad Pro 11-inch M2", 1668, 2388, 264, TABLET_STANDARD],
	["Apple iPad Pro 11-inch OLED M4|Apple iPad Pro 11-inch OLED M5", 1668, 2420, 264, TABLET_STANDARD],
	["Apple iPad Pro 12.9-inch M1|Apple iPad Pro 12.9-inch M2|Apple iPad Air 13-inch", 2048, 2732, 264, TABLET_PRO_LARGE],
	["Apple iPad Pro 13-inch OLED M4|Apple iPad Pro 13-inch OLED M5", 2064, 2752, 264, TABLET_PRO_LARGE],
	["Samsung Galaxy Tab S4|Samsung Galaxy Tab S6|Samsung Galaxy Tab S7|Samsung Galaxy Tab S8|Samsung Galaxy Tab S9|Lenovo Tab P12 Pro|Huawei MatePad Pro 11-inch|Xiaomi Pad 5|Honor Pad 9|Oppo Pad", 1600, 2560, 274, TABLET_STANDARD],
	["Samsung Galaxy Tab S9 Ultra|Samsung Galaxy Tab S10 Ultra|Samsung Galaxy Tab S12 Ultra", 1848, 2960, 239, TABLET_PRO_LARGE],
	["Samsung Galaxy Tab S9 FE|Samsung Galaxy Tab S10 FE", 1440, 2304, 249, TABLET_STANDARD],
	["Samsung Galaxy Tab A7|Lenovo Tab P11|Lenovo Yoga Tab 11|Lenovo Tab M10 Plus|Amazon Fire Max 11|Huawei MatePad SE|Oppo Pad Air|Realme Pad|Honor Pad 8", 1200, 2000, 215, TABLET_STANDARD],
	["Samsung Galaxy Tab A8|Samsung Galaxy Tab A9+|Lenovo Tab M11|Amazon Fire HD 10", 1200, 1920, 215, TABLET_STANDARD],
	["Samsung Galaxy Tab A9", 800, 1340, 179, TABLET_COMPACT],
	["Amazon Fire 7", 600, 1024, 171, TABLET_COMPACT],
	["Amazon Fire HD 8", 800, 1280, 189, TABLET_COMPACT],
	["Lenovo Tab P11 Pro Gen 2", 1536, 2560, 266, TABLET_STANDARD],
	["Lenovo Tab P12", 1840, 2944, 273, TABLET_STANDARD],
	["Lenovo Yoga Tab 13", 1350, 2160, 196, TABLET_PRO_LARGE],
	["Huawei MatePad Pro 13.2-inch", 1920, 2880, 262, TABLET_PRO_LARGE],
	["Huawei MatePad 11.5 S PaperMatte", 1840, 2800, 291, TABLET_STANDARD],
	["Xiaomi Pad 6", 1800, 2880, 309, TABLET_STANDARD],
	["Xiaomi Pad 6S Pro", 2032, 3048, 294, TABLET_PRO_LARGE],
	["Xiaomi Pad 7|Xiaomi Pad 7 Pro|Xiaomi Pad 8 Pro", 2136, 3200, 345, TABLET_STANDARD],
	["Microsoft Surface Pro 7", 2736, 1824, 267, TABLET_PRO_LARGE],
	["Microsoft Surface Pro 8|Microsoft Surface Pro 9|Microsoft Surface Pro 10|Microsoft Surface Pro 11", 2880, 1920, 267, TABLET_PRO_LARGE],
	["ASUS ROG Flow Z13 FHD+", 1920, 1200, 169, TABLET_PRO_LARGE],
	["ASUS ROG Flow Z13 QHD+", 2560, 1600, 225, TABLET_PRO_LARGE],
	["Honor MagicPad 2", 1920, 3000, 290, TABLET_PRO_LARGE],
	["Oppo Pad 2", 2000, 2800, 296, TABLET_STANDARD],
]


static func profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Array in _ROWS:
		var names := PackedStringArray(String(row[0]).split("|", false))
		out.append({
			"models": names,
			"width": int(row[1]),
			"height": int(row[2]),
			"ppi": int(row[3]),
			"category": StringName(row[4]),
		})
	return out


static func model_map() -> Dictionary:
	var out: Dictionary = {}
	for profile: Dictionary in profiles():
		for model: String in profile.models:
			var item := profile.duplicate()
			item["model"] = model
			out[model] = item
	return out


static func profile_for_model(model: String) -> Dictionary:
	var wanted := model.strip_edges().to_lower()
	for profile: Dictionary in profiles():
		for name: String in profile.models:
			if name.to_lower() == wanted:
				var item := profile.duplicate()
				item["model"] = name
				return item
	return {}


static func profile_for_resolution(size: Vector2i, dpi: int = 0) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var match_count := 0
	for profile: Dictionary in profiles():
		var same := size.x == int(profile.width) and size.y == int(profile.height)
		var rotated := size.y == int(profile.width) and size.x == int(profile.height)
		if not same and not rotated:
			continue
		match_count += 1
		var score := absf(float(int(profile.ppi) - dpi)) if dpi > 0 else 0.0
		if score < best_score:
			best_score = score
			best = profile.duplicate()
			best["rotated"] = rotated
	if not best.is_empty():
		best["resolution_match_count"] = match_count
	return best


static func model_count() -> int:
	var count := 0
	for row: Array in _ROWS:
		count += String(row[0]).split("|", false).size()
	return count
