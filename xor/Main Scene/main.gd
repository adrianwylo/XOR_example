extends Node2D

signal init_grid(node_count, screen_size, margin_size)
signal init_solution(node_count, difficulty)
signal init_shapes(node_count, difficulty)


#screen size
var screen_size

#variables passed into graph creation-------------------------------------------
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size = 0.1
# amount of nodes on one side of the grid (must be greater than 1) 
#(Enact a min limit for effectiveness of puzzle)
var node_count = 20
#-------------------------------------------------------------------------------

#true if grid created
var grid_done = false
#dictionary of all grid positions populated from grid_peices 
var pos_dic 

#variables passed into shape creation-------------------------------------------
#must 1 to 5 where 5 (easy to hard)
var difficulty = randi_range(1,5)
#-------------------------------------------------------------------------------

func new_game():
	$shape_1.start($shape_1/start_position_1.position)

func _ready() -> void:
	assert(node_count > 1, "too little nodes!")
	assert(margin_size < .5, "margins too big, no space for the nodes!")
	screen_size = get_viewport_rect().size
	emit_signal("init_grid", node_count, screen_size, margin_size)
	
	while not grid_done: #don't know if this is good logic
		print("waiting for grid to finish")
	
	assert(difficulty > 0 and difficulty < 6, "outside difficulty range!")
	
	#create math behind correct solution
	emit_signal("init_solution", node_count, difficulty)
	
	#create shapes of puzzle
	emit_signal("init_shapes", node_count, difficulty)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_shape_click() -> void:
	
	pass # Replace with function body.


func _on_grid_pieces_grid_done(pos_dic: Variant) -> void:
	grid_done = true
	pos_dic = pos_dic
