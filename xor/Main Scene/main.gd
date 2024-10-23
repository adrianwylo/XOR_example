extends Node2D

#signals to initiate game states
signal init_grid(node_count, screen_size, margin_size)
signal init_solution(node_count, difficulty, pos_dic)

#screen size
var screen_size

#variables passed into graph creation-------------------------------------------
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size = 0.1
# amount of nodes on one side of the grid (must be greater than 1) 
#(Enact a min limit for effectiveness of puzzle)
var node_count = 10

#-------------------------------------------------------------------------------

#true if grid created
var grid_done = false
#dictionary of all grid positions populated from grid_peices 
var map 

#variables passed into shape creation-------------------------------------------
#must 1 to 5 where 5 (easy to hard)
var difficulty = randi_range(1,5)
#-------------------------------------------------------------------------------

#Game initializer
func _ready() -> void:
	assert(node_count > 1, "too little nodes!")
	assert(margin_size < .5, "margins too big, no space for the nodes!")
	screen_size = get_viewport_rect().size
	emit_signal("init_grid", node_count, screen_size, margin_size)
	while not grid_done: #don't know if this is good logic
		print("waiting for grid to finish")
	assert(difficulty > 0 and difficulty < 6, "outside difficulty range!")
	#create math behind correct solution and generates all pieces
	emit_signal("init_solution", node_count, difficulty, map)




func _on_grid_pieces_grid_done(pos_dic: Variant) -> void:
	grid_done = true
	map = pos_dic
	
