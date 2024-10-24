extends Node2D

@export var new_shape: PackedScene
#reference to child node for timing lock
@onready var lock_timer = $Timer
#for testing purposes
@onready var timer = $testTimer

#Track if the object is being dragged
var dragging = false 

#Current dragged shape index
var dragged_shape_id = -1
#reference to dragged child
var dragged_child: Node

#searching dictionary for child reference nodes
#matches id to node
var all_shapes: Dictionary

#an array of an array of indexes representing what has been overlapped
#note that if A and B are connected, and B and C are connected
#they are all found in the dictionary, but their list of connections won't list
#anything they aren't connected to
var overlap_groups: Dictionary

#Ack signals for shapes
signal go(id)
signal snap(id, mouse_pos)
signal start_snap(grid_pos, id)
signal display_group(display_id, children)
signal no_display_group(id)

#class definition for overlap metadata
class overlap:
	#shapes involved in calculation
	var indexes_involved: Dictionary
	#shape chosen to display overlap
	var display_index: int
	
	func _init(indexes: Array, new_dic: Dictionary = {}) -> void:
		# create dic
		if new_dic.size() == 0:
			indexes_involved = {}
			#makes a dictionary that lists involved shapes and their collsions
			for index in indexes:
				var collisions = []
				for collided_index in indexes:
					if collided_index != index:
						collisions.append(collided_index)
				indexes_involved[index] = collisions
		# inject dic
		else:
			indexes_involved = new_dic
		#recalc display_index
		display_index = int(indexes_involved.keys()[0])
		for key in indexes_involved.keys():
			var int_key = int(key)
			if int_key > int(display_index):
				display_index = int_key

	#check if id is in overlap
	func id_is_in_list(id: int) -> bool:
		return indexes_involved.has(id)
	
	#add a specific collision to overlap (TODO)
	func add_col_to_list(new_id_1: int, new_id_2: int) -> void:
		var cur_display_index = self.display_index
		var found_1 = new_id_1 in indexes_involved.keys()
		var found_2 = new_id_2 in indexes_involved.keys()
		if found_1 and found_2:
			if new_id_2 not in indexes_involved[new_id_1]:
				indexes_involved[new_id_1].append(new_id_2)
			if new_id_1 not in indexes_involved[new_id_2]:
				indexes_involved[new_id_2].append(new_id_1)
		elif found_1:
			if new_id_2 not in indexes_involved[new_id_1]:
				indexes_involved[new_id_1].append(new_id_2)
			indexes_involved[new_id_2] = [new_id_1]
			if new_id_2 > cur_display_index:
				display_index = new_id_2
		elif found_2:
			if new_id_1 not in indexes_involved[new_id_2]:
				indexes_involved[new_id_2].append(new_id_1)
			indexes_involved[new_id_1] = [new_id_2]
			if new_id_1 > cur_display_index:
				display_index = new_id_1
		else:
			assert(found_1 or found_2, "can't add a connection if no id's are alr there")
	
	#recalculates display_index with stipulation to ignor input
	func recalc_display_wo(bad_index: int):
		display_index = -1
		for key in indexes_involved.keys():
			var int_key = int(key)
			if bad_index != int_key:
				if int_key > int(display_index):
					display_index = int_key
		assert(display_index != -1, "this may not be a group")
		
	
	#sever a specific collision from overlap
	#creturns an empty array if nothing needs to be done
	#returns the two separated dictionaries if there is something to be done
	func sub_col_from_list(new_id_1: int, new_id_2: int) -> Array:
		#sdf("running a subtraction")
		var cur_display_index = self.display_index
		var must_reevaluate = false
		var found_1 =new_id_1 in indexes_involved.keys()
		var found_2 = new_id_2 in indexes_involved.keys()
		assert(found_1 and found_2, "Both ids must exist to remove a connection")
		
		#remove connection path from 1
		if new_id_2 in indexes_involved[new_id_1]:
			indexes_involved[new_id_1].erase(new_id_2)
		#remove connect path from 2
		if new_id_1 in indexes_involved[new_id_2]:
			indexes_involved[new_id_2].erase(new_id_1)
		
		#check if the leftover dictionary is still connected
		var groupA = need_to_split(indexes_involved)
		##sdf("pathfind result has ", groupA)
		##sdf("original has ", indexes_involved)
		#check if this group size is lesser than list of all shapes
		if groupA.size() < indexes_involved.size():
			#sdf("must split up")
			#create two dictionaries of shape_ids and the shapes they connect to
			var split_1 = {}
			var split_2 = {}
			for index in indexes_involved:
				if index in groupA:
					split_1[index] = indexes_involved[index]
				else:
					split_2[index] = indexes_involved[index]
			#if the split creates groups of one, the og group is erased
			if split_1.size() == 1 and split_2.size() == 1:
				#sdf("no more groups")
				return [[]]
			#if one of the split arrays is a group of one, the other replaces
			#the og group
			elif split_1.size() == 1:
				indexes_involved = split_2
				if display_index == split_1.keys()[0]:
					must_reevaluate = true
			elif split_2.size() == 1:
				indexes_involved = split_1
				if display_index == split_2.keys()[0]:
					must_reevaluate = true
			#return the new indexes_involved dictionaries for the current and new node
			else:
				#sdf("new group from split")
				return [split_1, split_2]
		#no changes in children have to happen
		#readjustments after divide if there is no splitting in group
		if must_reevaluate:
			#recalc display_index
			display_index = int(indexes_involved.keys()[0])
			for key in indexes_involved.keys():
				var int_key = int(key)
				if int_key > int(display_index):
					display_index = int_key
		return []
	
	#returns array of indexes found from pathfinder
	func need_to_split(index_dic) -> Array:
		var visited_vertices = []
		var stack = [index_dic.keys()[0]]  
		while stack.size() > 0:
			var current_vertex = stack.pop_back() 
			if current_vertex not in visited_vertices:
				visited_vertices.append(current_vertex)
				for neighbor in index_dic[current_vertex]:
					if neighbor not in visited_vertices:
						stack.append(neighbor)
		return visited_vertices
	
	#removes all the keys in the array from indexes_involved
	func remove_indexes(indexes: Array) -> void:
		#sdf("removed_indexes")
		for key in indexes:
			if key in indexes_involved:
				indexes_involved.erase(key)
		display_index = int(indexes_involved.keys()[0])
		for key in indexes_involved.keys():
			var int_key = int(key)
			if int_key > int(display_index):
				display_index = int_key

