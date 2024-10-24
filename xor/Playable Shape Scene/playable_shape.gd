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
	#sdf("I'm connected to ", connected_node_id, " and i want to join ", other_node_id, "?")
	#if connected_node_id == -1:
		#connected_node_id = other_node_id
	emit_signal("overlapping", other_node_id, identity)
		

#handlers for noting loss of collision
func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	var other_shape_node = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index)).get_parent()
	var other_node_id = other_shape_node.return_id()
	#sdf("I'm connected to ", connected_node_id, " and i want to leave ", other_node_id, "?")
	#if connected_node_id == other_node_id:
		
	emit_signal("not_overlapping",other_node_id , identity)
		#connected_node_id = -1
		
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
		
	##sdf("In this group for id:", identity, " the overlaps are ", overlapping_ids)
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
		polygon_node.modulate = Color(1, 0.894118, 0.768627, 1) 
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

#checks if two packed arrays are equal
func are_lists_equal(list1: PackedVector2Array, list2: PackedVector2Array) -> bool:
		for i in range(list1.size()):
			if list1[i] != list2[i]:
				return false
		return true

#checks if two shapes are same (considers clockwise polarity + vertex ordering)
func same_shape(shape1: PackedVector2Array, shape2: PackedVector2Array) -> bool:
	if shape1.size() != shape2.size():
		return false
	# Now check regular
	for i in range(shape2.size()):
		var shifted_shape2 = PackedVector2Array()
		for j in range(shape2.size()):
			shifted_shape2.append(shape2[(i + j) % shape2.size()])
		if are_lists_equal(shape1, shifted_shape2):
			return true

	# Now check reverse 
	var reversed_shape2 = shape2.duplicate()
	reversed_shape2.reverse()
	for i in range(reversed_shape2.size()):
		var rotated_reversed_shape2 = PackedVector2Array()
		for j in range(reversed_shape2.size()):
			rotated_reversed_shape2.append(reversed_shape2[(i + j) % reversed_shape2.size()])
		if are_lists_equal(shape1, rotated_reversed_shape2):
			return true
	return false

func find_shape_key(shape: PackedVector2Array, cutout_shapes: Dictionary) -> int:
	for key in cutout_shapes:
		if same_shape(cutout_shapes[key], shape):
			return key
	#key not found
	return -1

