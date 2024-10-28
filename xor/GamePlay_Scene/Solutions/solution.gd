extends Node2D
#Generate the solutions and thus the logic behind all assets

#for debuging
@export var new_node: PackedScene

signal create_pieces(shape_pieces, position_dictionary, correctness_dic)
signal display_solution(solution_pieces, position_dictionary)

#nested dictionary organized by 
var correctness

#scale of 1 to 5
var diff_max = 5

#Define an edge class
class Edge:
	var pos_start: Vector2i
	var pos_end: Vector2i
	var len: int
	var open: bool

	# Constructor
	func _init(xy1: Vector2i, xy2: Vector2i, isopen: bool):
		pos_start = xy1
		pos_end = xy2
		len = pos_start.distance_to(pos_end)
		open = isopen

	func close():
		open = false

	func display_info():
		print("Start Position: ", pos_start)
		print("End Position: ", pos_end)
		print("Length: ", len)
		print("Open: ", open)

#Define a vertex class
class Vertex:
	var nextVertex: Vertex
	var vertex_pos: Vector2i
	
	#you know which is the next vertex...
	func _init(pos: Vector2i, next: Vertex = null) -> void:
		nextVertex = next
		vertex_pos = pos
	
	# Points the current vertex to a new vertex
	func addVertex(new: Vertex) -> void:
		new.nextVertex = nextVertex 
		nextVertex = new

	# Removes the next vertex by skipping over it
	func subVertex() -> void:
		if nextVertex != null:
			nextVertex = nextVertex.nextVertex

	 # Function to return ordered polygon vertices starting at first
	
	# Return list of edges:
	#func list_edges() -> Array:
		#var curr_vertex = self
		#while curr_vertex != null:
			#var prev_pos = curr_vertex.vertex_pos
			#curr_vertex = curr_vertex.nextVertex
			#Edge.new(prev_pos, curr_vertex.vertex_pos, )
			
	
	#returns a list of Vector2 (as polygon)
	func make_polygon_array() -> Array:
		var polygon = []
		var current_vertex = self 
		while current_vertex != null:
			polygon.append(current_vertex.vertex_pos)
			current_vertex = current_vertex.nextVertex
		assert(polygon.size() > 2, "not a shape!")
		assert(polygon[0] == polygon[polygon.size() - 1], 
			   "First and last vertex are diff!")
		return polygon
		
	#finds top left corner bound and bottom right corner bound [(tl), (br)]
	func find_bounds() -> Array:
		var max_x
		var min_x
		var max_y
		var min_y
		var current_vertex = self 
		while current_vertex != null:
			max_y = max(current_vertex.vertex_pos.y, max_y)
			max_x = max(current_vertex.vertex_pos.x, max_x)
			min_y = min(current_vertex.vertex_pos.y, min_y)
			min_x = min(current_vertex.vertex_pos.x, min_x)
			current_vertex = current_vertex.nextVertex
		return [Vector2i(min_x, min_y), Vector2i(max_x, max_y)]

#final info datatype passed to playable_pieces scene
class playable_metadata:
	var vertices: Array
	var tl: Vector2i
	var br: Vector2i
	var area: float
	
	func _init(vertex_array: Array) -> void:
		vertices = vertex_array
		var tlbr = find_tl_br()
		tl = tlbr[0]
		br = tlbr[1]
		area = calculate_area()
	
	func find_tl_br() -> Array:
		var t = vertices[0].y
		var b = vertices[0].y
		var l = vertices[0].x
		var r = vertices[0].x
		for vertex in vertices:
			var x = vertex.x
			var y = vertex.y
			if y<t:
				t = y
			if y>b:
				b = y
			if x>r:
				r = x
			if x<l:
				l = x
		return [Vector2i(l,t),Vector2i(r,b)]
	
	# Returns the area of the shape defined by vertices
	func calculate_area() -> float:
		var result = 0.0
		var num_vertices = vertices.size()
		for q in range(num_vertices):
			var p = (q + 1) % num_vertices
			result += (vertices[q].x * vertices[p].y - vertices[q].y * vertices[p].x)
		return abs(result) * 0.5


