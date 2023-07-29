const FWD = { MetroidvaniaSystem.R: Vector2i.RIGHT, MetroidvaniaSystem.D: Vector2i.DOWN, MetroidvaniaSystem.L: Vector2i.LEFT, MetroidvaniaSystem.U: Vector2i.UP }

class CellData:
	enum { DATA_EXITS, DATA_COLORS, DATA_SYMBOL, DATA_MAP, OVERRIDE_COORDS, OVERRIDE_CUSTOM }
	
	var color: Color = Color.TRANSPARENT
	var borders: Array[int] = [-1, -1, -1, -1]
	var border_colors: Array[Color] = [Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT]
	var symbol := -1
	var assigned_scene: String
	var override_map: String
	
	var loading
	
	func _init(line: String) -> void:
		if line.is_empty():
			return
		loading = [line, -1]
		
		var chunk := load_next_chunk()
		for i in 4:
			borders[i] = chunk.get_slice(",", i).to_int()
		
		chunk = load_next_chunk()
		if not chunk.is_empty():
			var color_slice := chunk.get_slice(",", 0)
			if not color_slice.is_empty():
				color = Color(color_slice)
			
			for i in 4:
				color_slice = chunk.get_slice(",", i + 1)
				if not color_slice.is_empty():
					border_colors[i] = Color(color_slice)
		
		chunk = load_next_chunk()
		if not chunk.is_empty():
			symbol = chunk.to_int()
		
		assigned_scene = load_next_chunk()
		loading = null
	
	func get_string() -> String:
		var data: PackedStringArray
		data.append("%s,%s,%s,%s" % borders)
		
		var colors: Array[Color]
		colors.assign([color] + Array(border_colors))
		if colors.any(func(col: Color): return col.a > 0):
			data.append("%s,%s,%s,%s,%s" % colors.map(func(col: Color): return col.to_html(false) if col.a > 0 else ""))
		else:
			data.append("")
		
		if symbol > -1:
			data.append(str(symbol))
		else:
			data.append("")
		data.append(assigned_scene.trim_prefix(MetSys.settings.map_root_folder + "/"))
		return "|".join(data)
	
	func load_next_chunk() -> String:
		loading[1] += 1
		return loading[0].get_slice("|", loading[1])
	
	func get_color() -> Color:
		var c: Color
		var override := get_override()
		if override and override.color.a > 0:
			c = override.color
		else:
			c = color
		
		if c.a > 0:
			return c
		return MetSys.settings.theme.default_center_color
	
	func get_border(idx: int) -> int:
		var override := get_override()
		if override and override.borders[idx] != -2:
			return override.borders[idx]
		return borders[idx]
	
	func get_border_color(idx: int) -> Color:
		var c: Color
		var override := get_override()
		if override and override.border_colors[idx].a > 0:
			c = override.border_colors[idx]
		else:
			c = border_colors[idx]
		
		if c.a > 0:
			return c
		return MetSys.settings.theme.default_border_color
	
	func get_symbol() -> int:
		var override := get_override()
		if override and override.symbol != -2:
			return override.symbol
		return symbol
	
	func get_assigned_scene() -> String:
		var override := get_override()
		if override and override.assigned_scene != "/":
			return override.assigned_scene
		if not override_map.is_empty():
			return override_map
		return assigned_scene
	
	func get_override() -> CellOverride:
		if not MetSys.save_data:
			return null
		return MetSys.save_data.cell_overrides.get(self)
	
	func get_coords() -> Vector3i:
		return MetSys.map_data.cells.find_key(self)