#Performs XOR operation on all children (TODO)
func XOR_polygons(display_id: int, children_shapes_data: Dictionary):
	var base_pos = children_shapes_data[display_id]["position"]
	var cutout_count = {} #{int(key): int(Amount of times overlapped)....}
	var cutout_shapes = {} #{int(key): PackedVector2Array(shape)....}
	
	#fill up the dictionary for referencing shapes
	var shape_info = {} #{int(shape_id): Packed_Vertice_Array(Base Shape)
	for shape_id in children_shapes_data:
		shape_info[shape_id] = children_shapes_data[shape_id]["abs base vertices"]
	
	#initialize cutouts
	var first_id = shape_info.keys()[0]
	var first_shape = shape_info[first_id]
	var new_key = randi()
	cutout_shapes[new_key] = first_shape
	cutout_count[new_key] = 1
	
	var sliced_shape_ids = shape_info.keys().slice(1, shape_info.size())  # Start from the second key
	#print("we begin initializing with ", first_id, " and now have to go over ", sliced_shape_ids)
	#print("BEGIN XOR ===============")
	for id in sliced_shape_ids:
		#print("looking at ", id)
		var must_add_keys = []
		var must_delete_keys = [] 
		var new_shape = shape_info[id]
		var shape_key = find_shape_key(new_shape, cutout_shapes)
		if shape_key == -1:
			#print(new_shape, " is an UNseen new shape")
			#iterate through all known shapes and check if there should be a xor occuring
			
			#per iteration, the saved overlap portion will get subtracted from new_shape
			#what's leftover will be added as a new entry to end of forloop
			var final_shape_additions: Array[PackedVector2Array] = [new_shape]
			
			#print("\nbeginning loop for cutout_shapes:")
			#iterate over all old cutout shapes and see how they interact with new ones
			for key in cutout_shapes:
				#print(cutout_shapes)
				#print("begin cutout loop cycle on key ", key)
				var old_shape = cutout_shapes[key]
				#print(old_shape, " is the old shape")
				var test_merge = Geometry2D.merge_polygons(old_shape,new_shape)
				var test_intersect = Geometry2D.intersect_polygons(old_shape,new_shape)
				#print("merging gets: ", test_merge)
				#print("intersecting gets: ", test_intersect)
				#check if new shape needs to interact with old shape
				if  filter_holes(test_merge) == 1 and test_intersect.size() != 0:
					#ensures there is an overlap
					#print("there are new shapes from this")
					var old_shape_count = cutout_count[key]
					#print("old_shape's count is ", old_shape_count)
					#categorize new overlaps as new shapes with new count
					var areas_intersected = test_intersect
					#all overlaps necessitate a new shape
					#print("\nevaluating areas intersected")
					for area_intersected in areas_intersected:
						var new_val = {							
							"shape": area_intersected,
							"count": 1 + old_shape_count
						}
						#print("(touched) queing adding ", new_val)
						must_add_keys.append(new_val)
						
					
					
					#categorize clipped old shapes as new shapes with old count
					#print("\nevaluating areas untouched")
					var areas_untouched = clip_all_polygons([old_shape], new_shape)
					#print("untouched areas = ", areas_untouched)
					if not areas_untouched.is_empty():
						#if there are shapes from the clip
						for area_untouched in areas_untouched:
							var new_val = {
								"shape": area_untouched,
								"count": old_shape_count
							}
							#print("(untouched) queing adding ", new_val)
							must_add_keys.append(new_val)
										
					#queue delete the old shape because it has been cut up now
					must_delete_keys.append(key)
					#update the final shape addition
					final_shape_additions = clip_all_polygons(final_shape_additions,old_shape)
				#else:
					#print("there is no interaction between cutout and new shape")
			
			
			#add final shape as new shape
			if not final_shape_additions.is_empty():
				#print("Leftover portion of new_shape: ", final_shape_additions, "\nis being added to data")
				for final_shape_addition in final_shape_additions:
					new_key = -1
					while cutout_shapes.has(new_key) or new_key == -1:
						new_key = randi() # Generate a random unique key
					cutout_shapes[new_key] = final_shape_addition
					cutout_count[new_key] = 1
		else:
			#print(new_shape, " is a seen new shape")
			#need to add to the count of that shape
			cutout_count[shape_key]+=1
		
		#delete the keys queued for deletion
		#print("deleting queued keys")
		for deletion_key in must_delete_keys:
			cutout_count.erase(deletion_key)
			cutout_shapes.erase(deletion_key)
		
		#add new shapes
		#print("adding queued shapes")
		for struct in must_add_keys:
			#print("adding ", struct)
			new_key = -1
			while cutout_shapes.has(new_key) or new_key == -1:
				new_key = randi() # Generate a random unique key
			cutout_shapes[new_key] = struct["shape"]
			cutout_count[new_key] = struct["count"]
			
		
		#print("\ncutout_shapes is: ", cutout_shapes, "\ncutout_count is: ", cutout_count)
	
	#print("\n\nDONE WITH ITERATION")
	#putting the overlaps that have an odd count in final array
	var unshifted_final = []
	for key in cutout_count:
		if cutout_count[key]%2 == 1:
			unshifted_final.append(cutout_shapes[key])
	
	#shifting overlaps relative to display_id position
	var shifted_final = []
	for shape in unshifted_final:
		var shifted_shape = []
		for vertex in shape:
			shifted_shape.append(vertex - base_pos)
		shifted_final.append(shifted_shape)
	#print("\n\nUnshifted Output: ", unshifted_final)
	#print("\n\nFinal Output: ", shifted_final)
	return shifted_final
	

	
	#
	#
	#var cutouts = {} #{index:[shape1, shape2...]
	##create cutouts dictionary
	#for index in children_shapes_data:
		#cutouts[index] = children_shapes_data[index]["abs base vertices"]
	##begin nested loop of xoring (clip_polygon)
	##print("BEGIN XOR ===============", "\nCutouts = ", cutouts)
	#var curr_XOR = []
	#for index_cuttee in cutouts:
		##make this a list because result of cut could be more
		#var new_cutouts: Array[PackedVector2Array] = []
		#new_cutouts.append(PackedVector2Array(cutouts[index_cuttee]))
		#
		##per iteration over the cutter, the ammount of shapes to be "cut"
		##will only grow (because a clipped shape can be divided into two
		##thus the new cutouts are constantly updated as we go through the 
		##indexes
		#for index_cutter in cutouts:
			#if index_cuttee != index_cutter:
				##print(index_cuttee, " is cuttee and ",index_cutter, " is cutout")
				##print(cutouts[index_cutter], "(always 1) cuts out ", new_cutouts, "(",new_cutouts.size(),") to get ")
				#new_cutouts = clip_all_polygons(new_cutouts, cutouts[index_cutter])
				##print(new_cutouts)
					#
		##append final cutouts to the current_XOR
		#curr_XOR.append_array(new_cutouts)
	##print("\n", curr_XOR, " is ready to be shifted")
	##shift all polygons in current_XOR
	#
	#
	#
	#
	#var shifted_curr_XOR = []
	#for shape in curr_XOR:
		#var shifted_shape = []
		#for vertex in shape:
			#shifted_shape.append(vertex-base_pos)
		#shifted_curr_XOR.append(shifted_shape)
	##print("final shift: ", shifted_curr_XOR, base_pos)
	#return shifted_curr_XOR



func filter_holes(shapes: Array) -> int:
	var non_hole_count = 0
	for shape in shapes:
		if not Geometry2D.is_polygon_clockwise(shape):
			non_hole_count+=1
	return non_hole_count