#variables for solution creation------------------------------------------------
#must be creater than 0
var max_shape_count # for now directly equal to difficulty * 2

#ultimate # of shapes
var shape_count

#change that there will be a 22.5 degree angle (inversely proportional to diff)
var angle_225_prob

#chance of 90/45 degree angle (1-angle_255_prob)
var angle_reg_prob

#total area of pieces on grid
var total_area

#array of areas of all shape entities
var shape_areas

#array of array of vertices that make up polygon
var mapped_shapes


var display_metadata


#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------
#returns tl and br from array of vertices
func find_tl_br(Vertices: Array) -> Array:
	var t = Vertices[0].y
	var b = Vertices[0].y
	var l = Vertices[0].x
	var r = Vertices[0].x
	for vertex in Vertices:
		var x = vertex.x
		var y = vertex.y
		if y<t:
			t = y
		if y>b:
			b = y
		if x>r:
			r = x
		if x<l:
			l = x
	return [Vector2i(l,t),Vector2i(r,b)]

#using the info from grid_pieces and the node count, creates dictionary mapping
#index to position on solutions display
func create_sol_pos_dic(info: Dictionary, node_count: int) -> Dictionary:
	var len_of_playable_cell = int(info["length"]/(node_count-1))
	var final_dic = {}
	for x in range(0, node_count):
		final_dic[str(x)] = {}
		for y in range(0, node_count):
			var node_pos = len_of_playable_cell * Vector2i(x,y) + info["offset"]
			final_dic[str(x)][str(y)] = node_pos
			#create node as child
			#FOR DEBUGGING
			#var node = new_node.instantiate()
			#node.position = node_pos
			#node.initialize_data(0.01, len_of_playable_cell, Vector2i(int(x),int(y)), true)
			#add_child(node)
	return final_dic

#returns tl and br for an array of playable metadata objects
func find_all_tl_br(metadatas: Array) -> Array:
	var t = metadatas[0].tl.y
	var b = metadatas[0].br.y
	var l = metadatas[0].tl.x
	var r = metadatas[0].br.x
	for metadata in metadatas:
		#print("curtlbr:", [Vector2i(l,t),Vector2i(r,b)])
		#print("tl:", metadata.tl)
		#print("br:", metadata.br)
		t = min(t, metadata.tl.y)
		b = max(b, metadata.br.y)
		l = min(l, metadata.tl.x)
		r = max(r, metadata.br.x)
	#print("final tlbr ",  [Vector2i(l,t),Vector2i(r,b)])
	return [Vector2i(l,t),Vector2i(r,b)]

#surmises node count for solution display to maximize siz of display
func find_node_count(metadatas: Array) -> int:
	var tlbr = find_all_tl_br(metadatas)
	var size_vector: Vector2i = tlbr[1] - tlbr[0]
	return 1 + max(size_vector.x, size_vector.y)

#shifts all vertices within metadata by a position vector 
func shift_metadata(metadatas: Array, solution_pos_offsets: Vector2i) -> Array:
	var final_metadata = []
	for metadata in metadatas:
		var shifted_vertices = shift_shape(metadata.vertices, solution_pos_offsets)
		var new_metadata = playable_metadata.new(shifted_vertices)
		final_metadata.append(new_metadata)
	return final_metadata

#create a new shape from an original shape shifted by position
func shift_shape(vertices: Array, pos_offset: Vector2i) -> Array:
	var shifted_vertices = []
	for vertex in vertices:
		var shifted_vert = Vector2i(vertex.x, vertex.y) + pos_offset
		shifted_vertices.append(shifted_vert)
	return shifted_vertices

