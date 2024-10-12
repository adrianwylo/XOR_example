extends Node2D
#Generate the solutions and thus the logic behind all assets

#scale of 1 to 5
var diff_max = 5

#Define an edge class
class Edge:
	var pos_start: Vector2
	var pos_end: Vector2
	var len: int
	var open: bool

	# Constructor
	func _init(x1: int, x2: int, y1: int, y2: int, startindex: int, isopen: bool):
		pos_start = Vector2(x1, y1)
		pos_end = Vector2(x2, y2)
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
	var vertex_pos: Vector2
	
	#you know which is the next vertex...
	func _init(pos: Vector2, next: Vertex = null):
		nextVertex = next
		vertex_pos = pos
	
	 # Points the current vertex to a new vertex
	func addVertex(new: Vertex):
		new.nextVertex = nextVertex 
		nextVertex = new

	# Removes the next vertex by skipping over it
	func subVertex():
		if nextVertex != null:
			nextVertex = nextVertex.nextVertex

	 # Function to return ordered polygon vertices starting at first
	func make_polygon_array() -> Array:
		var polygon = []
		var current_vertex = self 
		while current_vertex != null:
			polygon.append(current_vertex.coordinate)
			current_vertex = current_vertex.nextVertex
		assert(polygon.size() > 2, "not a shape!")
		assert(polygon[0] == polygon[polygon.size() - 1], "First and last vertex are diff!")
		return polygon

#variables for solution creation------------------------------------------------
#must be creater than 0
var max_shape_count # for now directly equal to difficulty * 2
#ultimate # of shapes
var shape_count

#change that there will be a 22.5 degree angle (inversely proportional to difficulty)
var angle_225_prob

#chance of 90/45 degree angle (1-angle_255_prob)
var angle_reg_prob

#total area of pieces on grid
var total_area

#array of areas of all shape entities
var shape_areas

#array of array of vertices that make up polygon
var mapped_shapes
#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------

#randomly chooses a direction (input = blacklisted options)
func choose_direction(no: Array) -> int:
	assert(len(no) < 4, "can't say no to all 4 buddy")
	var dir = randi_range(0,3)
	if dir in no:
		return choose_direction(no)
	else:
		return dir

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

#create seni random array of areas for shapes
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
#return rect (todo)
func plot_rect(start: Vector2, end: Vector2, x: int, y: int, direction: int, is_baseshape: bool = false) -> Array:
	if is_baseshape:
		
	assert(direction < 4 and direction >= 0, "thats not a direction!")
	match direction:
		0: #up
			
		1: #down
			
		2: #left
			
		3: #right
			
		
		# Default case (similar to 'else')
	var tl = tl_ref
	var tr = tl_ref + Vector2(x,0)
	var bl = tl_ref + Vector2(0,y)
	var br = tl_ref + Vector2(x,y)
	return [tl, tr, bl, br]

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
	
	#SHAPES WILL BE DRAWN WITH CLOCKWISE DIRECTION
	
	for shape_areas in shape_areas:
		#this it the top/leftmost corner of shape (does not have to be vertex)
		var tl_reference_pos = Vector2(0,0)
		var br_reference_pos = Vector2(0,0)
		
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

#script call
func _on_main_init_solution(node_count: Variant, difficulty: Variant) -> void:
	#note that max_shape_count is moreso tied to node count than anything
	max_shape_count = node_count*node_count/3
	#note that this is in units of grid_index squared
	total_area = floor(node_count*node_count*0.9)
	
	process_difficulty(difficulty)
	#populates
	map_shapes()
	
	
	pass # Replace with function body.
