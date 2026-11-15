extends Node
## Persistent, shared settings for the title menu and in-game pause menu.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MOUSE_SENSITIVITY := 0.0025

var master_volume := 0.8
var music_volume := 0.72
var effects_volume := 0.82
var mouse_sensitivity := DEFAULT_MOUSE_SENSITIVITY
var fullscreen := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("audio", "effects_volume", effects_volume)), 0.0, 1.0)
		mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.0005, 0.008)
		fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	_apply()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.008)
	_save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	_save()


func _apply() -> void:
	_apply_audio()
	_apply_display()


func _apply_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").apply_settings(music_volume, effects_volume)


func _apply_display() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