#creates a solution from playable_shapes_metadata
func create_solution(playable_shapes_metadata: Array, node_count: int) -> Array:
	var solution = []
	for metadata in playable_shapes_metadata:
		var new_shape_fits = false
		var working_metadata
		#NEED TO DEBUG
		while not new_shape_fits:
			#make a new shape
			var shape_size_vector: Vector2i = metadata.br - metadata.tl
			#might wanna check this math im watching tv
			#this ensures that the new vector is within the bounds found from the shape
			var new_position = Vector2i(randi_range(0,node_count - shape_size_vector.x - 1),randi_range(0,node_count - shape_size_vector.y - 1))
			#print("new_position = ", new_position)
			var new_shape = shift_shape(metadata.vertices,new_position - metadata.tl)
			#print("new shape is ", new_shape)
			#establish vertex overlaps needed to add new random shape
			var no_of_overlaps_needed = solution.size() - 3
			if no_of_overlaps_needed < 1:
				no_of_overlaps_needed = 1
			#count of how many 
			var no_of_overlaps = 0
			for past_shape_metadata in solution:
				#find out if a point in the new shape is in a past_shape's region
				var vertex_in_past_shape = false
				for vertex in new_shape:
					if Geometry2D.is_point_in_polygon(vertex, past_shape_metadata.vertices):
						var past_shape_tlbr = find_tl_br(past_shape_metadata.vertices)
						if Vector2i(past_shape_tlbr[1] - past_shape_tlbr[0]) != Vector2i(1,1):
							for past_vertex in past_shape_metadata.vertices:
								if vertex in past_shape_metadata.vertices:
									if randf() <= 0.30:
										vertex_in_past_shape = true
										break
				if vertex_in_past_shape:
					no_of_overlaps += 1
			if no_of_overlaps >= no_of_overlaps_needed or solution.size() == 0:
				var tlbr = find_tl_br(new_shape)
				working_metadata = playable_metadata.new(new_shape)
				new_shape_fits = true
		solution.append(working_metadata)
	return solution

#creates the new playable_metadata objects in array such that they don't overlap
func create_playable(list_of_shapes: Array, node_count: int) -> Array:
	#eventual list of playable_metadata objects
	var final = []
	for shape in list_of_shapes:
		var clear = false
		while not clear:
			var old_tlbr = find_tl_br(shape)
			var shape_size_vector: Vector2i = old_tlbr[1] - old_tlbr[0]
			var new_position = Vector2i(randi_range(0,node_count - shape_size_vector.x - 1),randi_range(0,node_count - shape_size_vector.y - 1))
			
			#new shape with the corrected vertices
			var new_shape = shift_shape(shape,new_position - old_tlbr[0])
			#iterates through all shapes to see if there is an overlap
			var no_collisions = true
			for prev_shape in final:
				var are_overlaps = false
				for vertex in new_shape:
					if Geometry2D.is_point_in_polygon(vertex, prev_shape.vertices):
						are_overlaps = true
						break
				if are_overlaps:
					no_collisions = false
					break
			if no_collisions:
				final.append(playable_metadata.new(new_shape))
				clear = true
	return final
			
			
#converts coordinate in graph into a string for identification
func coor_to_string(coordinate: Vector2i) -> String:
	return str(coordinate.x) + ',' + str(coordinate.y)


