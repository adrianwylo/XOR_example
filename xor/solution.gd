extends Node2D
#Generate the solutions and thus the logic behind all assets

#scale of 1 to 5
var diff_max = 5

#variables for solution creation---------------------------------------------------
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

#
#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
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

#randomly chooses a direction (input = blacklisted options)
func choose_direction(no: Array) -> int:
	assert(len(no) < 4, "can't say no to all 4 buddy")
	var dir = randi_range(0,3)
	if dir in no:
		return choose_direction(no)
	else:
		return dir
	
	


func map_shapes() -> void:
	#NOTES:
	#[0 = up, 1 = down, 2 = left, 3 = right]
	#this is an up triangle:                   this is a down triangle
	#      /|                                  ____.
	#     / |                                  |  /
	#    /  |                                  | /
	#   /___|                                  |/
	#
	#for 22.5 degree angles, we use probability check to determine which side is longer
	
	#for 2 choice items (l/r and u/d)
	#[0 = u/d, 1 = l/r]
	
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
		
		#choose shape
		#choose rotation
		
		
		#fill up edges of shape until can't anymore
		
			#choose side
			#choose shape
			#calc edge possibilities
			#update reference_pos
			
			
		
		

func _on_main_init_solution(node_count: Variant, difficulty: Variant) -> void:
	#note that max_shape_count is moreso tied to node count than anything
	max_shape_count = node_count*node_count/3
	#note that this is in units of grid_index squared
	total_area = floor(node_count*node_count*0.9)
	
	process_difficulty(difficulty)
	map_shapes()
	
	
	pass # Replace with function body.
