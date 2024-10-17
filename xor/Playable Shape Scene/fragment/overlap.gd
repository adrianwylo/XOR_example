extends Area2D

#holds ID's of shapes involved with node (DOES NOT INCLUDE ITSELF)
var others_involved = []
var base: bool
var polarity: bool

#returns an array of polygons (in vertices form)
func ret_polygons():
	var shapes = []
	for child in get_children():
		shapes.append(child.polygon)
	return shapes

#creates a display of some vertices
func add_polygon(vertices: Array):
	# Create a new Polygon2D node
	var polygon = Polygon2D.new()
	polygon.polygon = vertices
	#NOTE for debugging
	polygon.modulate = Color(randf(), randf(), randf())
	add_child(polygon)

# repurposes children and adds/subtracts them to fit array
func replace_polygon(polygons: Array):
	var child_index = 0
	var max_index = get_child_count() - 1
	var no_pol = polygons.size()
	#shave off extra children
	if max_index + 1 > no_pol:
		for i in range(max_index+1 - no_pol):
			del_polygon()
	for polygon in polygons:
		if child_index <= max_index:
			var child = get_child(child_index)
			child.polygon = polygon	
			child_index+=1
		else:
			add_polygon(polygon)

#deletes polygon at highest index (of children and shapes)
func del_polygon():
	var last_index = get_child_count() - 1
	var last_polygon = get_child(last_index)
	remove_child(last_polygon)
	last_polygon.queue_free() 

#shows polarity
func show_polarity():
	return polarity

#sets whether visible or not
func set_polarity(visible: bool):
	polarity = visible
	if polarity:
		show()
	else:
		hide()

#returns shape ids in overlap
func show_overlap() -> Array:
	return others_involved

#Checks if the instance is an overlaying of ONLY id's listed in array
#you can't just say B.indexes is in A, ,ust be B.indexes + B is in A
func is_in(other_indexes: Array) -> bool:
	others_involved.sort()
	other_indexes.sort() 
	return others_involved == other_indexes

#checks if this is a base fragment
func is_base(i_b):
	base = i_b

#removes the shape ids in array from others_involved
func stop_overlap(other_indexes: Array) -> void:
	others_involved = others_involved.filter(
	func(id):
		return not other_indexes.has(id)
	)

#initializes the list of overlapped shapes
func set_overlaps(indexes: Array) -> void:
	indexes.sort()
	others_involved = indexes

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	assert(get_child_count() > 0, "no vertices in this overlap")
