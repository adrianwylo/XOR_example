extends Area2D

# Reference to the 2D nodes:
@onready var base_col2d = $click_col2d
@onready var base_pol2d = $base_pol2d

#parent node for signal management:
var playable_pieces

#node this node is currently colliding with
var connected_node_id

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

# if this is a display
var is_display = false
# if this shape is in a group
var is_in_group = false

#MAPPING
var map
#length of one grid unit in pxls
var grid_len

#Physics variables:
# Size of the game window
var screen_size 
# Offset between mouse position and the object when dragging
var drag_offset
# How fast piece move in snap to grid
var snap_speed = 10 
#for clamping
var area_offset
#metadata from click instance
var click_event
var max_speed: float = 250 # Set your desired maximum speed
var smooth_factor: float = 0.1  # Time to reach the target position
var velocity: Vector2 = Vector2.ZERO  # Velocity to keep track of the current speed

#region Collision Detectors
#handlers for noting collision
func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	var other_node_id = other_shape_node.return_id()
	print("I'm connected to ", connected_node_id, " and i want to join ", other_node_id, "?")
	if connected_node_id == -1:
		connected_node_id = other_node_id
		emit_signal("overlapping", other_node_id, identity)
		

#handlers for noting loss of collision
func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	var other_node_id = other_shape_node.return_id()
	print("I'm connected to ", connected_node_id, " and i want to leave ", other_node_id, "?")
	if connected_node_id == other_node_id:
		
		emit_signal("not_overlapping",other_node_id , identity)
		connected_node_id = -1
		
#endregion

#region report functions
# Returns shape ID for collision identification
func return_id() -> int:
	return identity

# Returns polygon and position for collision identification
func return_base_and_pos() -> Dictionary:
	#does the position conversion here to absolute coordinates
	#for overlap calc
	var abs_vertices = []
	for vertex in base_pol2d.polygon:
		abs_vertices.append(Vector2i(vertex.x,vertex.y) + Vector2i(position.x,position.y))
	return {
		#"base vertices": base_pol2d.polygon,
		"abs base vertices": PackedVector2Array(abs_vertices),
		"position": position
	}
#endregion


#region Display Signal functions
# Processes incoming signals from playable_pieces over how display should function
func _show_group(display_id: int, overlapping_children: Array):
	var overlapping_ids = []
	var children_shapes = {}
	
	for child in overlapping_children:
		overlapping_ids.append(child.return_id())
		children_shapes[child.return_id()] = child.return_base_and_pos()
		
	#print("In this group for id:", identity, " the overlaps are ", overlapping_ids)
	##sdf(display_id, " is the display")
	#checks if this child is involved in group
	if identity in overlapping_ids:
		#checks if this child should display
		is_in_group = true
		if display_id == identity:
			var overlap_shape = XOR_polygons(display_id, children_shapes)
			if not overlap_shape.is_empty():
				display_overlap(overlap_shape)
			is_display = true
		else:
			is_display = false

#reorganizes nodes to display xor result
func display_overlap(pol_list):
	##sdf("displaying overlap for ",pol_list)
	# Get the current child count excluding two specific children
	var child_count = get_child_count() - 2
	var no_pol = pol_list.size()
	var child_index = 0
	
	var children = get_children()
	for i in range(2, len(children)):
		children[i].queue_free()  # Remove the node at index i
	# Iterate over the polygons in the list
	for vertices in pol_list:
		var polygon_node = Polygon2D.new()
		polygon_node.polygon = vertices
		polygon_node.modulate = Color(randf(), randf(), randf())
		add_child(polygon_node)
		polygon_node.show()

	if child_count > no_pol:
		for i in range(child_index, child_count, -1):
			var child_node = get_child(i)
			remove_child(child_node) 

#called when discontinuing a collsion
func _no_show_group(id):
	if id == identity:
		is_display = false
		is_in_group = false