#returns a list of a shapes(a cut by a single cutter)
func clip_all_polygons(cuttee_shapes: Array[PackedVector2Array], cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	#print("Begin clip_all")
	var final_list: Array[PackedVector2Array] = []
	for cuttee in cuttee_shapes:
		#print("working with ", cutter, " cutting ", cuttee)
		#if there is a single merge between cuts, clip should happen
		if filter_holes(Geometry2D.merge_polygons(cuttee, cutter)) == 1:
			#print("there is an intersection, so clip is happening")
			var new_cutout =  Geometry2D.clip_polygons(turn_pol_clockwise(cuttee), turn_pol_clockwise(cutter))
			#print("clip result: ", new_cutout)
			#assert(not new_cutout.is_empty(), "merge check has a flaw")
			#check if the result is a hole
			if new_cutout.size() > 1:
				#process the two polygons into a hole
				new_cutout = Hole_processing(new_cutout)
				#print("processed holes: ", new_cutout)
				for hole_cutout in new_cutout: 
					final_list.append(PackedVector2Array(hole_cutout))
			elif new_cutout.size() == 1:
				#print("add the one")
				#append the new 
				final_list.append(PackedVector2Array(new_cutout[0]))
			
				
		else:
			#print("there is no intersection")
			final_list.append(PackedVector2Array(cuttee))
		#print("End clip_all ",final_list, "\n")
	return final_list
	

func turn_pol_clockwise(shape: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.is_polygon_clockwise(shape):
		var reversed_shape = PackedVector2Array()
		for i in range(shape.size() - 1, -1, -1):
			reversed_shape.append(shape[i])
		return reversed_shape
	return shape 

		
		
#endregion

#region hole manager
#manages multi packedvectorarray results from geo2d functions
#note that both inputs must be polygons
func Hole_processing(clip_outputs: Array) -> Array:
	#individiually calculate each shape
	var holes = []
	var outlines = []
	#categorize outputs
	for clip_output in clip_outputs:
		if Geometry2D.is_polygon_clockwise(clip_output):
			holes.append(clip_output)
		else:
			outlines.append(clip_output)
	#print("outlines: ", outlines, "\nholes: ", holes)
	
	
	#saved hole info
	var chosen_hole_vertex_index # note that this represents which vertex
	var hole_vertex
	
	#saved outline info
	var chosen_outline_index  # note that this represents which outline
	var closest_vertex
	
	#distance between hole_vertex and closest_vertex
	var closest_distance
	
	#adds holes to outlines
	for hole in holes:
		#which point in hole being used as opener
		chosen_hole_vertex_index = 0
		
		#begin with first vertex on first outline
		closest_vertex = outlines[0][0]
		#outline index
		chosen_outline_index = 0
		
		#initial distance
		closest_distance = hole[chosen_hole_vertex_index].distance_to(closest_vertex)
		
		#search for hole's outline
		for outline in outlines:
			#loop through all hole vertices
			for index in range(hole.size()):
				var curr_hole_vertex = hole[index]
				for vertex in outline:
					var new_distance = curr_hole_vertex.distance_to(vertex)
					if closest_distance > new_distance:
						chosen_outline_index = outlines.find(outline)
						closest_vertex = vertex
						chosen_hole_vertex_index = index
						closest_distance = new_distance
		#check if the hole found is valid, or a shape splitter
		if shared_vertices(outlines[chosen_outline_index],hole) > 1:
			#print("THIS ISNT A HOLE, IT's A SHAPE SPLITTER")
			outlines[chosen_outline_index] = Geometry2D.clip_polygons(outlines[chosen_outline_index], hole)[0]
			outlines.append(Geometry2D.clip_polygons(outlines[chosen_outline_index], hole)[1])
		else:
			#print("THIS IS A HOLE")
			#modify outlines to include holes
			outlines[chosen_outline_index] = inject_hole(shift_hole(hole, chosen_hole_vertex_index), outlines[chosen_outline_index], closest_vertex)
	#this is an array of packedvector2arrays(polygons)
	return outlines


# Reorders vertices in a hole such that the starting point is at a new index
func shift_hole(hole: PackedVector2Array, start_index: int) -> PackedVector2Array:
	var shifted_hole = PackedVector2Array()
	# Append the part from start_index to the end
	for i in range(start_index, hole.size()):
		shifted_hole.append(hole[i])
	# Append the part from the beginning to start_index
	for i in range(0, start_index):
		shifted_hole.append(hole[i])
	return shifted_hole
	
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
	var no_shared_vert = shared_vertices(shape1, shape2)
	if no_shared_vert == 0:
		return false
	var intersected_polygons = Geometry2D.intersect_polygons(shape1, shape2)
	var merge_polygons =  Geometry2D.merge_polygons(shape1, shape2)
	if intersected_polygons.size() == 0 and merge_polygons.size() == 2:
		return true
	return false

#checks if two shapes share a vertice
func shared_vertices(shape1: Array, shape2: Array) -> int:
	# Iterate over vertices in shape1
	var shared_no = 0
	for vertex1 in shape1:
		# Check if the vertex is also in shape2
		for vertex2 in shape2:
			if vertex2 == vertex1:
				shared_no+=1  # Shared vertex found
	return shared_no # No shared vertices found
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
	base_pol2d.modulate = Color(1, 0.894118, 0.768627, 1)
	
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
