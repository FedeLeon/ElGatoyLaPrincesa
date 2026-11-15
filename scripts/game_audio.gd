extends Node
## Audio manager for original music, spatial woodland ambience, and gameplay cues.

const BUS_NAMES := ["Music", "Environment", "Player", "Enemies", "UI", "Voice"]
const MUSIC_TRACKS := {
	"title": preload("res://assets/audio/music/title_theme.ogg"),
	"forest": preload("res://assets/audio/music/forest_theme.ogg"),
	"sanctuary": preload("res://assets/audio/music/sanctuary_theme.ogg"),
}
const SOUNDS := {
	"staff_swing": preload("res://assets/audio/sfx/staff_swing.wav"),
	"staff_hit": preload("res://assets/audio/sfx/staff_hit.wav"),
	"dodge": preload("res://assets/audio/sfx/dodge.wav"),
	"guard": preload("res://assets/audio/sfx/guard.wav"),
	"arrow_release": preload("res://assets/audio/sfx/arrow_release.wav"),
	"arrow_impact": preload("res://assets/audio/sfx/arrow_impact.wav"),
	"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	"sigil_on": preload("res://assets/audio/sfx/sigil_on.wav"),
	"sigil_wrong": preload("res://assets/audio/sfx/sigil_wrong.wav"),
	"shrine_open": preload("res://assets/audio/sfx/shrine_open.wav"),
	"nimbo_call": preload("res://assets/audio/sfx/nimbo_call.wav"),
	"bandit_windup": preload("res://assets/audio/sfx/bandit_windup.wav"),
	"bandit_attack": preload("res://assets/audio/sfx/bandit_attack.wav"),
	"bandit_hit": preload("res://assets/audio/sfx/bandit_hit.wav"),
	"bandit_death": preload("res://assets/audio/sfx/bandit_death.wav"),
	"player_hurt": preload("res://assets/audio/sfx/player_hurt.wav"),
	"ui_hover": preload("res://assets/audio/sfx/ui_hover.wav"),
	"ui_confirm": preload("res://assets/audio/sfx/ui_confirm.wav"),
	"ui_pause": preload("res://assets/audio/sfx/ui_pause.wav"),
	"victory": preload("res://assets/audio/sfx/victory.wav"),
	"game_over": preload("res://assets/audio/sfx/game_over.wav"),
	"step_grass_1": preload("res://assets/audio/sfx/step_grass_1.wav"),
	"step_grass_2": preload("res://assets/audio/sfx/step_grass_2.wav"),
	"step_grass_3": preload("res://assets/audio/sfx/step_grass_3.wav"),
	"step_water_1": preload("res://assets/audio/sfx/step_water_1.wav"),
	"step_water_2": preload("res://assets/audio/sfx/step_water_2.wav"),
	"step_water_3": preload("res://assets/audio/sfx/step_water_3.wav"),
}
const EFFECT_BUSES := {
	"staff_swing": "Player", "staff_hit": "Enemies", "dodge": "Player", "guard": "Player",
	"arrow_release": "Player", "arrow_impact": "Enemies",
	"pickup": "UI", "sigil_on": "Environment", "sigil_wrong": "Environment",
	"shrine_open": "Environment", "nimbo_call": "Voice", "bandit_windup": "Enemies",
	"bandit_attack": "Enemies", "bandit_hit": "Enemies", "bandit_death": "Enemies",
	"player_hurt": "Player", "ui_hover": "UI", "ui_confirm": "UI", "ui_pause": "UI",
	"victory": "UI", "game_over": "UI",
}
const FOREST_AMBIENCE: AudioStream = preload("res://assets/audio/ambience/forest.ogg")
const STREAM_AMBIENCE: AudioStream = preload("res://assets/audio/ambience/stream.ogg")
const WATERFALL_AMBIENCE: AudioStream = preload("res://assets/audio/ambience/waterfall.ogg")
const VOICE_COUNT := 16

var _voices: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := -1
var _active_track := ""
var _music_tween: Tween
var _music_ducked := false
var _ambience_player: AudioStreamPlayer
var _world_loops: Array[AudioStreamPlayer3D] = []
var _voice_cursor := 0


func _ready() -> void:
	_ensure_buses()
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Musica%d" % index
		player.bus = "Music"
		player.volume_db = -40.0
		add_child(player)
		_music_players.append(player)
	for index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "VozEfecto%d" % index
		player.bus = "Player"
		add_child(player)
		_voices.append(player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbienteBosque"
	_ambience_player.bus = "Environment"
	_ambience_player.volume_db = -12.0
	add_child(_ambience_player)
	if GameSettings.has_method("_apply_audio"):
		GameSettings._apply_audio()


func _exit_tree() -> void:
	if is_instance_valid(_music_tween) and _music_tween.is_running():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
	for player in _voices:
		player.stop()
		player.stream = null
	stop_forest_ambience()


func _ensure_buses() -> void:
	for bus_name in BUS_NAMES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus(AudioServer.bus_count)
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func apply_settings(music_volume: float, effects_volume: float) -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("Player", effects_volume)
	_set_bus_volume("Enemies", effects_volume)
	_set_bus_volume("UI", effects_volume)
	_set_bus_volume("Voice", effects_volume)
	_set_bus_volume("Environment", effects_volume * 0.72)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.001)))


