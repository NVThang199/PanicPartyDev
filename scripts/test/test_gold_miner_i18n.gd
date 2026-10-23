@tool
extends SceneTree

const EXPECTED_KEYS = [
	"MINIGAME_GOLD_MINER",
	"GOLD_MINER_RULES",
	"GOLD_MINER_CONTROLS_HINT"
]

const LOCALES = ["en", "vi", "es", "fr", "de", "pt_BR", "ru", "ja", "ko", "zh_CN", "it"]

func _init() -> void:
	print("--- Running Gold Miner i18n Unit Tests ---")

	# 1. Test CSV integrity
	var file = FileAccess.open("res://translations/translations.csv", FileAccess.READ)
	assert(file != null, "translations.csv must exist")

	var found_keys = {}
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		for key in EXPECTED_KEYS:
			if line.begins_with(key + ","):
				found_keys[key] = line
	file.close()

	for key in EXPECTED_KEYS:
		assert(found_keys.has(key), "translations.csv must contain key: " + key)
		var parts = found_keys[key].split(",")
		assert(parts.size() >= 12, "Key " + key + " must have at least 12 fields (key + 11 locales)")

	# 2. Test TranslationServer in engine
	for loc in LOCALES:
		TranslationServer.set_locale(loc)
		for key in EXPECTED_KEYS:
			var translated = tr(key)
			assert(translated != key, "Key '%s' should be translated for locale '%s'" % [key, loc])
			assert(translated.length() > 0, "Translation for '%s' in locale '%s' must not be empty" % [key, loc])

	# 3. Check specific translations
	TranslationServer.set_locale("en")
	assert(tr("MINIGAME_GOLD_MINER") == "Gold Miner 3D", "English name mismatch")
	assert(tr("GOLD_MINER_CONTROLS_HINT") == "Left Click / Space: Drop Hook", "English controls hint mismatch")
	assert(tr("GOLD_MINER_RULES").begins_with("Launch your hook"), "English rules mismatch")

	TranslationServer.set_locale("vi")
	assert(tr("MINIGAME_GOLD_MINER") == "Đào Vàng 3D", "Vietnamese name mismatch")
	assert(tr("GOLD_MINER_CONTROLS_HINT") == "Chuột trái / Phím cách: Thả móc", "Vietnamese controls hint mismatch")
	assert(tr("GOLD_MINER_RULES").begins_with("Phóng móc gắp"), "Vietnamese rules mismatch")

	print("TEST_GOLD_MINER_I18N_PASS")
	quit(0)