#region Overlap Calcs
#signal from child that theres a collision (TODO)
func _on_piece_overlap(other_id: int, id: int):
	#sdf("Test overlap of ", id, " and ", other_id)
	var id_group_key = -1
	var other_id_group_key = -1
	
	#check if the overlap is a bust
	#if is_corner(all_shapes[other_id].return_base_and_pos()["abs base vertices"], 
				 #all_shapes[id].return_base_and_pos()["abs base vertices"]):
		##sdf(other_id, "'s corners touch ", id)
		#return
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key
	
	# Case 1: Neither ID is in any group, create a new group
	if id_group_key == -1 and other_id_group_key == -1:
		#sdf("//Case 1 for ", id, " and ", other_id)
		var key = -1
		while overlap_groups.has(key) or key == -1:
			key = randi()
		overlap_groups[key] = overlap.new([other_id, id])
		#sdf(overlap_groups[key].indexes_involved)
	
	# Case 2: other_id is in a group, add id to it
	elif id_group_key == -1 and other_id_group_key != -1:
		#sdf("//Case 2 for ", id, " and ", other_id)
		overlap_groups[other_id_group_key].add_col_to_list(id,other_id)
		#sdf(overlap_groups[other_id_group_key].indexes_involved)

	# Case 3: id is in a group, add other_id to it
	elif id_group_key != -1 and other_id_group_key == -1:
		#sdf("//Case 3 for ", id, " and ", other_id)
		overlap_groups[id_group_key].add_col_to_list(id,other_id)
		#sdf(overlap_groups[id_group_key].indexes_involved)

	# Case 4: Both IDs are in different groups, merge the groups by creating a new one that represents all of them
	elif id_group_key != other_id_group_key:
		#sdf("//Case 4 for ", id, " and ", other_id)
		var og_dic = overlap_groups[id_group_key].indexes_involved
		var other_dic = overlap_groups[other_id_group_key].indexes_involved
		var combined_dic = {}
		# Merge og_dic
		for index in og_dic:
			if index not in combined_dic:
				combined_dic[index] = []
				for collision in og_dic[index]:
					if collision not in combined_dic[index]:
						combined_dic[index].append(collision)
		
		# Merge other_dic
		for index in other_dic:
			if index not in combined_dic:
				combined_dic[index] = []
				for collision in other_dic[index]:
					if collision not in combined_dic[index]:
						combined_dic[index].append(collision)
		
		#gen key for new 
		var key = -1
		while overlap_groups.has(key) or key == -1:
			key = randi()
		overlap_groups[key] = overlap.new([],combined_dic)
		# Remove the old and new group
		overlap_groups.erase(id_group_key)
		overlap_groups.erase(other_id_group_key)  
		#sdf(overlap_groups[key].indexes_involved)
	# Case 5: Both IDs are in same group, update index tables accordingly
	else:
		#sdf("//Case 5 for ", id, " and ", other_id)
		overlap_groups[other_id_group_key].add_col_to_list(id,other_id)
		#sdf(overlap_groups[other_id_group_key].indexes_involved)
			
			
