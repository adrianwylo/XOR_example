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
var overlaps
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
	overlaps = []
	# create base shape
	create_new_overlap_node(true, base_shape_vertices,[])
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

#regurgitates collision2D's vertices + position
func return_polygon_info() -> Array:
	return [overlaps, position, identity]

#function for modifying the vertices of an show and its child representation
func modify_pol_frags(overlap: Node, new_vertices: Array):
	print("\nCalling modify_pol_frags ")
	#IT IS IN HERE THAT WE HAVE TO FILTER OUT HOW TO READ FUNCTION OUTPUTS
	
	if new_vertices.size()<1:
		#turn into assertion later
		print("ALERT: no vertices in modify_pol_frags (should check the size before passing in here)")
	overlap.replace_polygon(new_vertices)
	
	#delete for overhead
	print("checking if vectorArray replacement successful")
	print(new_vertices)
	print(overlap.ret_polygons())

#redoing of intersect_polygon for overlaps (amd their multiple polygons)
func intersect_overlaps(A: Area2D, B: Area2D, A_pos: Vector2, B_pos: Vector2) -> Array:
	var A_shapes = A.ret_polygons()
	var B_shapes = B.ret_polygons()
	print("\ncalling intersect_overlaps for A:")
	#print(A_shapes)
	#print("and B:")
	#print(B_shapes)
	assert(not A_shapes.is_empty(), "empty A (int)")
	assert(not B_shapes.is_empty(), "empty B (int)")
	var final_intersect = []
	for a in A_shapes:
		for b in B_shapes:
			
			var shifted_b = []
			for vertex in b:
				shifted_b.append(vertex+B_pos)				
			shifted_b = PackedVector2Array(shifted_b)
			
			var shifted_a = []
			for vertex in a:
				shifted_a.append(vertex+A_pos)				
			shifted_a = PackedVector2Array(shifted_a)
			
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
func clip_overlaps(A: Area2D, B: Area2D, A_pos: Vector2, B_pos: Vector2) -> Array:
	var A_shapes = A.ret_polygons()
	var B_shapes = B.ret_polygons()
	print("\ncalling clip_overlaps for A:")
	#print(A_shapes)
	#print("and B:")
	#print(B_shapes)
	#assert(not A_shapes.is_empty(), "empty A (clip)")
	#assert(not B_shapes.is_empty(), "empty B (clip)")
	var final_clip = []
	for a in A_shapes:
		for b in B_shapes:
			var shifted_b = []
			for vertex in b:
				shifted_b.append(vertex+B_pos)				
			shifted_b = PackedVector2Array(shifted_b)
			
			var shifted_a = []
			for vertex in a:
				shifted_a.append(vertex+A_pos)				
			shifted_a = PackedVector2Array(shifted_a)
			
			var clips = Geometry2D.clip_polygons(shifted_a, shifted_b)
			for clip in clips:
				var shifted_poly = []
				for vertex in clip:
					shifted_poly.append(vertex-A_pos)
				final_clip.append(shifted_poly)
	print("final clip is")
	print(final_clip)
	return final_clip

#function for adding child rep in overlaps
func create_new_overlap_node(polarity: bool, new_vertices: Array,  involved_ids: Array = []):
	print("\nmaking new node with:")
	print(new_vertices)
	var new_overlap =  new_poly.instantiate()
	#make new vertices
	new_overlap.add_polygon(new_vertices)
	new_overlap.set_overlaps(involved_ids)
	new_overlap.set_polarity(polarity)
	if polarity:
		print("Visible pol for " + str(identity))
	else:
		print("Invisible pol for " + str(identity))
	#add child and add new overlap to overlaps
	add_child(new_overlap)
	overlaps.append(new_overlap)
	

#logic handler for xor mechanic when this shape is above
func _check_overlap_A(other_overlaps, other_pos, other_id, id):
	print("\ncheck_overlap_A for: A=" + str(id) + " and B=" +str(other_id))
	if id != identity:
		return
	for other_overlap in other_overlaps:
		var other_polarity = other_overlap.show_polarity
		var B_list = other_overlap.show_overlap() 
		B_list.append(other_id)
		for overlap in overlaps:
			var my_polarity = overlap.show_polarity
			print("now look at a " + ("positive" if my_polarity else "negative") + " node for")
			print(overlap.show_overlap())
			#save list of involved ids in other node
			if overlap.is_in(B_list):
				#modify current interaction
				if my_polarity:
					#A is shown
					if other_polarity:
						print("#(+A)(+B) is in")
						var neg = intersect_overlaps(overlap, other_overlap,position,other_pos)
						var pos = clip_overlaps(overlap, other_overlap,position,other_pos)
						#check if neg is false
						if neg.is_empty():
							#remove this overlap from the node 
							#We revert positive parity nodes and delete negative ones
							overlap.stop_overlap(B_list)
						#modify the node's shapes
						modify_pol_frags(overlap, pos)
					#print("#(+A)(-B) = nothing to do")
				else:
					#A is not shown
					print("(-A)(+B/-B) is in")
					var pos = intersect_overlaps(overlap, other_overlap,position,other_pos)
					var neg = clip_overlaps(overlap, other_overlap,position,other_pos)
					if pos.is_empty():
						#remove this node entirely
						remove_child(overlap)	
						overlap.queue_free()
					else:
						#modify the node's shapes (even though they aren't seen)
						modify_pol_frags(overlap, neg)
			else:
				if my_polarity:
					#A is shown
					if other_polarity:
						print("#(+A)(+B) is new")
						var neg = intersect_overlaps(overlap, other_overlap,position,other_pos)
						var pos = clip_overlaps(overlap, other_overlap,position,other_pos)
						#modify the positive overlap
						modify_pol_frags(overlap, pos)
						print("modified positive")
						#must add B into the index list
						overlap.add_to_overlap(B_list)

						#create new neg node
						create_new_overlap_node(false,neg,B_list)
						print("created negative")
						print("done with (+A)(+B) calc\n")
				else:
					print("(-A)(+B/-B) is new")
					var pos = intersect_overlaps(overlap, other_overlap,position,other_pos)
					var neg = clip_overlaps(overlap, other_overlap,position,other_pos)
					#modify the positive overlap
					modify_pol_frags(overlap,neg)
					#must add B into the index list
					overlap.add_to_overlap(B_list)
					#create new pos node
					create_new_overlap_node(true,pos,B_list)

#logic handler for xor mechanic when this shape is below (adds a virtual mask to shapes)
func _check_overlap_B(other_overlaps, other_pos, other_id, id):
	print("check_overlap_B for: A=" + str(id) + " and B=" + str(other_id))
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
