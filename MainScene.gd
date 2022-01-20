extends Node2D


var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
const _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")


func ready():
	randomize()
	

func _process(_delta):
	if Input.is_action_pressed("start_game"):
		_generate_map()


func _generate_map():
	for i in range(20):
		for j in range(20):
			var _wall = _wall_scene.instance()
			var x = i * 16 + 16
			var y = j * 24 + 24
			_wall.position = Vector2(x, y)
			get_parent().add_child(_wall)
