extends Node2D

var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")

var _new_GetCoord = preload("res://library/GetCoord.gd").new()

var map_walkable:Array

var buffer_check:bool = false
var map_generated:bool = false

var time:float = 0
var buffer_time:float = 0.2

func ready():
	randomize()


func _process(delta):
	if buffer_check == true:
		if map_generated == false:
			if Input.is_action_pressed("start_game"):
				_generate_map()
				$SpaceToGenMap.visible = false
				map_generated = true
				buffer_check = false
				time = 0
		if Input.is_action_pressed("select"):
			get_clicked_grid_tile()
			buffer_check = false
			time = 0
	
	if time < buffer_time:
		time += delta
	elif buffer_check == false:
		buffer_check = true
	else:
		pass


# Currently generates a static map
func _generate_map():
	for i in range(1,32):
		for j in range(1,16):
			var _floor = _floor_scene.instance()
			var location:Vector2 = _new_GetCoord.index_to_vector(i, j)
			_floor.position = location
			get_parent().add_child(_floor)
	for i in range(33):
		for j in range(17):
			var _wall = _wall_scene.instance()
			var x:int = i * 16 + 8
			var y:int = j * 24 + 12
			if (j == 0 || j == 16) || (i == 0 || i == 32):
				_wall.position = Vector2(x, y)
				get_parent().add_child(_wall)
	var _player = _player_scene.instance()
	_player.position = _new_GetCoord.index_to_vector(3, 3)
	get_parent().add_child(_player)


func get_clicked_grid_tile():
	var click_loc = get_global_mouse_position()
	var index_loc = _new_GetCoord.vector_to_index(click_loc.x, click_loc.y)
	print(index_loc)
	return Vector2(index_loc)
