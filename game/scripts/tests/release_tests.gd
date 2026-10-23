class_name ReleaseTests
extends RefCounted
## TASK-097: выпуск в Google Play. Проверяется то, что можно проверить без сборки:
## оба пресета Android согласованы между собой и с project.godot, в файле нет ключей и паролей,
## в магазинной сборке нет лишних разрешений. Сама сборка AAB идёт в .github/workflows/aab.yml.

const MIN_TARGET_SDK := 36          ## Google Play: новые приложения и обновления с 31.08.2026 (продление до 01.11.2026)


static func run() -> void:
	var fails := PackedStringArray()
	var ok := 0
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	ok += SelfTest._expect(fails, err == OK, "export_presets.cfg не читается (код %d)" % err)
	if err != OK:
		SelfTest._finish(fails, ok, "ВЫПУСК", "")
		return
	var version := String(ProjectSettings.get_setting("application/config/version", "?"))
	var apk := "preset.0.options"
	var aab := "preset.1.options"
	ok += SelfTest._expect(fails, String(cfg.get_value("preset.0", "name", "")) == "Android", "пресет 0 не «Android» (его зовёт android.yml)")
	ok += SelfTest._expect(fails, String(cfg.get_value("preset.1", "name", "")) == "Android AAB", "пресет 1 не «Android AAB» (его зовёт aab.yml)")
	ok += SelfTest._expect(fails, String(cfg.get_value("preset.1", "export_path", "")).ends_with(".aab"), "у пресета AAB путь не на .aab")
	ok += SelfTest._expect(fails, not bool(cfg.get_value(apk, "gradle_build/use_gradle_build", true)), "APK для отладки должен идти без Gradle (быстрая сборка)")
	ok += SelfTest._expect(fails, bool(cfg.get_value(aab, "gradle_build/use_gradle_build", false)), "AAB возможен только с Gradle")
	ok += SelfTest._expect(fails, int(cfg.get_value(aab, "gradle_build/export_format", 0)) == 1, "формат экспорта AAB не Android App Bundle")
	var target := int(String(cfg.get_value(aab, "gradle_build/target_sdk", "0")))
	ok += SelfTest._expect(fails, target >= MIN_TARGET_SDK, "целевой API %d ниже требования Google Play %d" % [target, MIN_TARGET_SDK])
	for key: String in ["version/code", "version/name", "package/unique_name", "package/name", "screen/immersive_mode"]:
		ok += SelfTest._expect(fails, cfg.get_value(apk, key, "a") == cfg.get_value(aab, key, "b"), "%s различается в пресетах APK и AAB" % key)
	ok += SelfTest._expect(fails, String(cfg.get_value(apk, "version/name", "")) == version, "version/name %s не совпала с версией проекта %s" % [cfg.get_value(apk, "version/name", ""), version])
	ok += SelfTest._expect(fails, int(cfg.get_value(aab, "version/code", 0)) > 0, "нет version/code")
	ok += SelfTest._expect(fails, String(cfg.get_value(aab, "package/unique_name", "")) == "com.vladi.pustite", "идентификатор пакета изменён: Play его запоминает навсегда")
	ok += SelfTest._expect(fails, bool(cfg.get_value(aab, "architectures/arm64-v8a", false)), "в AAB нет arm64-v8a: Google Play требует 64 бита")
	# разрешения магазинной сборки: только вибрация
	ok += SelfTest._expect(fails, not bool(cfg.get_value(aab, "permissions/internet", true)), "в AAB включён доступ в сеть")
	ok += SelfTest._expect(fails, not bool(cfg.get_value(aab, "permissions/access_network_state", true)), "в AAB включено состояние сети")
	ok += SelfTest._expect(fails, PackedStringArray(cfg.get_value(aab, "permissions/custom_permissions", PackedStringArray())).is_empty(), "в AAB есть свои разрешения")
	# значки
	for key: String in ["main_192x192", "adaptive_foreground_432x432", "adaptive_background_432x432"]:
		var ip := String(cfg.get_value(aab, "launcher_icons/" + key, ""))
		ok += SelfTest._expect(fails, ip != "" and FileAccess.file_exists(ip), "у AAB нет значка %s" % key)
	# ключи и пароли в файле быть не должны
	var raw := FileAccess.get_file_as_string("res://export_presets.cfg")
	for needle: String in ["keystore/release", "keystore/debug", "release_password", "release_user", "storepass"]:
		ok += SelfTest._expect(fails, not raw.contains(needle), "в export_presets.cfg есть «%s»: пароли и ключи хранятся в секретах GitHub" % needle)
	SelfTest._finish(fails, ok, "ВЫПУСК", "пресеты APK и AAB согласованы, целевой API %d, разрешений нет, ключей в файле нет" % target)