class CellOverride extends CellData:
	var original_room: CellData
	var custom_cell_coords := MetroidvaniaSystem.VECTOR3INF
	
	func _init(from: CellData) -> void:
		original_room = from
		borders = [-2, -2, -2, -2]
		symbol = -2
		assigned_scene = "/"
	
	static func load_from_line(line: String) -> CellOverride:
		var cell: CellData
		var coords_string := line.get_slice("|", CellData.OVERRIDE_COORDS)
		var coords := Vector3i(coords_string.get_slice(",", 0).to_int(), coords_string.get_slice(",", 1).to_int(), coords_string.get_slice(",", 2).to_int())
		
		var is_custom := line.get_slice("|", CellData.OVERRIDE_CUSTOM) == "true"
		if is_custom:
			cell = MetSys.map_data.create_cell_at(coords)
		else:
			cell = MetSys.map_data.get_cell_at(coords)
		
		var override := CellOverride.new(cell)
		if is_custom:
			override.custom_cell_coords = coords
		
		var fake_cell := CellData.new(line)
		override.borders = fake_cell.borders
		override.border_colors = fake_cell.border_colors
		override.color = fake_cell.color
		override.symbol = fake_cell.symbol
		override.set_assigned_scene(fake_cell.assigned_scene)
		
		return override
	
	func set_border(idx: int, value := -2):
		assert(idx >= 0 and idx < 4)
		borders[idx] = value
	
	func set_border_color(idx: int, value := Color.TRANSPARENT):
		assert(idx >= 0 and idx < 4)
		border_colors[idx] = value
	
	func set_color(value := Color.TRANSPARENT):
		color = value
	
	func set_symbol(value := -2):
		assert(value >= -2 and value < MetSys.settings.theme.symbols.size())
		symbol = value
	
	func set_assigned_scene(map := "/"):
		if map == "/":
			_cleanup_assigned_scene()
		else:
			if custom_cell_coords != MetroidvaniaSystem.VECTOR3INF:
				if not map in MetSys.map_data.assigned_scenes:
					MetSys.map_data.assigned_scenes[map] = []
				MetSys.map_data.assigned_scenes[map].append(custom_cell_coords)
			else:
				MetSys.map_data.map_overrides[map] = original_room.assigned_scene
				
				for coords in MetSys.map_data.get_whole_room(original_room.get_coords()):
					var cell: CellData = MetSys.map_data.cells[coords]
					if not cell.override_map.is_empty():
						push_warning("Assigned map already overriden at: %s" % coords)
					cell.override_map = map
		
		assigned_scene = map
		MetSys.room_assign_updated.emit()
	
	func apply_to_group(group_id: int):
		assert(group_id in MetSys.map_data.cell_groups)
		
		for coords in MetSys.map_data.cell_groups[group_id]:
			var override: CellOverride = MetSys.get_cell_override(coords)
			if override == self:
				continue
			
			override.borders = borders.duplicate()
			override.color = color
			override.border_colors = border_colors
			override.symbol = symbol
	
	func destroy() -> void:
		if custom_cell_coords == MetroidvaniaSystem.VECTOR3INF:
			push_error("Only custom cell can be destroyed.")
			return
		
		MetSys.remove_cell_override(custom_cell_coords)
		MetSys.map_data.erase_cell(custom_cell_coords)
		MetSys.map_data.cell_overrides.erase(custom_cell_coords)
		MetSys.map_data.custom_rooms.erase(self)
	
	func _cleanup_assigned_scene() -> void:
		if assigned_scene == "/":
			return
		
		MetSys.map_data.map_overrides.erase(assigned_scene)
		for coords in MetSys.map_data.get_whole_room(original_room.get_coords()):
			MetSys.map_data.cells[coords].override_map = ""
	
	func _get_override_string(coords: Vector3i) -> String:
		return str(get_string(), "|", coords.x, ",", coords.y, ",", coords.z, "|", custom_cell_coords != MetroidvaniaSystem.VECTOR3INF)
	
	func commit() -> void:
		MetSys.map_updated.emit()

var cells: Dictionary#[Vector3i, CellData]
var custom_rooms: Dictionary#[Vector3i, CellData]
var assigned_scenes: Dictionary#[String, Array[Vector3i]]
var cell_groups: Dictionary#[int, Array[Vector3i]]

var cell_overrides: Dictionary#[Vector3i, CellOverride]
var map_overrides: Dictionary#[String, String]

