@tool
extends Control

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map
@onready var panel: PanelContainer = $Panel

@export var mode_group: ButtonGroup

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var current_layer: int

func layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	map_overlay.queue_redraw()

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = (Vector2i(view_drag.z, view_drag.w) + Vector2i(map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.ROOM_SIZE)
			map.queue_redraw()
			map_overlay.queue_redraw()
		else:
			map_overlay.queue_redraw()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()

func _on_overlay_draw() -> void:
	var mouse := get_cursor_pos()
	
	var font := get_theme_font(&"font", &"Label")
	map_overlay.draw_string(font, Vector2(0, panel.size.y + font.get_height()), str(mouse))
	
	var room_size: Vector2 = MetSys.ROOM_SIZE
	map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size, room_size), Color.GREEN, false, 2)

func _on_map_draw() -> void:
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(map, Vector2i(x, y) + map_offset, Vector3i(x, y, current_layer))

func get_cursor_pos() -> Vector2i:
	var room_size: Vector2 = MetSys.ROOM_SIZE
	var pos := (map_overlay.get_local_mouse_position() - room_size / 2).snapped(room_size) / room_size as Vector2i
	return pos
