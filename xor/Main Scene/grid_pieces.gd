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
#length of one grid cell
var len_of_cell
#-------------------------------------------------------------------------------

#signal for completion
signal grid_done(pos_dic)

signal snap_info(grid_pos)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Called by main
func _on_main_init_grid(n_c, s_s, m_s) -> void:
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
	
	#not counting margins, length of one side of full grid
	var grid_size = grid_size_m * (1 - margin_size*2)
	var margin_offset = Vector2(grid_size*margin_size, grid_size*margin_size)
	
	#changes position of grid
	grid_offset += margin_offset
	len_of_cell = grid_size/(node_count-1)
	
	#decide scale of nodes with reference to screen size
	size_scale = 0.02#temp placeholder
	
	#added 2 to contribute to the a buffer 
	for x in range(0, node_count):
		pos_dic[str(x)] = {}
		for y in range(0, node_count):
			var is_edge = (x == node_count - 1 or y == node_count - 1)
			#(- 1 because includes 2 divisions = 3 points)
			var node_pos = len_of_cell * Vector2(x,y) + grid_offset
			pos_dic[str(x)][str(y)] = Vector2i(node_pos.x, node_pos.y) 
			#create node as child
			var node = new_node.instantiate()
			node.connect("snap_found", _on_snap_found)
			node.position = node_pos
			node.initialize_data(size_scale, len_of_cell, Vector2i(int(x),int(y)), is_edge)
			add_child(node)

	#might want to consider looking at how screen size changes will affect the grid		
	

func _on_snap_found(grid_coor):
	emit_signal("snap_info", grid_coor)

#query children for a snap
func _on_playable_pieces_snap(id: Variant, corner_pos: Variant) -> void:
	var child_count = get_child_count()
	for i in range(child_count):
		var child = get_child(i)
		child.check_snap(corner_pos)
	
