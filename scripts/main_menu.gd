extends Control
## Illustrated title screen and entry point for the adventure.

var menu_content: Control
var options_panel: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameAudio.play_menu_music()
	_build_background()
	_build_menu()
	_build_options()


func _build_background() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "IlustracionDelBosque"
	backdrop.texture = load("res://assets/ui/title_forest_pixel_v2.png")
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.68, 1.0])
	gradient.colors = PackedColorArray([Color(0.015, 0.025, 0.023, 0.92), Color(0.025, 0.04, 0.03, 0.74), Color(0.025, 0.04, 0.03, 0.0)])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1280
	gradient_texture.height = 720
	gradient_texture.fill_from = Vector2(0, 0.5)
	gradient_texture.fill_to = Vector2(1, 0.5)
	var shade := TextureRect.new()
	shade.texture = gradient_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_menu() -> void:
	menu_content = Control.new()
	menu_content.name = "MenuPrincipal"
	menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_content)
	var overline := Label.new()
	overline.text = "UNA AVENTURA EN EL BOSQUE ANTIGUO"
	overline.position = Vector2(76, 108)
	overline.size = Vector2(570, 36)
	overline.add_theme_font_size_override("font_size", 16)
	overline.add_theme_color_override("font_color", Color("d8c99e"))
	menu_content.add_child(overline)
	var title := Label.new()
	title.text = "El gato y la\nPrincesa"
	title.position = Vector2(70, 145)
	title.size = Vector2(590, 168)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("fff0c9"))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.035, 0.025, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	menu_content.add_child(title)
	var description := Label.new()
	description.text = "Escucha la voz del bosque.\nEncuentra el camino al santuario."
	description.position = Vector2(76, 318)
	description.size = Vector2(480, 58)
	description.add_theme_font_size_override("font_size", 19)
	description.add_theme_color_override("font_color", Color("eee5d0"))
	menu_content.add_child(description)
	var buttons := VBoxContainer.new()
	buttons.name = "Botones"
	buttons.position = Vector2(76, 407)
	buttons.size = Vector2(355, 190)
	buttons.add_theme_constant_override("separation", 13)
	menu_content.add_child(buttons)
	var start := _make_button("Iniciar aventura", true)
	buttons.add_child(start)
	start.pressed.connect(_start_adventure)
	var options := _make_button("Opciones", false)
	buttons.add_child(options)
	options.pressed.connect(_open_options)
	var exit := _make_button("Salir del juego", false)
	buttons.add_child(exit)
	exit.pressed.connect(func() -> void: get_tree().quit())
	start.grab_focus()
	var credits := Label.new()
	credits.text = "Una historia original de El gato y la Princesa"
	credits.position = Vector2(76, 662)
	credits.size = Vector2(610, 24)
	credits.add_theme_font_size_override("font_size", 13)
	credits.add_theme_color_override("font_color", Color("c7c4b3"))
	menu_content.add_child(credits)


func _build_options() -> void:
	options_panel = Control.new()
	options_panel.set_script(preload("res://scripts/options_panel.gd"))
	options_panel.visible = false
	add_child(options_panel)
	options_panel.connect("back_requested", _close_options)


func _open_options() -> void:
	menu_content.visible = false
	options_panel.visible = true


func _close_options() -> void:
	options_panel.visible = false
	menu_content.visible = true
	var start := menu_content.get_node("Botones") as VBoxContainer
	(start.get_child(0) as Button).grab_focus()


func _start_adventure() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		push_error("No se pudo iniciar la aventura: %s" % error_string(error))


func _make_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(355, 56)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("f6efd9"))
	button.add_theme_color_override("font_hover_color", Color("fff6d7"))
	button.add_theme_color_override("font_pressed_color", Color("f0dfa9"))
	button.add_theme_stylebox_override("normal", _button_style(Color("53634a") if primary else Color(0.09, 0.15, 0.12, 0.92)))
	button.add_theme_stylebox_override("hover", _button_style(Color("7a7048")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("394a3c")))
	button.add_theme_stylebox_override("focus", _button_style(Color("665b3d")))
	button.pressed.connect(func() -> void: GameAudio.play_ui("ui_confirm"))
	button.mouse_entered.connect(func() -> void: GameAudio.play_ui("ui_hover"))
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4aa72")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
