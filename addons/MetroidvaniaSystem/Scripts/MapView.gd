extends Control

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map
@onready var current_layer_spinbox: SpinBox = %CurrentLayer
@onready var status_label: Label = %StatusLabel

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)
var plugin: EditorPlugin

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var current_layer: int

func _enter_tree() -> void:
	if owner:
		plugin = owner.plugin

func _ready() -> void:
	map.draw.connect(_on_map_draw)
	map_overlay.mouse_exited.connect(status_label.hide)
	map_overlay.gui_input.connect(_on_overlay_input)
	map_overlay.draw.connect(_on_overlay_draw)
	
	current_layer_spinbox.value_changed.connect(on_layer_changed)
	%RecenterButton.pressed.connect(on_recenter_view)
	
	status_label.hide()
	await get_tree().process_frame
	update_map_position()
	map.size = MetSys.CELL_SIZE * 200
	MetSys.settings.theme_changed.connect(func(): update_map_position(); on_layer_changed(current_layer))

func get_cursor_pos() -> Vector2i:
	var pos := (map_overlay.get_local_mouse_position() - MetSys.CELL_SIZE / 2).snapped(MetSys.CELL_SIZE) / MetSys.CELL_SIZE as Vector2i - map_offset
	return pos

func on_layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	map_overlay.queue_redraw()

func on_recenter_view() -> void:
	map_offset = Vector2i(10, 10)
	map_overlay.queue_redraw()
	update_map_position()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = Vector2(view_drag.z, view_drag.w) + (map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.CELL_SIZE
			update_map_position()
			map_overlay.queue_redraw()
			_on_drag()
		else:
			map_overlay.queue_redraw()
		
		_update_status_label()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()

func _on_drag():
	pass

func _update_status_label():
	status_label.show()
	status_label.text = str(get_cursor_pos())

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			current_layer_spinbox.value -= 1
			accept_event()
		elif event.keycode == KEY_E:
			current_layer_spinbox.value += 1
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if map_overlay:
			map_overlay.queue_redraw()

func _on_map_draw() -> void:
	if not plugin:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_cell(map, Vector2i(x, y) + Vector2i(100, 100), Vector3i(x, y, current_layer), true, false)
	
	if MetSys.settings.theme.use_shared_borders:
		MetSys.draw_shared_borders()

func _on_overlay_draw() -> void:
	pass

func update_map_position():
	map.position = Vector2(map_offset - Vector2i(100, 100)) * MetSys.CELL_SIZE