#takes the list of playable metadata, and returns a nested dictionary
#of solution's relative distances
#{point 1:{point 2: vector difference, .........}, .....}
func make_solution_metadata(metadatas: Array) -> Dictionary:
	var final_dic = {}
	for index1 in range(metadatas.size()):
		var first_top_left_coor = metadatas[index1].tl
		var size_vector1: Vector2i = metadatas[index1].br - metadatas[index1].tl
		var key1 = coor_to_string(size_vector1)
		if final_dic.has(key1):
			for index2 in range(metadatas.size()):
				if index2 != index1:
					var second_top_left_coor = metadatas[index2].tl
					var size_vector2: Vector2i = metadatas[index2].br - metadatas[index2].tl
					var key2 = coor_to_string(size_vector2)
					if final_dic[key1].has(key2):
						final_dic[key1][key2].append(second_top_left_coor - first_top_left_coor)
					else:
						final_dic[key1][key2] = [second_top_left_coor - first_top_left_coor]
		else:
			var new_dic = {}
			for index2 in range(metadatas.size()):
				if index2 != index1:
					var second_top_left_coor = metadatas[index2].tl
					var size_vector2: Vector2i = metadatas[index2].br - metadatas[index2].tl
					var key2 = coor_to_string(size_vector2)
					if new_dic.has(key2):
						new_dic[key2].append(second_top_left_coor - first_top_left_coor)
					else:
						new_dic[key2] = [second_top_left_coor - first_top_left_coor]
			final_dic[key1] = new_dic
	return final_dic
	

#reorders list of playable_metadata objects based on area (smaller area = higher index) 
func sort_by_area(metadata_list: Array) -> Array:
	#print(metadata_list)
	var final_metadata = metadata_list
	final_metadata.sort_custom(func(a, b): return a.area > b.area)
	#print(final_metadata)
	return final_metadata
	
#script call
func _on_main_init_solution(node_count: Variant, difficulty: Variant, playable_pos_dic: Variant, solution_pos_info: Variant) -> void:
	#UNFINISHED CODE BLOCK FOR DIFFICULTY MANAGEMENT ----------------------------------------------vv
	#max_shape_count = node_count*2
	#total_area = floor(node_count*node_count*0.9)
	#process_difficulty(difficulty)
	#map_shapes()
	#AT THE MOMENT THESE ARE JUST RANDO SHAPES, BUT WE NEED PLAYABLE PIECES AND SOLUTION PIECES
	#WHEN PASSED IN, THESE HAVE TO BE POSITIONS NOT JUST COORDINATES
	#SHAPES WILL BE DRAWN WITH CLOCKWISE DIRECTION
	#UNFINISHED CODE BLOCK FOR DIFFICULTY MANAGEMENT ----------------------------------------------^^
	
	#for now shapes created will involve 9 shapes:
	var playable_shapes =  [[Vector2(10,0),Vector2(11,0),Vector2(11,1),Vector2(10,1)],
							[Vector2(0,0),Vector2(3,0),Vector2(3,3),Vector2(0,3)],
							[Vector2(4,5),Vector2(4,7),Vector2(6,7),Vector2(6,5)],
							[Vector2(4,5),Vector2(4,7),Vector2(6,7),Vector2(6,5)],
							[Vector2(7,5),Vector2(7,8),Vector2(9,8),Vector2(9,5)],
							[Vector2(10,5),Vector2(10,7),Vector2(13,7),Vector2(13,5)]]
							#[Vector2(10,0),Vector2(12,0),Vector2(12,1),Vector2(10,1)],
							#[Vector2(10,0),Vector2(11,0),Vector2(11,2),Vector2(10,2)]]
	#
	var playable_shapes_metadata = create_playable(playable_shapes, node_count)
	
	playable_shapes_metadata = sort_by_area(playable_shapes_metadata)
	
	#processing of solution_shapes dictionary
	var solution_shapes_metadata = create_solution(playable_shapes_metadata, node_count)
	
	#calculate the size of grid for creating solution display
	var sol_dic_node_count = find_node_count(solution_shapes_metadata)
	
	#calculating 
	var sol_tlbr = find_all_tl_br(solution_shapes_metadata)
	
	var size_vector: Vector2i = sol_tlbr[1] - sol_tlbr[0]
	
	#shift necessary for solution to be displayed in center
	var shift_vec = Vector2i(ceil((sol_dic_node_count  - 1- size_vector.x)/2),floor((sol_dic_node_count  - 1 - size_vector.y)/2)) - sol_tlbr[0]
	solution_shapes_metadata = shift_metadata(solution_shapes_metadata, shift_vec)
	
	
	correctness = make_solution_metadata(solution_shapes_metadata)
	#print(correctness)
	var solution_pos_dic = create_sol_pos_dic(solution_pos_info, sol_dic_node_count)
	
	#call to create playable pieces
	emit_signal("create_pieces", playable_shapes_metadata, playable_pos_dic, correctness)
	#call to create solution display
	emit_signal("display_solution", solution_shapes_metadata, solution_pos_dic)

