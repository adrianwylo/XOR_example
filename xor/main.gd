extends Node2D

@export var new_node: PackedScene

#screen size
var screen_size

#variables for graph creation---------------------------------------------------
#scale used to determine sizes of nodes
var size_scale
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size = 0.05
# amount of nodes on one side of the grid (must be greater than 1)
var node_count = 4
#dictionary of all grid positions: 
#{x_coor:"{y_coor: something else maybe, ...}, ...}
var pos_dic = {}

func get_size_scale() -> int:
	return size_scale

func create_grid() -> void:
	screen_size = get_viewport_rect().size
	
	# counting margins, length of one side of grid
	var grid_size_m = min(screen_size.x, screen_size.y)
	var grid_offset = Vector2((screen_size.x - grid_size_m) / 2, (screen_size.y - grid_size_m)/ 2)
	
	# counting margins, length of one side of grid
	var grid_size = grid_size_m * (1 - margin_size*2)
	var margin_offset = Vector2(grid_size*margin_size, grid_size*margin_size)
	
	#add margin offset to grid_offset
	grid_offset += margin_offset
	
	#decide scale of nodes with reference to screen size
	size_scale = 0.7 #temp placeholder
	
	#added 2 to contribute to the a buffer 
	for x in range(0, node_count):
		pos_dic[x] = {}
		for y in range(0, node_count):
			var node_pos = (grid_size/(node_count-1)) * Vector2(x,y) + grid_offset
			pos_dic[x][y] = node_pos
			node_create(node_pos)
			
	
	


func _ready() -> void:
	print('test')
	create_grid()
	
	new_game()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func new_game():
	var node_count = 2
	$shape_1.start($shape_1/start_position_1.position)
	$shape_2.start($shape_2/start_position_2.position)

func node_create(pos: Vector2) -> void:
	# Create a new instance of the node scene.
	var node = new_node.instantiate()
	node.position = pos
	node.initialize_size_scale(size_scale)
	# Spawn the node into Main.
	add_child(node)