#Performs XOR operation on all children (TODO)
func XOR_polygons(display_id: int, children_shapes_data: Dictionary):
	#begin with display shape
	#sdf(children_shapes_data)
	var base_pos = children_shapes_data[display_id]["position"]
	var curr_XOR = [children_shapes_data[display_id]["abs base vertices"]]
	var curr_merge = children_shapes_data[display_id]["abs base vertices"]
	#sdf(" NEW XOR CALC=============================")
	#sdf("finish xor'd ", display_id)
	#sdf("new curr_Xor = ", curr_XOR)
	
	#stack of processed shapes
	var processed_shapes = [display_id]
	#begin loop of xoring
	while true:
		var all_shapes_checked = true 
		#adding all new shapes
		#{shape_id: {"position": pos_vector, "abs base vertices"" [shape]},......}
		for index in children_shapes_data:
			if index != display_id:
				print("\nOPERATING ON NEW INDEX: ", index)
				#get new values
				var new_vertices = children_shapes_data[index]["abs base vertices"]
				#check if there is a collision between the polygons
				print("curr merge: ",curr_merge,"\nnew vertices: ", new_vertices, "\ncurr xor: ", curr_XOR)
				var test_merge = Geometry2D.merge_polygons(curr_merge, new_vertices)
				#sdf("they share an edge: ",test_merge.size()<2 )
				#sdf("they share a corner: ", is_corner(curr_merge, new_vertices))
				if test_merge.size()<2: # checks if the current calc is touching (ADD OR THEY SHARE A POINT)
					#do a calc and don't repeat it
					#sdf(processed_shapes, " is operated against ", index)
					if not processed_shapes.has(index):
						#sdf("new vertices = ", new_vertices)
						#do calc
						#update xor
						#list of products from xor
						var processed_merges = []
						var unprocessed_corners = []
						
						#the merged shape that becomes indicator of whether polygon
						#should create a calculation
						var polygon_merger = new_vertices
						#the expression of the xoring of above
						var new_current_XOR = [new_vertices]
						#loop through polygons to see how things should operate
						while true:
						#for i in range(2):
							##sdf("round ", i)
							var merges_done = true
							
							for pol_index in range(curr_XOR.size()):
								var polygon = curr_XOR[pol_index]
								
								#sdf("\ntesting polygon index ", pol_index,": ", polygon, "\nwith new vertices:", new_current_XOR)
								
								#check if polygon touches new vertice
								var new_pol_merge = Geometry2D.merge_polygons(polygon, polygon_merger)
								#sdf("polygon: ", polygon, "\npolygon_merger: ", polygon_merger)
								#sdf("they share an edge: ",new_pol_merge.size()<2 )
								#sdf("they share a corner: ", is_corner(polygon, polygon_merger))
								if new_pol_merge.size()<2 and not is_corner(polygon, polygon_merger):
									if pol_index not in processed_merges:
										print("xoring ", polygon, " (index ",pol_index,")", " and ", new_vertices)
										var xor_result = XOR_processing(polygon, new_vertices)
										print("result is ", xor_result)
										new_current_XOR = xor_result
										
										#updates checker for edge sharing
										polygon_merger = new_pol_merge[0]
										
										#add polygon to the processed merges we see
										processed_merges.append(pol_index)
									else:
										print('already merged')
										merges_done = false
								else:
									if is_corner(polygon, polygon_merger):
										if pol_index not in unprocessed_corners:
											print("saving ",polygon, " (index ",pol_index,")", " as corner")
											#queue polygon to be processed after all merges are processed
											unprocessed_corners.append(pol_index)
									else:
										print('already merged put in corner list')
										merges_done = false
							
							if merges_done == true:
								#sdf("\nhere are the standings for indexes covered")
								#sdf(processed_merges)
								#sdf(unprocessed_corners)
								break
										
										
						#iterate through the corners
						#sdf("what we have after merges: ", new_current_XOR)
						
						for corner_index in unprocessed_corners:
							var corner_polygon = curr_XOR[corner_index]
							#sdf("appending index ",corner_index,": ", new_current_XOR)
							new_current_XOR.append(corner_polygon)
						curr_XOR = new_current_XOR
						#sdf("FINISHED XOR:  ", index)
						#sdf("new curr_Xor = ", curr_XOR)
						
						#update merge
						curr_merge = test_merge
						#add index to the finished_list
						processed_shapes.append(index)
						print("AFTER-OP:\n","curr merge: ",curr_merge,"\nnew vertices: ", new_vertices, "\ncurr xor: ", curr_XOR)
						print()
						
				else:
					#funcitons under assumption that when all shapes are gotten to, there will always
					#be a merge or a corner check
					all_shapes_checked = false
		if all_shapes_checked == true:
			#sdf(processed_shapes)
			break
	
	#shift all polygons in current_XOR
	var shifted_curr_XOR = []
	for shape in curr_XOR:
		var shifted_shape = []
		for vertex in shape:
			shifted_shape.append(vertex-base_pos)
		shifted_curr_XOR.append(shifted_shape)
	#sdf(shifted_curr_XOR, base_pos)
	return shifted_curr_XOR
