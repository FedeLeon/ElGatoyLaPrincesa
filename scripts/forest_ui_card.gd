extends Panel
## Reusable ink-and-moss frame for the in-game HUD.

@export var accent_color := Color("b9a46e")
@export var ornamented := true


func _ready() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.055, 0.045, 0.91)
	frame.border_color = Color("827b59")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(0)
	frame.shadow_color = Color(0.01, 0.025, 0.02, 0.42)
	frame.shadow_size = 0
	frame.shadow_offset = Vector2(0, 3)
	frame.anti_aliasing = false
	add_theme_stylebox_override("panel", frame)
	queue_redraw()


func _draw() -> void:
	if size.x < 40.0 or size.y < 35.0:
		return
	var left := Vector2(17, 20)
	var right := Vector2(size.x - 17, 20)
	if ornamented:
		_draw_sprig(left, Vector2(1, 0.45))
		_draw_sprig(right, Vector2(-1, 0.45))
	var line_color := Color(accent_color, 0.5)
	draw_line(Vector2(38, 15), Vector2(size.x - 38, 15), line_color, 1.0, true)
	draw_circle(Vector2(29, 15), 1.8, accent_color)
	draw_circle(Vector2(size.x - 29, 15), 1.8, accent_color)


func _draw_sprig(origin: Vector2, direction: Vector2) -> void:
	var stem := direction.normalized()
	var tip := origin + stem * 23.0
	draw_line(origin, tip, Color(accent_color, 0.8), 1.35, false)
	for index in range(2):
		var point := origin + stem * (7.0 + index * 8.0)
		_draw_leaf(point, stem.rotated(-0.9), accent_color)
		_draw_leaf(point + stem * 3.0, stem.rotated(0.9), Color("8da477"))
	draw_circle(tip, 1.8, Color("c9bb82"))


func _draw_leaf(at: Vector2, direction: Vector2, color: Color) -> void:
	var axis := direction.normalized() * 5.0
	var cross_axis := Vector2(-axis.y, axis.x) * 1.8
	var points := PackedVector2Array([
		at,
		at + axis * 0.45 + cross_axis,
		at + axis,
		at + axis * 0.45 - cross_axis,
	])
	draw_colored_polygon(points, Color(color, 0.92))
