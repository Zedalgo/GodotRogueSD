extends Node2D

var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _dwarf_scene:PackedScene = preload("res://sprite/Dwarf.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")


var _new_GetCoord = preload("res://library/GetCoord.gd").new()

var player:Sprite
var wall:Sprite

var entities:Array = []
var map:Array = []

var map_generated:bool = false

var tile_width:int = 16
var tile_height:int = 24


# Theoretically runs when the main scene happens for the first time
func _ready():
	randomize()

# Handles player inputs
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
		if Input.is_action_pressed("move_down"):
			try_move(0, 1)
		if Input.is_action_pressed("move_up"):
			try_move(0, -1)
		if Input.is_action_pressed("move_right"):
			try_move(1, 0)
		if Input.is_action_pressed("move_left"):
			try_move(-1, 0)


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
				map[i].append(_wall)
			else:
				var _floor = _floor_scene.instance()
				var location:Vector2 = _new_GetCoord.index_to_vector(i, j)
				_floor.position = location
				get_parent().add_child(_floor)
				map[i].append(_floor)
	
	# Turns the walls red via Color(R, G, B), floats[0-1]
#	for i in range(33):
#		for j in range(17):
#			if map[i][j].walkable == false:
#				map[i][j].modulate = Color(1, 0, 0)
	
	player = _player_scene.instance()
	player.position = _new_GetCoord.index_to_vector(3, 3)
	get_parent().add_child(player)
	entities.append(player)
	
	for _i in range(8):
		var dwarf = _dwarf_scene.instance()
		dwarf.entity_name = "dwarf"
		dwarf.position = _new_GetCoord.index_to_vector(round(rand_range(1, 32)), round(rand_range(1, 15)))
		get_parent().add_child(dwarf)
		print(dwarf.name)
		entities.append(dwarf)
	
	print(entities)

# Identifies any entities in a grid index tile and prints them to the console
# Creatures use .entity_name instead of .name because godot won't let two nodes share a .name
func get_clicked_grid_tile():
	var click_loc = get_global_mouse_position()
	var location:Vector2 = _new_GetCoord.vector_to_index(click_loc.x, click_loc.y)
	location = _new_GetCoord.index_to_vector(location.x, location.y)
	var entity:String = "nothing"
	for i in range(entities.size()):
		if entities[i].position == location:
			entity = "a %s " % entities[i].entity_name
	print("There is ", entity)

func try_move(dx, dy):
	var try_vec_x = player.position.x + (dx * tile_width)
	var try_vec_y = player.position.y + (dy * tile_height)
	var try_index:Vector2 = _new_GetCoord.vector_to_index(try_vec_x, try_vec_y)
	if map[try_index.x][try_index.y].walkable == false:
		print("That's a wall")
	else:
		var entity_is_blocking:bool = false
		var blocking_entity
		for i in range(entities.size()):
			if entities[i].position == Vector2(try_vec_x, try_vec_y) && entities[i].walkable == false:
				entity_is_blocking = true
				blocking_entity = entities[i]
		
		if  entity_is_blocking == true:
			print("Something's in the way, and you strike it!")
			attack(player, blocking_entity)
		else:
			player.position.x = try_vec_x
			player.position.y = try_vec_y
		
		entity_is_blocking = false

func attack(attacker, defender):
	defender.health -= attacker.damage
	# checks health and creates corpses for dead entities, will need to move to it's own function later
	if defender.health <= 0:
		var corpse = _corpse_scene.instance()
		corpse.position = defender.position
		corpse.entity_name = "%s corpse" % defender.entity_name
		get_parent().add_child(corpse)
		entities.append(corpse)
		# The godot node isn't removed by the next line, so I'll need to find a way to do something about that later
		defender.visible = false
		for i in range(entities.size()):
			if entities[i].position == defender.position:
				entities.remove(i)
				break
