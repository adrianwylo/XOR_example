extends Area2D

# Reference to the 2D nodes:
@onready var base_col2d = $click_col2d
@export var new_poly: PackedScene

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
#list of references to visible_pieces (and invisible ones) 
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
		playable_pieces.connect("check_overlap_A", _check_overlap_A)
		playable_pieces.connect("check_overlap_B", _check_overlap_B)
	identity = get_index()
	
	#track position
	position = coor_to_px(tl_pos)
	grid_coor = tl_pos
	
	# for movement bounds
	screen_size = get_viewport_rect().size
	area_offset = coor_to_px(br_pos) - coor_to_px(tl_pos)
	
	#NOTE the coordinates passsed in here are relative to the position already
	var base_shape_vertices = pol_coor_to_px(packed_vertices, tl_pos)
	# create base shape
	var base_pol2d = new_poly.instantiate()
	base_pol2d.add_polygon(base_shape_vertices) 
	base_pol2d.set_polarity(true)
	base_pol2d.set_overlaps([])
	
	# add child to tree
	add_child(base_pol2d)
	#create fragment  list
	fragments = [base_pol2d]
	
	# create clickable collision
	base_col2d.polygon = base_shape_vertices

#process passed metadata
func pass_metadata(vertices: Array, tl: Vector2, br: Vector2) -> void:
	assert(vertices.size() > 2, "not a shape")
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
	return [fragments, position, identity]

#function for modifying the vertices of an show and its child representation
func modify_pol_frags(overlap: Node, new_vertices: Array):
	#IT IS IN HERE THAT WE HAVE TO FILTER OUT HOW TO READ FUNCTION OUTPUTS
	overlap.replace_polygon(new_vertices)

#redoing of intersect_polygon for overlaps (amd their multiple polygons)
func intersect_overlaps(A: Area2D, B: Area2D) -> Array:
	var A_shapes = A.ret_polygons()
	var B_shapes = B.ret_polygons()
	assert(not A_shapes.empty(), "empty A (int)")
	assert(not B_shapes.empty(), "empty B (int)")
	var final_intersect = []
	for a in A_shapes:
		for b in B_shapes:
			var intersections = Geometry2D.intersect_polygons(a, b)
			if intersections.size() > 0:
				final_intersect.append_array(intersections) 
	return final_intersect

#redoing of clip_polygon for overlaps (and their multiple polygons)
func clip_overlaps(A: Area2D, B: Area2D) -> Array:
	var A_shapes = A.ret_polygons()
	var B_shapes = B.ret_polygons()
	assert(not A_shapes.empty(), "empty A (clip)")
	assert(not B_shapes.empty(), "empty B (clip)")
	var final_clip = []
	for a in A_shapes:
		for b in B_shapes:
			var clips = Geometry2D.clip_polygons(a, b)
			if clips.size() > 0:
				final_clip.append_array(clips) 
	return final_clip

#function for adding child rep in fragments
func create_new_frag_node(polarity: bool, new_vertices: Array,  involved_ids: Array = []):
	var new_frag =  new_poly.instantiate()
	#make new vertices
	new_frag.add_polygon(new_vertices)
	new_frag.set_overlaps(involved_ids)
	new_frag.set_polarity(polarity)
	#add child and add fragment to fragments
	add_child(new_frag)
	fragments.append(new_frag)
	

#logic handler for xor mechanic
func _check_overlap_A(other_fragments, other_pos, other_id, id):
	if id != identity:
		pass
	#STILL HAVE TO GO OVER LOGIC REGARDING HANDLING BASE CASE 
	#BASE CASE ONLY MATTERS IF THERE ARE 2 CHILDREN (MAY NOT MATTER)
	
	for other_fragment in other_fragments:
		var other_polarity = other_fragment.show_polarity
		var B_list = other_fragment.show_overlap() 
		B_list.append(other_id)
		for fragment in fragments:
			var my_polarity = fragment.show_polarity
			#save list of involved ids in other node
			if fragment.is_in(B_list):
				#modify current interaction
				if my_polarity:
					#A is shown
					if other_polarity:
						print("#(+A)(+B)")
						var neg = intersect_overlaps(fragment, other_fragment)
						var pos = clip_overlaps(fragment, other_fragment)
						#check if neg is false
						if neg.empty():
							#remove this overlap from the node 
							#We revert positive parity nodes and delete negative ones
							fragment.stop_overlap[B_list]
						#modify the node's shapes
						modify_pol_frags(fragment, pos)
					else:
						print("#(+A)(-B) = nothing to do")
				else:
					#A is not shown
					print("(-A)(+B/-B)")
					var pos = intersect_overlaps(fragment, other_fragment)
					var neg = clip_overlaps(fragment, other_fragment)
					if pos.empty():
						#remove this node entirely
						remove_child(fragment)	
						fragment.queue_free()
					else:
						#modify the node's shapes (even though they aren't seen)
						modify_pol_frags(fragment, neg)
			else:
				print("IF OVERLAP DOESN'T EXIST")

#logic handler for xor mechanic
func _check_overlap_B(other_fragments, other_pos, id):
	if id == identity:
		
		pass


#handlers for adding to collision dictionary
func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	emit_signal("overlapping", other_shape_node.return_id(), identity)

#handlers for adding to collision dictionary
func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	emit_signal("not_overlapping", other_shape_node.return_id(), identity)
