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

#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



#INCOMPLETE populates parameters for solution generator
func process_difficulty(diff) -> void:
	#percentage of max_shape number created
	var shape_count_percent = diff/5 + (randi() % 11-5)/100#random modifier
	shape_count = floor(max_shape_count * shape_count_percent)
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
	
	
	

func _on_main_init_solution(node_count: Variant, difficulty: Variant) -> void:
	#note that max_shape_count is moreso tied to node count than anything
	max_shape_count = difficulty*2
	#note that this is in units of grid_index squared
	total_area = floor(node_count*node_count*0.9)
	
	process_difficulty(difficulty)
	
	
	
	pass # Replace with function body.
