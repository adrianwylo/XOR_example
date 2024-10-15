extends Area2D

# Reference to the 2D nodes:
@onready var base_col2d = $click_col2d

#parent node for signal management:
var playable_pieces

#signal calls to parent:
signal occupy_drag(identity)
signal free_drag(identity, click_location)
signal continue_q(identity)

#metadata class for polygon children
class fragment:
	var shape: Array
	var parity: bool
	var index: int
	
	func _init(vertices: Array, is_visible: bool, id: int = -1):
		shape = vertices
		parity = is_visible
		index = id

#passed metadata:
#top left corner of shape (coordinates)
var tl_pos
#bottom right corner of shape (coordinates)
var br_pos
#identification #
var identity
#packaged vertices for polygon definition
var packed_vertices

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
#list of visible_pieces (and invisible ones) (does not include base shape)
var fragments
#to access position (pxls) just use position

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
		playable_pieces.connect("check_overlap_A", _check_overlap_A)
		playable_pieces.connect("check_overlap_B", _check_overlap_B)
	identity = get_index()
	
	#track position
	position = coor_to_px(tl_pos)
	grid_coor = tl_pos
	
	# for movement bounds
	screen_size = get_viewport_rect().size
	area_offset = coor_to_px(br_pos) - coor_to_px(tl_pos)
	
	# create base shape
	var pol2d = Polygon2D.new()
	pol2d.polygon = pol_coor_to_px(packed_vertices, tl_pos)
	#will remove
	var random_color = Color(randf(), randf(), randf())
	pol2d.modulate = random_color
	add_child(pol2d)
	#the id is -2 because 0-indexed and first child is collision
	fragments = [fragment.new(packed_vertices, true, get_child_count()-2)]
	
	# create clickable collision
	base_col2d.polygon = pol_coor_to_px(packed_vertices, tl_pos)
	
	

#process passed metadata
func pass_metadata(vertices, tl, br) -> void:
	assert(len(vertices) > 2, "not a shape")
	packed_vertices = PackedVector2Array(vertices)
	tl_pos = tl
	br_pos = br
	

#save map from coordinate to position
func pass_map(pos_dic) -> void:
	map = pos_dic
	grid_len = map['1']['0'].x - map['0']['0'].x 

#Click event handler
func _input(event: InputEvent) -> void:
	click_event = event
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if dragging == true:
			emit_signal("free_drag", identity, event.position - mouse_offset)
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), base_col2d.polygon):
				#request to start dragging
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

#regurgitates collision2D's vertices + position
func return_polygon_info() -> Array:
	#needs additional logic
	return [fragments, position, identity]

#logic handler for xor mechanic
func _check_overlap_A(vertices, pos, id):
	if id == identity:
		
		pass
		#var overlap = Geometry2D.exclude_polygons(oc, dc)
		
func _check_overlap_B(vertices, pos, id):
	if id == identity:
		
		pass
