extends Area2D

# Reference to the 2D nodes:
@onready var col2d = $CollisionPolygon2D
@onready var pol2d = $Polygon2D 

#parent node for signal management:
var playable_pieces

#signal calls to parent:
signal occupy_drag(identity)
signal free_drag(identity)
signal continue_q(identity)

#Metadata Variables:
#top left corner of shape (coordinates)
var tl_pos
#bottom right corner of shape (coordinates)
var br_pos
#packaged vertices for polygon definition
var packed_vertices
#identification #
var identity
#boolean value is shape being dragged?
var dragging = false

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
@export var snap_speed = 400 
#itialized from br and tl for clamping
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	playable_pieces = get_parent()
	if playable_pieces:
		playable_pieces.connect("go", _start_dragging)
		playable_pieces.connect("stop", _stop_dragging)
	position = coor_to_px(tl_pos)
	area_offset = coor_to_px(br_pos) - coor_to_px(tl_pos)
	pol2d.polygon = pol_coor_to_px(packed_vertices, tl_pos)
	col2d.polygon = pol_coor_to_px(packed_vertices, tl_pos)
	#will remove
	var random_color = Color(randf(), randf(), randf())
	pol2d.modulate = random_color
	screen_size = get_viewport_rect().size

#packs vertexes
func pass_vertices(vertices) -> void:
	assert(len(vertices) > 2, "not a shape")
	packed_vertices = PackedVector2Array(vertices)

#saves metadata
func pass_metadata(tl, br, id) -> void:
	tl_pos = tl
	br_pos = br
	identity = id

#save map from coordinate to position
func pass_map(pos_dic) -> void:
	map = pos_dic
	grid_len = map['1']['0'].x - map['0']['0'].x 

#Click event handler
func _input(event: InputEvent) -> void:
	click_event = event
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if dragging == true:
			print(str(identity)+" wants to stop")
			emit_signal("free_drag", identity)
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), $CollisionPolygon2D.polygon):
				#request to start dragging
				print(str(identity)+" wants to move from pos " + str(position))
				emit_signal("occupy_drag", identity)

#reacts to go ack
func _start_dragging(id):
	if id == identity:
		dragging = true
		drag_offset = position - click_event.position
		playable_pieces.move_child(self, playable_pieces.get_child_count() - 1) 

#reacts to stop ack
func _stop_dragging(id):
	if id == identity:
		dragging = false
		#facilitate snap
		print(click_event.position)
		emit_signal("continue_q", identity)

#clamps shape movement
func _process(delta: float) -> void:
	if dragging:
		position = get_global_mouse_position() + drag_offset
		position = position.clamp(Vector2.ZERO, screen_size - area_offset)