#endregion

#region XOR hole manager
#modified XOR operation between polygons that works out how to manage holes
#note that both inputs must be polygons
func XOR_processing(old_vertices: PackedVector2Array, new_vertices: PackedVector2Array) -> Array:
	#individiually calculate each shape
	var holes = []
	var outlines = []
	var xor_outputs = Geometry2D.exclude_polygons(old_vertices, new_vertices)
	
	#categorize outputs
	for xor_output in xor_outputs:
		if Geometry2D.is_polygon_clockwise(xor_output):
			holes.append(xor_output)
		else:
			outlines.append(xor_output)
	
	var ref_point
	var closest_vertex
	var closest_distance
	var chosen_outline_index
	
	#adds holes to outlines
	for hole in holes:
		#makes the reference point first vertex in shape
		ref_point = hole[0]
		closest_vertex = outlines[0][0]
		closest_distance = ref_point.distance_to(closest_vertex)
		chosen_outline_index = 0
		
		#search for hole's outline
		for outline in outlines:
			for vertex in outline:
				var new_distance = ref_point.distance_to(vertex)
				if closest_distance > new_distance:
					chosen_outline_index = outlines.find(outline)
					closest_distance = new_distance
					closest_vertex = vertex
		
		#modify outlines to include holes
		outlines[chosen_outline_index] = inject_hole(hole, outlines[chosen_outline_index], closest_vertex)
	
	#this is an array of packedvector2arrays(polygons)
	return outlines

# Add hole to outline
func inject_hole(hole: PackedVector2Array, outline: PackedVector2Array, closest_vertex: Vector2) -> PackedVector2Array:
	# Ensure the hole is closed by appending the first vertex to the end
	hole.append(hole[0])
	# Find the injection index based on the closest vertex
	var injection_index = outline.find(closest_vertex)
	if injection_index == -1:
		# Handle case where closest_vertex is not found
		#sdf("Error: closest_vertex not found in outline")
		return outline
	# Create a new array by slicing and inserting the hole
	return outline.slice(0, injection_index + 1) + hole + outline.slice(injection_index, outline.size())
#endregion

#region Corner checker
#checks if two shapes exclusively share corners
func is_corner(shape1: PackedVector2Array, shape2: PackedVector2Array) -> bool:
	var shared_vertices = []
	for vertex1 in shape1:
		for vertex2 in shape2:
			if vertex1 == vertex2:
				shared_vertices.append(vertex1)
	if shared_vertices.size() == 0:
		return false
	var intersected_polygons = Geometry2D.intersect_polygons(shape1, shape2)
	var merge_polygons =  Geometry2D.merge_polygons(shape1, shape2)
	if intersected_polygons.size() == 0 and merge_polygons.size() == 2:
		return true
	return false