#region UNFINISHED DIFDFICULTY -> RANDOM SOLUTION FUNCTIONS
#randomly chooses a direction (input = blacklisted options)
func choose_direction(no: Array) -> int:
	assert(len(no) < 4, "can't say no to all 4 buddy")
	var dir = randi_range(0,3)
	if dir in no:
		return choose_direction(no)
	else:
		return dir

#create semi random array of areas for shapes
func make_area_bins(diff, total_area, shape_count) -> Array:
	var base_val = floor(total_area/shape_count)
	
	#more difficulty is less variance (possible variation based on total area)
	var variance = floor((diff_max + 1 - diff)/diff_max*(base_val/2))
	var shape_areas = []
	var accounted_total = 0
	for i in range(shape_count):
		#this doesnt work completely for creating skews for low difficulties
		var variation = randi_range(-1*variance,variance)
		var shape_area = base_val + variation
		shape_areas.append(shape_area)
		accounted_total += shape_area
	
	var missing_diff = total_area - accounted_total 
	
	if missing_diff != 0:
		for i in range(abs(missing_diff)):
			if missing_diff > 0:
				shape_areas[i % shape_count]+=1
				missing_diff-=1
			elif missing_diff < 0 and shape_areas[i % shape_count] > 1:
				shape_areas[i % shape_count]-=1
				missing_diff+=1
			else:
				continue
	return shape_areas

#populates parameters for solution generator
func process_difficulty(diff) -> void:
	print("difficulty is " + str(diff))
	#percentage of max_shape number created
	var shape_count_percent = float(diff)/diff_max + randf_range(-0.05, 0.05)
	shape_count = int(round(max_shape_count * shape_count_percent))
	print("there are " + str(shape_count) + " shapes!")
	
	#will use these probabilities in shape generation
	if diff < diff_max/4:
		angle_225_prob = 0.4
	elif diff< diff_max/2:
		angle_225_prob = 0.2
	else:
		angle_225_prob = 0
	angle_reg_prob = (1 - angle_225_prob)/2
	
	#calculations for shape variation  
	shape_areas = make_area_bins(diff, total_area, shape_count)
	print("here are the areas that add up to " + str(total_area))
	print(shape_areas)

#returns true or false with a given probability
func probability_check(prob: float) -> bool:
	return randf() <= prob

#the following functions return vertex linked list:
#return rect
func plot_rect(start: Vector2i, end: Vector2i, x: int, y: int, direction: int, 
			   is_baseshape: bool = false) -> Vertex:
	#override
	if is_baseshape:
		direction = 3
	assert(direction < 4 and direction >= 0, "thats not a direction!")
	match direction:
		0: #up
			assert(end == start + Vector2i(x, 0), "bad input (up)")
			var br = Vertex.new(end)
			var tr = Vertex.new(start + Vector2i(x, -y), br)
			var tl = Vertex.new(start + Vector2i(0, -y), tr)
			var bl = Vertex.new(start, tl)
			return bl
		1: #down
			assert(end == start + Vector2i(-x, 0), "bad input (down)")
			var tl = Vertex.new(end)
			var bl = Vertex.new(start + Vector2i(-x, y), tl)
			var br = Vertex.new(start + Vector2i(0, y), bl)
			var tr = Vertex.new(start, br)
			return tr
		2: #left
			assert(end == start + Vector2i(0, -y), "bad input (left)")
			var tr = Vertex.new(end)
			var tl = Vertex.new(start + Vector2i(-x, -y), tr)
			var bl = Vertex.new(start + Vector2i(-x, 0), tl)
			var br = Vertex.new(start, bl)
			return br
		3: #right
			assert(end == start + Vector2i(0, y), "bad input (right)")
			var bl = Vertex.new(end)
			var br = Vertex.new(start + Vector2i(x, y), bl)
			var tr = Vertex.new(start + Vector2i(x, 0), br)
			var tl = Vertex.new(start, tr)
			if is_baseshape: 
				#closes off shape
				bl.addVertex(Vertex.new(start))
			return tl
		_:
			return null

