extends Node2D
#Generate the solutions and thus the logic behind all assets

signal create_pieces(shape_pieces, position_dictionary)
signal display_solution(solution_pieces, position_dictionary)

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
	
	func _init(vertex_array: Array, top_left: Vector2i, bottom_right: Vector2i) -> void:
		vertices = vertex_array
		tl = top_left
		br = bottom_right
		

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

#array of metadata for playable pieces
var playable_shapes_metadata

var display_metadata
#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------

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

#shift the shape and finds tl/br -> makes class for movement to playable_shape
func create_packed_array(Vertices: Array, Position: Vector2i) -> playable_metadata:
	var shifted_vertices: PackedVector2Array = []
	for vertex in Vertices:
		var shifted_vert = vertex + Position
		shifted_vertices.append(shifted_vert)
	var tlbr = find_tl_br(shifted_vertices)
	var final = playable_metadata.new(shifted_vertices,tlbr[0],tlbr[1])
	return final

#returns tl and br from array of vertices
func find_tl_br(Vertices: Array) -> Array:
	var t = Vertices[0].y
	var b = Vertices[0].y
	var l = Vertices[0].y
	var r = Vertices[0].y
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
	return final_dic

#returns tl and br for an array of array of vertices
func find_all_tl_br(metadatas: Array) -> Array:
	var t = metadatas[0].tl.y
	var b = metadatas[0].br.y
	var l = metadatas[0].tl.x
	var r = metadatas[0].br.x
	for metadata in metadatas:
		print("curtlbr:", [Vector2i(l,t),Vector2i(r,b)])
		print("tl:", metadata.tl)
		print("br:", metadata.br)
		t = min(t, metadata.tl.y)
		b = max(b, metadata.br.y)
		l = min(l, metadata.tl.x)
		r = max(r, metadata.br.x)
	return [Vector2i(l,t),Vector2i(r,b)]

#surmises node count for solution display to maximize siz of display
func find_node_count(metadatas: Array) -> int:
	var tlbr = find_all_tl_br(metadatas)
	var size_vector: Vector2i = tlbr[1] - tlbr[0]
	return 1 + max(size_vector.x, size_vector.y)

#shifts all vertices within metadata by a position vector (subtraction)
func shift_metadata(metadatas: Array, solution_pos_offsets: Vector2i) -> Array:
	var final_metadata = []
	for metadata in metadatas:
		var shifted_vertices = []
		for vector in metadata.vertices:
			print("old vec: ", vector)
			var new_vec = Vector2i(vector.x,vector.y) - solution_pos_offsets
			print("new vec: ", new_vec)
			shifted_vertices.append(new_vec)
		var new_metadata = playable_metadata.new(shifted_vertices,metadata.tl-solution_pos_offsets, metadata.br-solution_pos_offsets)
		final_metadata.append(new_metadata)
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
	playable_shapes_metadata = [playable_metadata.new([Vector2(5,0),
											 Vector2(8,0),
											 Vector2(8,3),
											 Vector2(7,3),
											 Vector2(7,1),
											 Vector2(6,1),
											 Vector2(6,3),
											 Vector2(5,3)],
											 Vector2(5,0),
											 Vector2(8,3)),
					  playable_metadata.new([Vector2(10,0),
											 Vector2(11,0),
											 Vector2(11,1),
											 Vector2(10,1)], 
											 Vector2(10,0),
											 Vector2(11,1)),
					  playable_metadata.new([Vector2(5,5),
											 Vector2(5,7),
											 Vector2(7,7),
											 Vector2(7,5)], 
											 Vector2(5,5),
											 Vector2(7,7)),
					  playable_metadata.new([Vector2(8,5),
											 Vector2(8,8),
											 Vector2(10,8),
											 Vector2(10,5)], 
											 Vector2(8,5),
											 Vector2(10,8)),
					  playable_metadata.new([Vector2(9,5),
											 Vector2(9,8),
											 Vector2(11,8),
											 Vector2(11,5)], 
											 Vector2(9,5),
											 Vector2(11,8))]

	emit_signal("create_pieces", playable_shapes_metadata, playable_pos_dic)
	
	var solution_shapes_metadata = playable_shapes_metadata
	var solution_pos_offsets = find_all_tl_br(solution_shapes_metadata)[0]
	solution_shapes_metadata = shift_metadata(solution_shapes_metadata, solution_pos_offsets)
	var solution_pos_dic = create_sol_pos_dic(solution_pos_info, find_node_count(solution_shapes_metadata))
	
	print("solution_pos_offsets:", solution_pos_offsets)
	print("solution_pos_dic:", solution_pos_dic)
	
	emit_signal("display_solution",solution_shapes_metadata, solution_pos_dic)
