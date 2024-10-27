extends Node2D

@export var new_node: PackedScene

#variables for graph creation---------------------------------------------------
#screen size
var screen_size
#proportion of grid side that is left/topmost margin (must be between 0 and .5)
var margin_size
# amount of nodes on one side of the grid (must be greater than 1)
var node_count
#dictionary of all grid positions for playable pieces: 
var playable_pos_dic = {}
#dictionary of all grid positions for solution display:
var solution_pos_dic_info 
#-------------------------------------------------------------------------------

#signal for completion
signal grid_done(playable_pos_dic)

signal snap_info(grid_pos)

# Called by main
func _on_main_init_grid(n_c, s_s, m_s) -> void:
	node_count = n_c
	screen_size = s_s
	margin_size = m_s
	create_grids()
	emit_signal("grid_done", playable_pos_dic, solution_pos_dic_info)

#1. creates the child nodes to make up grid
#2. populates playable_pos_dic:
#   {x_index:"{y_index: (x_coor, y_coor), ...}, ...}
func create_grids() -> void:	
	#Code right now expects that the orientation is horizontal
	#decide scale of nodes with reference to screen size
	var size_scale = node_count * 0.001 #THIS IS A MAGIC NUMBER
	
	#counting margins, length of one side of grid
	var playable_grid_size_full = screen_size.y
	#offset of playable grid from top left
	var playable_grid_offset = Vector2i((screen_size.x - playable_grid_size_full)/2, 0)
	
	#not counting margins, length of one side of full grid
	var playable_grid_size_nodes = playable_grid_size_full * (1 - margin_size*2)
	
	#additional margins because of offset
	var margin_offset = Vector2i(playable_grid_size_nodes * margin_size, playable_grid_size_nodes * margin_size)
	
	#changes position of grid
	playable_grid_offset += margin_offset
	var len_of_playable_cell = int(playable_grid_size_nodes/(node_count-1))
	
		
	#added 2 to contribute to the a buffer 
	for x in range(0, node_count):
		playable_pos_dic[str(x)] = {}
		for y in range(0, node_count):
			var is_edge = (x == node_count - 1 or y == node_count - 1)
			#(- 1 because includes 2 divisions = 3 points)
			var node_pos = len_of_playable_cell * Vector2i(x,y) + playable_grid_offset
			playable_pos_dic[str(x)][str(y)] = node_pos
			
			#create node as child
			var node = new_node.instantiate()
			node.position = node_pos
			node.initialize_data(size_scale, len_of_playable_cell, Vector2i(int(x),int(y)), is_edge)
			add_child(node)
			
	#data needed for the solution display:
	#this will be shared with the grid offset
	var solution_grid_margin_size = margin_offset.x
	#size of solution_grid_w/o margins
	var solution_grid_size_nodes = (screen_size.x - playable_grid_size_full)/2 - solution_grid_margin_size
	#offset of solution grid
	var solution_grid_offset = Vector2i(int(screen_size.x - (screen_size.x - playable_grid_size_full)/2), 
										int((screen_size.y - solution_grid_size_nodes)/2))
	solution_pos_dic_info = {
		"length" = solution_grid_size_nodes,
		"offset" = solution_grid_offset
	}
#query children for a snap
func _on_playable_pieces_snap(id: Variant, corner_pos: Variant, area_offset: Variant) -> void:
	var bot_right_pos = corner_pos + area_offset
	var top_left_pos = corner_pos
	var child_count = get_child_count()		
	for i in range(child_count):
		var tlchild = get_child(i)
		if tlchild.pos_found_in_node(top_left_pos):
			for a in range(child_count):
				var brchild = get_child(a)
				if brchild.pos_found_in_node(bot_right_pos):
					emit_signal("snap_info", tlchild.ret_grid_location())

	
