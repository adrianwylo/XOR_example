extends Node2D

signal init_grid(node_count, screen_size, margin_size)
signal init_shapes(shape_count)#can fill more later, for now let's make 2x2 squares

#screen size
var screen_size

#variables passed into graph creation-------------------------------------------
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size = 0.05
# amount of nodes on one side of the grid (must be greater than 1)
var node_count = 4
#-------------------------------------------------------------------------------

#dictionary of all grid positions populated from grid_peices 
var pos_dic 

#variables passed into shape creation-------------------------------------------
#must 1 to 5 where 5 (easy to hard)
var difficulty = 1
#-------------------------------------------------------------------------------

func new_game():
	$shape_1.start($shape_1/start_position_1.position)

func _ready() -> void:
	assert(node_count > 1, "too little nodes!")
	assert(margin_size < .5, "margins too big, no space for the nodes!")
	screen_size = get_viewport_rect().size
	emit_signal("init_grid", node_count, screen_size, margin_size)
	pos_dic = await $Grid_Pieces.grid_done
	
	assert(difficulty > 0 and difficulty < 6, "outside difficulty range!")
	emit_signal("init_shapes", node_count, difficulty)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_shape_click() -> void:
	
	pass # Replace with function body.