#checks if two shapes share a vertice
func shared_vertices(shape1: Array, shape2: Array) -> bool:
	# Iterate over vertices in shape1
	for vertex1 in shape1:
		# Check if the vertex is also in shape2
		for vertex2 in shape2:
			if vertex2 == vertex1:
				return true  # Shared vertex found
	return false  # No shared vertices found
#endregion

#region Initialization Functions
#Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#parent connections
	playable_pieces = get_parent()
	if playable_pieces:
		playable_pieces.connect("go", _start_dragging)
		playable_pieces.connect("start_snap", _stop_dragging)
		playable_pieces.connect("display_group", _show_group)
		playable_pieces.connect("no_display_group", _no_show_group)
	identity = get_index()
	connected_node_id = -1
	
	#track position
	position = coor_to_px(tl_pos)
	grid_coor = tl_pos
	
	# for movement bounds
	screen_size = Vector2i(get_viewport_rect().size)
	
	area_offset = coor_to_px(br_pos) - coor_to_px(tl_pos)
	
	# create base shape
	#NOTE the coordinates passsed in here are relative to the position already
	base_shape_vertices = pol_coor_to_px(packed_vertices, tl_pos)
	base_pol2d.polygon = base_shape_vertices
	base_pol2d.modulate = Color(1, 0, 0) 
	
	# create clickable collision a little smaller 
	base_col2d.polygon = base_shape_vertices


#process passed metadata
func pass_metadata(vertices: Array, tl: Vector2i, br: Vector2i) -> void:
	#assert(vertices.size() > 2, "not a shape")
	packed_vertices = PackedVector2Array(vertices)
	tl_pos = tl
	br_pos = br

#save map from coordinate to position
func pass_map(pos_dic) -> void:
	map = pos_dic

# Converts a single vertex into pixel coordinates
func coor_to_px(vertex: Vector2i) -> Vector2i:
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
		var new_pos = coor_to_px(vertex) - converted_offset
		converted.append(new_pos)
	return converted
#endregion

#region Piece Move Functions
#Click event handler
func _input(event: InputEvent) -> void:
	click_event = event
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if dragging == true:
			emit_signal("free_drag", identity, event.position - mouse_offset)
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), base_col2d.polygon):
				#request to start dragging
				#sdf()
				#sdf(str(identity) +" wants to move from grid index " + str(grid_coor))
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
		#sdf(str(identity) +" has stopped at grid index " + str(grid_coor))

#facilitates the animation of snapping to grid
func snap_to_grid(grid_pos):
	snap_target = coor_to_px(grid_pos)
	snapping = true

#clamps shape movement and modifies children
func _physics_process(delta: float) -> void:
	#display related -------------------------------------------------------------------------------
	if is_in_group:
		base_pol2d.hide()
		if not is_display:
			# Remove all children except for node 0 and node 1
			for i in range(get_child_count() - 1, 1, -1):  # Iterate backward to avoid index issues
				var child_node = get_child(i)
				remove_child(child_node)  # or child_node.queue_free() to free memory
	else:
		base_pol2d.show()
		# Remove all children except for node 0 and node 
		for i in range(get_child_count() - 1, 1, -1):  # Iterate backward to avoid index issues
			var child_node = get_child(i)
			remove_child(child_node)  # or child_node.queue_free() to free memory	
	#interaction related ---------------------------------------------------------------------------
	if snapping:
		position = position.lerp(snap_target, snap_speed * delta)
		if position.distance_to(snap_target) < 1.0:
			position = snap_target
			snapping = false  # Stop snapping after reaching the target
	if dragging:
		var target_position = get_global_mouse_position() + drag_offset
		target_position = target_position.clamp(Vector2.ZERO, screen_size - area_offset)
		position = position.lerp(target_position, smooth_factor)
		position = position.clamp(Vector2.ZERO, screen_size - area_offset)
#endregion