# Signal from child indicating there's no more collision
func _on_piece_no_overlap(other_id: int, id: int):
	#sdf("Test cease overlap of ", id, " and ", other_id)
	var id_group_key = -1
	var other_id_group_key = -1
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key
		if id_group_key != -1 and other_id_group_key != -1:
			break
	
	# means that there is a connection to be severed
	if other_id_group_key == id_group_key and id_group_key != -1:
		#sdf("begin separating ", other_id, " and ", id)
		#for simplicity's sale
		var old_key = id_group_key
		var sep_vertices = overlap_groups[id_group_key].sub_col_from_list(other_id, id)
		if sep_vertices.size() == 2:
			var group_1 = sep_vertices[0]
			var group_2 = sep_vertices[1]
			
			#create new key for new_group
			var new_key = -1
			while overlap_groups.has(new_key) or new_key == -1:
				new_key = randi() # Generate a random unique key

			var new_group_dic = {}
			for index in group_2:
				#repopulate new dic with group_2 entries
				new_group_dic[index] = overlap_groups[old_key].indexes_involved[index]
			overlap_groups[new_key] = overlap.new([], new_group_dic)
			
			#redefine old group by removing indexes in group 2
			overlap_groups[old_key].remove_indexes(group_2.keys())
			
		#the group is empty after operation and must be removed from overlap_groups
		elif sep_vertices.size() == 1:
			overlap_groups.erase(old_key)
	
#endregion

#region Life of the Drag
#ack function picking a piece
func _on_piece_occupy_drag(id) -> void:
	if dragging == false and dragged_shape_id == -1:
		#id's are the same as indexes because they don't change
		dragged_shape_id = id
		dragged_child = get_child(dragged_shape_id)
		
		#turn on flag for going
		dragging = true
		emit_signal("go", id)

#ack function for letting go of piece (requests grid nodes for info)
func _on_piece_free_drag(id, corner_pos, area_offset) -> void:
	if dragged_shape_id == id:
		emit_signal("snap", id, corner_pos, Vector2(area_offset.x,area_offset.y))

#pipe grid coordinates to shape
func _on_grid_pieces_snap_info(grid_pos: Variant) -> void:
	emit_signal("start_snap", grid_pos, dragged_shape_id)

# Reopen for next piece picked
func _on_piece_continue_q(id) -> void:
	if dragged_shape_id == id:
		#gives time for snap so piece can't be taken
		lock_timer.start(0.25)

#finishes snap operation after timer and reopens drag
func _on_lock_timer_timeout() -> void:
	dragged_shape_id = -1
	dragging = false 
	lock_timer.stop()
#endregion

#region Initialization
#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant, pos_dic: Variant) -> void:
	for polygon in shape_pieces:
		shape_create(polygon, pos_dic)

#create new instance of the playable_shape scene
func shape_create(metadata, map) -> void:
	var shape = new_shape.instantiate()
	shape.pass_metadata(metadata.vertices, metadata.tl, metadata.br)
	shape.pass_map(map)
	shape.connect("free_drag", _on_piece_free_drag)
	shape.connect("occupy_drag", _on_piece_occupy_drag)
	shape.connect("continue_q", _on_piece_continue_q)
	shape.connect("overlapping", _on_piece_overlap)
	shape.connect("not_overlapping", _on_piece_no_overlap)
	add_child(shape)
	all_shapes[get_child_count()-1] = shape
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the timer with 10 seconds interval for testing purposes
	timer.wait_time = 7
	#timer.start()
	overlap_groups = {}
	all_shapes = {}

#endregion

#region Action
#Calculates overlaps constantly and changes views
func _physics_process(delta: float) -> void:
	for id in all_shapes:
		var key = find_key_with_id(id)
		if key != -1:
			#update display indexes based on whether theres a shape being dragged:
			overlap_groups[key].recalc_display_wo(dragged_shape_id)
			var grouped_children = []
			for index in overlap_groups[key].indexes_involved:
				grouped_children.append(all_shapes[index])
			emit_signal("display_group",overlap_groups[key].display_index, grouped_children)
			
		else:
			emit_signal("no_display_group", id)

# debug rendition of process
func _on_test_timer_timeout() -> void: 
	#sdf("\n\n\n NEW ROUND----------------------------------------------------")
	for id in all_shapes:
		var key = find_key_with_id(id)
		if key != -1:
			#sdf("\nindexes in group = ", overlap_groups[key].indexes_involved)
			#update display indexes based on whether theres a shape being dragged:
			overlap_groups[key].recalc_display_wo(dragged_shape_id)
			var grouped_children = []
			for index in overlap_groups[key].indexes_involved:
				grouped_children.append(all_shapes[index])
			emit_signal("display_group",overlap_groups[key].display_index, grouped_children)
			
		else:
			emit_signal("no_display_group", id)
#endregion

#region Helpers
#Find the key associated with the id
func find_key_with_id(id) -> int:
	for key in overlap_groups:
		if id in overlap_groups[key].indexes_involved:
			return key
	return -1

#detects whether there is a phony collision
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
		#sdf("intersecsetwseef ",intersected_polygons)
		return true
	return false
#endregion
