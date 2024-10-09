extends Node2D

@export var new_shape: PackedScene

#variables for shape creation-------------------------------------------
#must be creater than 0
var shape_count
#WILL BE MORE... (consolidate difficulty rating within this function)
#-------------------------------------------------------------------------------

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#INCOMPLETE
func process_difficulty(diff) -> void:
	shape_count = 2
	assert(shape_count > 0, "too little shapes!")

	


func _on_main_init_shapes(n_count, diff) -> void:
	process_difficulty(diff)
	#arbitrary assignments
	for shape in range(0, shape_count):
		shape_create(Vector2(1,1))
		
	pass # Replace with function body.
	

func shape_create(pos: Vector2) -> void:
	# Create a new instance of the node scene.
	var shape = new_shape.instantiate()
	shape.position = pos
	# Spawn the node into Main.
	add_child(shape)	
