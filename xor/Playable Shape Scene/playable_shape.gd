extends Area2D

# Reference to the 2D nodes:
@onready var base_col2d = $click_col2d
@onready var base_pol2d = $base_pol2d
@onready var overlap_pol2d = $Overlap

#parent node for signal management:
var playable_pieces

#signal calls to parent:
signal occupy_drag(identity)
signal free_drag(identity, click_location)
signal continue_q(identity)
signal overlapping(other_id, my_id)
signal not_overlapping(other_id, my_id)

#passed metadata:
#top left corner of shape (coordinates)
var tl_pos
#bottom right corner of shape (coordinates)
var br_pos
#identification #
var identity
#packaged vertices for polygon definition
var packed_vertices
#converted vertices for orignal
var base_shape_vertices

#current metadata 
var grid_coor
#boolean value is shape being dragged?
var dragging = false
#boolean for is snapping?
var snapping = false
#upon dragging, tracks offset from corner for snapping
var mouse_offset
#target for linear interpolation
var snap_target

#MAPPING
var map
#length of one grid unit in pxls
var grid_len

#Physics variables:
# Size of the game window
var screen_size 
# Offset between mouse position and the object when dragging
var drag_offset = Vector2() 
# How fast piece move in snap to grid
var snap_speed = 10 
#for clamping
var area_offset
#metadata from click instance
var click_event

#class for polygon metadata
class poly_metadata:
	var my_id: int
	#list of overlaps
	var list_of_overlaps: Array
	var my_position: Vector2i
	#list of vertices
	var my_base_shape: Array
	
	func _init(id: int, overlaps_list: Array, my_pos: Vector2, base: Array):
		my_id = id
		list_of_overlaps = overlaps_list
		my_position = my_pos
		my_base_shape = base

# Returns shape ID for collision identification
func return_id():
	return identity

# Converts a single vertex into pixel coordinates
func coor_to_px(vertex: Vector2) -> Vector2:
	var x_key = str(vertex.x)
	var y_key = str(vertex.y)
	assert(map.has(x_key), "x not found")
	assert(map[x_key].has(y_key), "y not found")
	return map[x_key][y_key]

#converts packed vertex array  into pixel coordinates
func pol_coor_to_px(vertices: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var converted = PackedVector2Array()
	var converted_offset = coor_to_px(offset)
	for vertex in vertices:
		var new_pos = coor_to_px(vertex)-converted_offset
		converted.append(new_pos)
	return converted

#Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#parent connections
	playable_pieces = get_parent()
	if playable_pieces:
		playable_pieces.connect("go", _start_dragging)
		playable_pieces.connect("start_snap", _stop_dragging)
	identity = get_index()
	
	#track position
	position = coor_to_px(tl_pos)
	grid_coor = tl_pos
	
	# for movement bounds
	screen_size = get_viewport_rect().size
	area_offset = coor_to_px(br_pos) - coor_to_px(tl_pos)
	
	# create base shape
	#NOTE the coordinates passsed in here are relative to the position already
	base_shape_vertices = pol_coor_to_px(packed_vertices, tl_pos)
	base_pol2d.polygon = base_shape_vertices
	base_pol2d.modulate = Color(0, 0, 200)
	
	# create clickable collision
	base_col2d.polygon = base_shape_vertices
	

#process passed metadata
func pass_metadata(vertices: Array, tl: Vector2, br: Vector2) -> void:
	#assert(vertices.size() > 2, "not a shape")
	packed_vertices = PackedVector2Array(vertices)
	tl_pos = tl
	br_pos = br

#save map from coordinate to position
func pass_map(pos_dic) -> void:
	map = pos_dic

#Click event handler
func _input(event: InputEvent) -> void:
	click_event = event
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if dragging == true:
			emit_signal("free_drag", identity, event.position - mouse_offset)
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), base_col2d.polygon):
				#request to start dragging
				print()
				print(str(identity) +" wants to move from grid index " + str(grid_coor))
				mouse_offset = event.position-position
				emit_signal("occupy_drag", identity)

#reacts to go ack
func _start_dragging(id):
	if id == identity:
		dragging = true
		drag_offset = position - click_event.position

#reacts to stop ack
func _stop_dragging(grid_pos, id):
	if id == identity:
		dragging = false
		snap_to_grid(grid_pos)
		#processing of metadata from snap 
		grid_coor = grid_pos
		emit_signal("continue_q", identity)
		print(str(identity) +" has stopped at grid index " + str(grid_coor))

#facilitates the animation of snapping to grid
func snap_to_grid(grid_pos):
	snap_target = coor_to_px(grid_pos)
	snapping = true

#clamps shape movement 
func _process(delta: float) -> void:
	if snapping:
		position = position.lerp(snap_target, snap_speed * delta)
		if position.distance_to(snap_target) < 1.0:
			position = snap_target
			snapping = false  # Stop snapping after reaching the target
	if dragging:
		position = get_global_mouse_position() + drag_offset
		position = position.clamp(Vector2.ZERO, screen_size - area_offset)

#redoing of intersect_polygon for overlaps (and their multiple polygons)
func intersect_overlaps(a: Array, B_shapes: Array, A_pos: Vector2, B_pos: Vector2) -> Array:
	assert(not B_shapes.is_empty(), "empty B (int)")
	var final_intersect = []
	var shifted_a = []
	for vertex in a:
		shifted_a.append(vertex+A_pos)
	shifted_a = PackedVector2Array(shifted_a)
	for b in B_shapes:
		var shifted_b = []
		for vertex in b:
			shifted_b.append(vertex+B_pos)
		shifted_b = PackedVector2Array(shifted_b)
		var intersections = Geometry2D.intersect_polygons(shifted_a, shifted_b)
		for intersection in intersections:
			var shifted_poly = []
			for vertex in intersection:
				shifted_poly.append(vertex-A_pos)
			final_intersect.append(shifted_poly)
	print("final intersect is")
	print(final_intersect)
	return final_intersect

#redoing of clip_polygon for overlaps (and their multiple polygons)
func clip_overlaps(a: Array, B_shapes: Array, A_pos: Vector2, B_pos: Vector2) -> Array:
	assert(not B_shapes.is_empty(), "empty B (int)")
	var final_clip = []
	var shifted_a = []
	for vertex in a:
		shifted_a.append(vertex+A_pos)
	shifted_a = PackedVector2Array(shifted_a)
	for b in B_shapes:
		var shifted_b = []
		for vertex in b:
			shifted_b.append(vertex+B_pos)
		shifted_b = PackedVector2Array(shifted_b)
		var clipions = Geometry2D.clip_polygons(shifted_a, shifted_b)
		for clipion in clipions:
			var shifted_poly = []
			for vertex in clipion:
				shifted_poly.append(vertex-A_pos)
			final_clip.append(shifted_poly)
	print("final clip is")
	print(final_clip)
	return final_clip

#handlers for adding to collision dictionary
func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	emit_signal("overlapping", other_shape_node.return_id(), identity)

#handlers for adding to collision dictionary
func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	emit_signal("not_overlapping", other_shape_node.return_id(), identity)
