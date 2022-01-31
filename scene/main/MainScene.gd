extends Node2D

# Sprite scenes
var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _dwarf_scene:PackedScene = preload("res://sprite/Dwarf.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")
var _chest_scene:PackedScene = preload("res://sprite/Chest.tscn")
var _fountain_scene:PackedScene = preload("res://sprite/Fountain.tscn")
# Utilities
var _new_GetCoord = preload("res://library/GetCoord.gd").new()
var astar = AStar2D.new()
# Don't remember why these are like this, probably load bearing
var player:Sprite
var wall:Sprite
# Arrays
var entities:Array = []
var inventory:Array = []
var items:Array = []
var map:Array = []
# Booleans
var map_generated:bool = false
var player_turn:bool = true
# Constants
# Integers
var tile_width:int = 16
var tile_height:int = 24
var turn_number:int = 0
# Notes
### Z Index: {-1:terrain, 0:items, 1:entities}

# Text readout stores forever, will want to limit that eventually


# Theoretically runs when the main scene happens for the first time, many functions won't run on start 
# if you put them here, might be godot functions only
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
	if (map_generated == true) && (player_turn == true) && (player.alive == true):
		if Input.is_action_pressed("select"):
			get_clicked_grid_tile()
		if Input.is_action_pressed("debug_key"):
			player_turn = false
		if Input.is_action_pressed("move_down"):
			try_move(player, 0, 1)
		if Input.is_action_pressed("move_up"):
			try_move(player, 0, -1)
		if Input.is_action_pressed("move_right"):
			try_move(player, 1, 0)
		if Input.is_action_pressed("move_left"):
			try_move(player, -1, 0)
		if Input.is_action_pressed("get"):
			for i in range(items.size() - 1, -1, -1):
				if (items[i].position == player.position) && (inventory.size() < 10):
					inventory.append(items[i])
					$Text_Log.text = "You picked up the %s\n%s" % [items[i].item_name, $Text_Log.text]
					get_parent().remove_child(items[i])
					items.remove(i)
					player_turn = false
					break
				elif inventory.size() >= 10:
					$Text_Log.text = "You can't carry any more!\n%s" % $Text_Log.text
				else:
					pass
		
		if player_turn == false:
			turn_number += 1
			# Heal back 1 health every ten turns
			if (player.health_current < player.health_max) && (turn_number % 10 == 0):
				player.health_current += 1
			update_inventory_panel()
			update_status_screen()
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
				_wall.z_index = -1
				get_parent().add_child(_wall)
				map[i].append(_wall)
			else:
				var _floor = _floor_scene.instance()
				var location:Vector2 = _new_GetCoord.index_to_vector(i, j)
				_floor.position = location
				_floor.z_index = -1
				get_parent().add_child(_floor)
				map[i].append(_floor)
				astar.add_point(k, _new_GetCoord.index_to_vector(i, j))
				
				k += 1
				if i > 1:
					var i_node = astar.get_closest_point(_new_GetCoord.index_to_vector(i, j))
					var i_node_left = astar.get_closest_point(_new_GetCoord.index_to_vector(i - 1, j))
					astar.connect_points(i_node, i_node_left)
				if j > 1:
					var j_node = astar.get_closest_point(_new_GetCoord.index_to_vector(i, j))
					var j_node_above = astar.get_closest_point(_new_GetCoord.index_to_vector(i, j - 1))
					astar.connect_points(j_node, j_node_above)
	
	create_entity(3, 3, _player_scene, "Player", 20, 5)
	player = entities[0]
	player.z_index = 1

	for _i in range(1):
		var x:int = round(rand_range(1, 31))
		var y:int = round(rand_range(1, 15))
		create_entity(x, y, _dwarf_scene, "dwarf", 10, 3)
	
	for _i in range(1):
		var x:int = round(rand_range(1, 31))
		var y:int = round(rand_range(1, 15))
		create_terrain_piece(5, 5, _fountain_scene, "fountain")
	
	update_inventory_panel()
	update_status_screen()


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
			attack(entity, blocking_entity)
			player_turn = false
		else:
			entity.position.x = try_vec_x
			entity.position.y = try_vec_y
			player_turn = false
		
		entity_is_blocking = false


func attack(attacker, defender):
	defender.health_current -= attacker.damage
	$Text_Log.set_text("%s strikes %s for %s damage!\n%s" % [attacker.entity_name,
			 defender.entity_name, attacker.damage, $Text_Log.get_text()])
	# checks health and creates corpses for dead entities, will need to move to it's own function later
	if defender.health_current <= 0:
		defender.alive = false
		defender.walkable = true


func enemy_phase():
	for i in range(1, entities.size()): 
		if entities[i].alive == true:
			movement_type(entities[i])
	create_corpses()
	update_status_screen()
	player_turn = true


func update_status_screen():
	$HealthBar.max_value = player.health_max
	#If max health exceeds 115, the bar will go offscreen, may need to clamp if health can get higher
	$HealthBar.margin_right = $HealthBar.margin_left + (2 * player.health_max)
	$HealthBar.value = player.health_current
	$TurnTracker.text = "Turn: %s" % turn_number


func update_inventory_panel():
	$InventoryScreen.text = "Inventory:\n"
	var empty_slot_number:int = 9 - inventory.size()
	for i in range(inventory.size()):
		$InventoryScreen.text = "%s%s) %s\n" % [$InventoryScreen.text, i + 1, inventory[i].item_name]
	for i in range(empty_slot_number):
		$InventoryScreen.text = "%s%s) \n" % [$InventoryScreen.text, (i + inventory.size()) + 1]


func create_entity(x, y, entity_scene:PackedScene, entity_name:String, entity_health:int,
		entity_damage:int, entity_walkable:bool = false, alive:bool = true):
	var entity = entity_scene.instance()
	entity.entity_name = entity_name
	entity.position = _new_GetCoord.index_to_vector(x, y)
	entity.health_max = entity_health
	entity.health_current = entity.health_max
	entity.damage = entity_damage
	entity.walkable = entity_walkable
	entity.alive = alive
	entity.z_index = 1
	get_parent().add_child(entity)
	entities.append(entity)


#func create_item(x, y, item_scene:PackedScene, item_name:String, magical:bool):
#	
#	pass


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

# Creates terrain pieces like fountains that will replace floor tiles after base map generation
func create_terrain_piece(x, y, piece_scene:PackedScene, piece_name:String):
	var terrain_piece = piece_scene.instance()
	terrain_piece.position = _new_GetCoord.index_to_vector(x, y)
	get_parent().add_child(terrain_piece)
	map[x][y] = terrain_piece
	pass


func movement_type(moving_entity):
	if moving_entity.move_type == "AStar":
		var path_to_player:Array = astar.get_point_path(astar.get_closest_point(moving_entity.position), astar.get_closest_point(player.position))
		var dx:int = (path_to_player[1].x - path_to_player[0].x) / tile_width
		var dy:int = (path_to_player[1].y - path_to_player[0].y) / tile_height
		try_move(moving_entity, dx, dy)
	pass
