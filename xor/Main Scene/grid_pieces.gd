extends Node2D

@export var new_node: PackedScene

#variables for graph creation---------------------------------------------------
#screen size
var screen_size
#scale used to determine sizes of nodes
var size_scale
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size
# amount of nodes on one side of the grid (must be greater than 1)
var node_count
#dictionary of all grid positions: 
var pos_dic = {}
#-------------------------------------------------------------------------------

#signal for completion
signal grid_done(pos_dic)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Called by main
func _on_main_init_grid(n_c, s_s, m_s) -> void:
	print("init grid")
	node_count = n_c
	screen_size = s_s
	margin_size = m_s
	create_grid()
	emit_signal("grid_done", pos_dic)
	
#1. creates the child nodes to make up grid
#2. populates pos_dic:
#   {x_index:"{y_index: (x_coor, y_coor), ...}, ...}
func create_grid() -> void:	
	#counting margins, length of one side of grid
	var grid_size_m = min(screen_size.x, screen_size.y)
	var grid_offset = Vector2((screen_size.x - grid_size_m)/2, 
							  (screen_size.y - grid_size_m)/2)
	
	#not counting margins, length of one side of grid
	var grid_size = grid_size_m * (1 - margin_size*2)
	var margin_offset = Vector2(grid_size*margin_size, grid_size*margin_size)
	
	#add margin offset to grid_offset
	grid_offset += margin_offset
	
	#decide scale of nodes with reference to screen size
	size_scale = 0.2#temp placeholder
	
	#added 2 to contribute to the a buffer 
	for x in range(0, node_count):
		pos_dic[x] = {}
		for y in range(0, node_count):
			#(- 1 because includes 2 divisions = 3 points)
			var node_pos = (grid_size/(node_count-1)) * Vector2(x,y) + grid_offset
			pos_dic[x][y] = node_pos
			node_create(node_pos)

	#might want to consider looking at how screen size changes will affect the grid		

# initiates node scenes as main children
func node_create(pos: Vector2) -> void:
	# Create a new instance of the node scene.
	var node = new_node.instantiate()
	node.position = pos
	node.initialize_size_scale(size_scale)
	add_child(node)	
