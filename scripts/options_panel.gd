extends Control
## Shared options panel used by the title menu and the pause menu.

signal back_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.025, 0.04, 0.035, 0.84)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -245
	panel.offset_top = -305
	panel.offset_right = 245
	panel.offset_bottom = 305
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Ajustes"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f1dba5"))
	layout.add_child(title)
	_add_spacer(layout, 5)
	_add_audio_slider(layout, "Volumen general", GameSettings.master_volume, GameSettings.set_master_volume)
	_add_audio_slider(layout, "Música", GameSettings.music_volume, GameSettings.set_music_volume)
	_add_audio_slider(layout, "Efectos", GameSettings.effects_volume, GameSettings.set_effects_volume)
	var sensitivity_row := _make_row(layout, "Sensibilidad del ratón")
	var sensitivity_value := _make_value_label(sensitivity_row)
	sensitivity_value.text = "%d%%" % roundi(GameSettings.mouse_sensitivity / DEFAULT_SENSITIVITY * 100.0)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.008
	sensitivity.step = 0.0001
	sensitivity.value = GameSettings.mouse_sensitivity
	sensitivity.custom_minimum_size = Vector2(0, 28)
	layout.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float) -> void:
		GameSettings.set_mouse_sensitivity(value)
		sensitivity_value.text = "%d%%" % roundi(value / DEFAULT_SENSITIVITY * 100.0)
	)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = GameSettings.fullscreen
	fullscreen.add_theme_font_size_override("font_size", 20)
	fullscreen.add_theme_color_override("font_color", Color("f1ead5"))
	layout.add_child(fullscreen)
	fullscreen.toggled.connect(GameSettings.set_fullscreen)
	_add_spacer(layout, 8)
	var back := _make_button("Volver", true)
	back.custom_minimum_size = Vector2(0, 52)
	layout.add_child(back)
	back.pressed.connect(func() -> void: back_requested.emit())
	visibility_changed.connect(func() -> void:
		if visible:
			back.grab_focus()
	)


const DEFAULT_SENSITIVITY := 0.0025


func _add_audio_slider(parent: VBoxContainer, label_text: String, initial_value: float, setter: Callable) -> void:
	var row := _make_row(parent, label_text)
	var value_label := _make_value_label(row)
	value_label.text = "%d%%" % roundi(initial_value * 100.0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(0, 24)
	parent.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		value_label.text = "%d%%" % roundi(value * 100.0)
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.06, 0.97)
	style.border_color = Color("a78e5e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_row(parent: VBoxContainer, text_value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = text_value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f1ead5"))
	row.add_child(label)
	return row


func _make_value_label(parent: HBoxContainer) -> Label:
	var value := Label.new()
	value.custom_minimum_size = Vector2(62, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", Color("dfca9a"))
	parent.add_child(value)
	return value


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)


func _make_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("f6efd9"))
	button.add_theme_color_override("font_hover_color", Color("fff6d7"))
	button.add_theme_stylebox_override("normal", _button_style(Color("526349") if primary else Color("273a31")))
	button.add_theme_stylebox_override("hover", _button_style(Color("7d7046")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("394a3c")))
	button.add_theme_stylebox_override("focus", _button_style(Color("665b3d")))
	button.pressed.connect(func() -> void: GameAudio.play_ui("ui_confirm"))
	button.mouse_entered.connect(func() -> void: GameAudio.play_ui("ui_hover"))
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4aa72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