func load_data():
	var file := FileAccess.open(MetSys.settings.map_root_folder.path_join("MapData.txt"), FileAccess.READ)
	
	var data := file.get_as_text().split("\n")
	var i: int
	
	var is_in_groups := true
	while i < data.size():
		var line := data[i]
		if line.begins_with("["):
			is_in_groups = false
			line = line.trim_prefix("[").trim_suffix("]")
			
			var coords: Vector3i
			coords.x = line.get_slice(",", 0).to_int()
			coords.y = line.get_slice(",", 1).to_int()
			coords.z = line.get_slice(",", 2).to_int()
			
			i += 1
			line = data[i]
			
			var cell_data := CellData.new(line)
			if not cell_data.assigned_scene.is_empty():
				assigned_scenes[cell_data.assigned_scene] = [coords]
			
			cells[coords] = cell_data
		elif is_in_groups:
			var group_data := data[i].split(":")
			var group_id := group_data[0].to_int()
			var rooms_in_group: Array
			for j in range(1, group_data.size()):
				var coords: Vector3i
				coords.x = group_data[j].get_slice(",", 0).to_int()
				coords.y = group_data[j].get_slice(",", 1).to_int()
				coords.z = group_data[j].get_slice(",", 2).to_int()
				rooms_in_group.append(coords)
			
			cell_groups[group_id] = rooms_in_group
		
		i += 1
	
	for map in assigned_scenes.keys():
		var assigned_cells: Array[Vector3i]
		assigned_cells.assign(assigned_scenes[map])
		assigned_scenes[map] = get_whole_room(assigned_cells[0])

func save_data():
	var file := FileAccess.open(MetSys.settings.map_root_folder.path_join("MapData.txt"), FileAccess.WRITE)
	
	for group in cell_groups:
		if cell_groups[group].is_empty():
			continue
		
		var line: PackedStringArray
		line.append(str(group))
		for coords in cell_groups[group]:
			line.append("%s,%s,%s" % [coords.x, coords.y, coords.z])
		
		file.store_line(":".join(line))
	
	for coords in cells:
		file.store_line("[%s,%s,%s]" % [coords.x, coords.y, coords.z])
		
		var cell_data := get_cell_at(coords)
		file.store_line(cell_data.get_string())

func get_cell_at(coords: Vector3i) -> CellData:
	return cells.get(coords)

func create_cell_at(coords: Vector3i) -> CellData:
	cells[coords] = CellData.new("")
	return cells[coords]

func create_custom_cell(coords: Vector3i) -> CellOverride:
	assert(not coords in cells, "A cell already exists at this position")
	var cell := create_cell_at(coords)
	custom_rooms[coords] = cell
	
	var override: CellOverride = MetSys.save_data.add_cell_override(cell)
	override.custom_cell_coords = coords
	return override

func get_whole_room(at: Vector3i) -> Array[Vector3i]:
	var room: Array[Vector3i]
	
	var to_check: Array[Vector2i] = [Vector2i(at.x, at.y)]
	var checked: Array[Vector2i]
	
	while not to_check.is_empty():
		var p: Vector2i = to_check.pop_back()
		checked.append(p)
		
		var coords := Vector3i(p.x, p.y, at.z)
		if coords in cells:
			room.append(coords)
			for i in 4:
				if cells[coords].borders[i] == -1:
					var p2: Vector2i = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func get_cells_assigned_to(map: String) -> Array[Vector3i]:
	if map in map_overrides:
		map = map_overrides[map]
	
	var ret: Array[Vector3i]
	ret.assign(assigned_scenes.get(map, []))
	return ret

func get_assigned_scene_at(coords: Vector3i) -> String:
	var cell := get_cell_at(coords)
	if cell:
		return cell.get_assigned_scene()
	else:
		return ""

func erase_cell(coords: Vector3i):
	var assigned_scene: String = cells[coords].assigned_scene
	MetSys.map_data.assigned_scenes[assigned_scene] = []
	
	cells.erase(coords)
	
	for group in cell_groups.values():
		group.erase(coords)
