extends Node2D

var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _dwarf_scene:PackedScene = preload("res://sprite/Dwarf.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")

var _new_GetCoord = preload("res://library/GetCoord.gd").new()
var astar = AStar2D.new()

var player:Sprite
var wall:Sprite


var entities:Array = []
var items:Array = []
var map:Array = []

var map_generated:bool = false
var player_turn:bool = true

var tile_width:int = 16
var tile_height:int = 24

# I will eventually need to start defining enemy health, damage, etc independent of the sprite node
# they utilize for visuals. Will likely need to learn how resource scripts work

# Theoretically runs when the main scene happens for the first time
func _ready():
	randomize()

# Handles player inputs
func _unhandled_input(Input):
	if Input.is_action_pressed("start_game") && map_generated == false:
		$SpaceToGenMap.visible = false
		map_generated = true
		$Text_Log.set_text("Generating map...")
		generate_map()
		$Text_Log.set_text("Map generated.\n%s" % $Text_Log.get_text())
	if map_generated == true && player_turn == true:
		if Input.is_action_pressed("select"):
			get_clicked_grid_tile()
		if Input.is_action_pressed("debug_key"):
			print(astar.get_closest_point(player.position))
		if Input.is_action_pressed("move_down"):
			try_move(player, 0, 1)
		if Input.is_action_pressed("move_up"):
			try_move(player, 0, -1)
		if Input.is_action_pressed("move_right"):
			try_move(player, 1, 0)
		if Input.is_action_pressed("move_left"):
			try_move(player, -1, 0)
		
		if player_turn == false:
			create_corpses()
			enemy_phase()


# Currently generates a static map
func generate_map():
	var k:int = 0
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
				astar.add_point(k, Vector2(i * tile_width, j * tile_height))
				k += 1
	
	player = _player_scene.instance()
	player.position = _new_GetCoord.index_to_vector(3, 3)
	get_parent().add_child(player)
	entities.append(player)
	
	for _i in range(2):
		var dwarf = _dwarf_scene.instance()
		dwarf.entity_name = "dwarf"
		dwarf.position = _new_GetCoord.index_to_vector(round(rand_range(1, 31)), round(rand_range(1, 15)))
		get_parent().add_child(dwarf)
		entities.append(dwarf)


# Identifies any entities in a grid index tile and prints them to the console
# Creatures use .entity_name instead of .name because godot won't let two nodes share a .name
func get_clicked_grid_tile():
	var click_loc = get_global_mouse_position()
	var location:Vector2 = _new_GetCoord.vector_to_index(click_loc.x, click_loc.y)
	location = _new_GetCoord.index_to_vector(location.x, location.y)
	var grid_has:String = "There is"
	var name_entity:String
	var name_item:String
	var entity_found:bool = false
	var item_found:bool = false
	for i in range(entities.size()):
		if entities[i].position == location:
			name_entity = "a %s" % entities[i].entity_name
			entity_found = true
	for i in range(items.size()):
		if items[i].position == location:
			if item_found == false:
				name_item = "a %s" % items[i].item_name
				item_found = true
			elif item_found == true:
				name_item = "%s & a %s" % [name_item, items[i].item_name]
	if entity_found == true:
		grid_has = "%s %s" % [grid_has, name_entity]
	if item_found == true:
		if entity_found == true:
			grid_has = "%s," % grid_has
		grid_has = "%s %s" % [grid_has, name_item]
	if item_found == false && entity_found == false:
		
		grid_has = "%s nothing" % grid_has
	
	$Text_Log.set_text("%s\n%s" % [grid_has, $Text_Log.get_text()])


func try_move(entity, dx, dy):
	var try_vec_x = entity.position.x + (dx * tile_width)
	var try_vec_y = entity.position.y + (dy * tile_height)
	var try_index:Vector2 = _new_GetCoord.vector_to_index(try_vec_x, try_vec_y)
	if map[try_index.x][try_index.y].walkable == false:
		pass
	else:
		var entity_is_blocking:bool = false
		var blocking_entity
		for i in range(entities.size()):
			if entities[i].position == Vector2(try_vec_x, try_vec_y) && entities[i].walkable == false:
				entity_is_blocking = true
				blocking_entity = entities[i]
		
		if  entity_is_blocking == true:
			$Text_Log.set_text("Something's in the way, and you strike it!\n%s" % $Text_Log.get_text())
			attack(entity, blocking_entity)
			player_turn = false
		else:
			entity.position.x = try_vec_x
			entity.position.y = try_vec_y
			player_turn = false
		
		entity_is_blocking = false


func attack(attacker, defender):
	defender.health -= attacker.damage
	# checks health and creates corpses for dead entities, will need to move to it's own function later
	if defender.health <= 0:
		defender.alive = false
		defender.walkable = true


func enemy_phase():
	var direction:int
	for i in range(1, entities.size()): 
		direction = round(rand_range(0,5))
		if entities[i].alive == true:
			if direction == 0:
				try_move(entities[i], 0, -1)
			if direction == 1:
				try_move(entities[i], 0, 1)
			if direction == 2:
				try_move(entities[i], -1, 0)
			if direction == 3:
				try_move(entities[i], 1, 0)
			if direction > 3:
				pass
	create_corpses()
	player_turn = true


func create_corpses():
	var corpse = _corpse_scene.instance()
	for i in range(entities.size()-1, -1, -1):
		if entities[i].alive == false:
			corpse.item_name = "%s corpse" % entities[i].entity_name
			corpse.position = entities[i].position
			get_parent().add_child(corpse)
			items.append(corpse)
			get_parent().remove_child(entities[i])
			entities.remove(i)
