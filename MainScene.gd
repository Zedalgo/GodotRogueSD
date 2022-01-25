extends Node2D

var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")

var _new_GetCoord = preload("res://library/GetCoord.gd").new()

var player:Sprite
var wall:Sprite

var map:Array = []

var map_generated:bool = false

var tile_width:int = 16
var tile_height:int = 24


# Theoretically runs when the main scene happens for the first time
func _ready():
	randomize()

# Handles non-movement player inputs
func _unhandled_input(Input):
	if Input.is_action_pressed("start_game") && map_generated == false:
		$SpaceToGenMap.visible = false
		map_generated = true
		print("Generating map...")
		generate_map()
		print("Map generated.")
	if map_generated == true:
		if Input.is_action_pressed("select"):
			get_clicked_grid_tile()
		if Input.is_action_pressed("debug_key"):
			print(_new_GetCoord.vector_to_index(player.position.x, player.position.y))
		if Input.is_action_pressed("move_up"):
			try_move(0, -1)


# Currently generates a static map
func generate_map():
	for i in range(33):
		map.append([])
		for j in range(17):
			var _wall = _wall_scene.instance()
			var x:int = i * 16 + 8
			var y:int = j * 24 + 12
			if (j == 0 || j == 16) || (i == 0 || i == 32):
				
				_wall.position = Vector2(x, y)
				get_parent().add_child(_wall)
				map[i].append([_wall])
			else:
				var _floor = _floor_scene.instance()
				var location:Vector2 = _new_GetCoord.index_to_vector(i, j)
				_floor.position = location
				get_parent().add_child(_floor)
				#map[i][j].append(_floor)
	
	player = _player_scene.instance()
	player.position = _new_GetCoord.index_to_vector(3, 3)
	get_parent().add_child(player)


func get_clicked_grid_tile():
	var click_loc = get_global_mouse_position()
	var index_loc = _new_GetCoord.vector_to_index(click_loc.x, click_loc.y)
	print(index_loc)
	return Vector2(index_loc)

func try_move(dx, dy):
	var try_vec_x = player.position.x + (dx * tile_width)
	var try_vec_y = player.position.y + (dy * tile_height)
	var try_index:Vector2 = _new_GetCoord.vector_to_index(try_vec_x, try_vec_y)
	if map[try_index.x][try_index.y] == wall:
		print("That's a wall")
	else:
		player.position.x = try_vec_x
		player.position.y = try_vec_y