#return triangle
func plot_tri(start: Vector2i, end: Vector2i, x: int, y: int, direction: int, 
			   is_baseshape: bool = false) -> Vertex:
	#override
	if is_baseshape:
		direction = 3
	assert(direction < 4 and direction >= 0, "thats not a direction!")
	match direction:
		0: #up
			assert(end == start + Vector2i(x, 0), "bad input (up)")
			var br = Vertex.new(end)
			var tr = Vertex.new(start + Vector2i(x, -y), br)
			var bl = Vertex.new(start, tr)
			#blacklisted
			var tl = start + Vector2i(0, -y)
			return bl
		1: #down
			assert(end == start + Vector2i(-x, 0), "bad input (down)")
			var tl = Vertex.new(end)
			var bl = Vertex.new(start + Vector2i(-x, y), tl)
			var tr = Vertex.new(start, bl)
			#blacklisted
			var br = start + Vector2i(0, y)
			return tr
		2: #left
			assert(end == start + Vector2i(0, -y), "bad input (left)")
			var tr = Vertex.new(end)
			var tl = Vertex.new(start + Vector2i(-x, -y), tr)
			var br = Vertex.new(start, tl)
			#blacklisted
			var bl = start + Vector2i(-x, 0)
			return br
		3: #right
			assert(end == start + Vector2i(0, y), "bad input (right)")
			var bl = Vertex.new(end)
			var br = Vertex.new(start + Vector2i(x, y), bl)
			var tl = Vertex.new(start, br)
			#blacklisted
			var tr = start + Vector2i(x, 0)
			if is_baseshape: 
				#closes off shape
				bl.addVertex(Vertex.new(start))
			return tl
		_:
			return null
		

#Populates mapped_shapes (Todo)
func map_shapes() -> void:
	#NOTES:
	#[0 = up, 1 = down, 2 = left, 3 = right]
	#this is an up triangle:                   this is a down triangle
	#      /|                                  ____.
	#     / |                                  |  /
	#    /  |                                  | /
	#   /___|                                  |/
	#
	#for 22.5 degree angles, we use probability check to determine which side is
	#longer 
	
	#for 2 choice items (l/r and u/d)
	#[0 = u/d, 1 = l/r]
	
	for shape_areas in shape_areas:
		#this it the top/leftmost corner of shape (does not have to be vertex)
		var tl_reference_pos
		var br_reference_pos
		
		#lengths of edges + coordinates
		var o_left = {}
		var o_right = {}
		var o_down = {}
		var o_up = {}
		
		#used to call on dics based on randomized index
		var open_lines = [o_left, o_right, o_down, o_up]
		
		#keep track of unavailable lines
		var blacklist = []
		var unfilled_area = shape_areas
		
		var shape
		
		#create base shape
		#starting objects = trianngle types x1, x2
		# (arbitrary)     = rect of 1 x 1, 2 x 1, 2 x 3
		if probability_check(angle_225_prob):
			var shape_allignment = choose_direction([])
			
			
		#choose shape
		#choose rotation
		
		
		#fill up edges of shape until can't anymore
		
			#choose side
			#choose shape
			#calc edge possibilities
			#update reference_pos
#endregion
