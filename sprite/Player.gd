extends Sprite

var tile_height = 24
var tile_width = 16


# Handles player inputs
func _unhandled_input(Input):
	if Input.is_action_pressed("move_down"):
		try_move(0, 1)
#	if Input.is_action_pressed("move_up"):
#		try_move(0, -1)
	if Input.is_action_pressed("move_right"):
		try_move(1, 0)
	if Input.is_action_pressed("move_left"):
		try_move(-1, 0)

func try_move(dx, dy):
	position.x += (dx * tile_width)
	position.y += (dy * tile_height)