func play_menu_music() -> void:
	_music_ducked = false
	stop_forest_ambience()
	play_music("title")


func play_music(track_name: String, fade_seconds: float = 1.7) -> void:
	if not MUSIC_TRACKS.has(track_name) or _active_track == track_name:
		return
	var next_index := 0 if _active_music != 0 else 1
	var next_player := _music_players[next_index]
	var old_player: AudioStreamPlayer = _music_players[_active_music] if _active_music >= 0 else null
	if is_instance_valid(_music_tween) and _music_tween.is_running():
		_music_tween.kill()
	var music_stream: AudioStream = MUSIC_TRACKS[track_name]
	if music_stream is AudioStreamOggVorbis:
		(music_stream as AudioStreamOggVorbis).loop = true
	next_player.stop()
	next_player.stream = music_stream
	next_player.volume_db = -36.0
	next_player.play()
	_active_music = next_index
	_active_track = track_name
	var target_db := -7.0 if _music_ducked else 0.0
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(next_player, "volume_db", target_db, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(old_player) and old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", -36.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.set_parallel(false)
		_music_tween.tween_callback(_stop_music_player.bind(old_player))


func _stop_music_player(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null


func set_paused(is_paused: bool) -> void:
	_music_ducked = is_paused
	if _active_music < 0:
		return
	var player := _music_players[_active_music]
	var target_db := -8.0 if is_paused else 0.0
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, 0.32).set_trans(Tween.TRANS_SINE)


func enter_forest(parent: Node3D, waterfall_pools: Array[Vector3]) -> void:
	_music_ducked = false
	play_music("forest")
	if not _ambience_player.playing:
		_ambience_player.stream = FOREST_AMBIENCE
		if _ambience_player.stream is AudioStreamOggVorbis:
			(_ambience_player.stream as AudioStreamOggVorbis).loop = true
		_ambience_player.play()
	if _world_loops.is_empty():
		_add_world_loop(parent, STREAM_AMBIENCE, Vector3(0.0, 0.2, -12.0), "ArroyoCentro", 45.0, 10.0, -5.0)
		_add_world_loop(parent, STREAM_AMBIENCE, Vector3(-58.0, 0.2, -12.0), "ArroyoOeste", 45.0, 10.0, -5.0)
		_add_world_loop(parent, STREAM_AMBIENCE, Vector3(58.0, 0.2, -12.0), "ArroyoEste", 45.0, 10.0, -5.0)
		for index in waterfall_pools.size():
			_add_world_loop(parent, WATERFALL_AMBIENCE, waterfall_pools[index], "Cascada%d" % index, 68.0, 16.0, -6.0)


func stop_forest_ambience() -> void:
	if is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.stream = null
	for player in _world_loops:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_world_loops.clear()


func leave_forest() -> void:
	stop_forest_ambience()
	_active_track = "" if _active_track == "forest" else _active_track


func _add_world_loop(parent: Node3D, audio: AudioStream, at: Vector3, node_name: String, distance: float, unit_size: float, volume_db: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = audio
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
	player.bus = "Environment"
	player.max_distance = distance
	player.unit_size = unit_size
	player.volume_db = volume_db
	parent.add_child(player)
	player.global_position = at
	player.play()
	_world_loops.append(player)


func play_ui(sound_name: String, pitch_scale: float = 1.0) -> void:
	_play_2d(sound_name, pitch_scale, -2.0)


func play_at(sound_name: String, at: Vector3, parent: Node3D, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(sound_name) or not is_instance_valid(parent):
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SFX_%s" % sound_name
	player.stream = SOUNDS[sound_name]
	player.bus = _bus_for(sound_name)
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.max_distance = 45.0
	player.unit_size = 8.0
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _play_2d(sound_name: String, pitch_scale: float, volume_db: float) -> void:
	if not SOUNDS.has(sound_name) or _voices.is_empty():
		return
	var player: AudioStreamPlayer
	for index in _voices.size():
		var candidate_index := (_voice_cursor + index) % _voices.size()
		if not _voices[candidate_index].playing:
			player = _voices[candidate_index]
			_voice_cursor = (candidate_index + 1) % _voices.size()
			break
	if not is_instance_valid(player):
		player = _voices[_voice_cursor]
		_voice_cursor = (_voice_cursor + 1) % _voices.size()
	player.stop()
	player.stream = SOUNDS[sound_name]
	player.bus = _bus_for(sound_name)
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func _bus_for(sound_name: String) -> String:
	return String(EFFECT_BUSES.get(sound_name, "Player"))
