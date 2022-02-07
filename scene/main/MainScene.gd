extends Node2D

#variables for mag generation testing
var whitepixel:PackedScene = preload("res://sprite/WhitePixel.tscn")
var max_dungeon_height:int = 408
var max_dungeon_width:int = 528
var temp_map:Array = []

# Sprite scenes
var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _d_lower_scene:PackedScene = preload("res://sprite/d_lower.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")
var _chest_scene:PackedScene = preload("res://sprite/Chest.tscn")
var _fountain_scene:PackedScene = preload("res://sprite/Fountain.tscn")
var _o_scene:PackedScene = preload("res://sprite/o_lower.tscn")
# Utilities
var _new_GetCoord = preload("res://library/GetCoord.gd").new()
var _HelperFunc = preload("res://library/HelperFunctions.gd").new()
var astar = AStar2D.new()
var map_gen_astar = AStar2D.new()
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
##### Notes #####
# Z Index: {-1:terrain, 0:items, 1:entities}
# Text readout stores forever, will want to limit that eventually
##### To Do After Basic Gameplay#####
# Score
# Hichscore tracking
# Morgue File - Cogmind


func _ready():
	randomize() # Creates a new seed for randomization

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
			print("Mouse at:", get_global_mouse_position())
		if Input.is_action_pressed("debug_key"):
			pass
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


func generate_map():
	#Fill space with walls, populate the map array
	for i in range(33):
		map.append([])
		for j in range(17):
			var _wall = place_terrain(i, j, _wall_scene, "wall", false)
			map[i].append(_wall)
		
	# Room Generation
	var room_list:Array = []
	var number_of_rooms:int = randi() % 3 + 4
	var growth_ticks:int = rand_range(3, 4) * number_of_rooms
	print("Number of Rooms:", number_of_rooms)
	##32 zones on a 8x4 grid, 4-6 zones growing 3 times leads to 16-24 occupied zones
	
	# ?!? Bug in initial generation: Overlapping rooms might still occur
	for i in range(number_of_rooms):
		var macro_x:int = rand_range(0, 8)
		var macro_y:int = rand_range(0, 4)
		var room_number:int = i
		var room_coords:Array = []
		var replace_index_x:int
		var replace_index_y:int
		
		room_coords = [macro_x, macro_y, room_number]
		var overlap:bool = false
		for j in range(room_list.size()):
			if room_list[j] == room_coords:
				overlap = true
		
		while overlap == true:
			macro_x = rand_range(0, 7)
			macro_y = rand_range(0, 3)
			var not_overlapping:bool = false
			room_coords = [macro_x, macro_y, room_number]
			for j in range(room_list.size()):
				if room_list[j] == room_coords:
					break
				if j == room_list.size() - 1:
					not_overlapping = true
			if not_overlapping == true:
				overlap = false
		
		room_list.append(room_coords)
		replace_index_x = (macro_x * 4) + 2
		replace_index_y = (macro_y * 4) + 2
		print("Generating room ", room_number, " at index ", replace_index_x, ", ", replace_index_y, "[", macro_x, "][", macro_y, "]")
		for a in range(replace_index_x - 1, replace_index_x + 2):
			for b in range(replace_index_y - 1, replace_index_y + 2):
				replace_terrain(a, b, _floor_scene, "floor", true)
	
	#Expands the initial rooms in a similar way to initial gen, just tethered to the room selected for growth
	for i in range(growth_ticks):
		var room_selector:int = rand_range(0, room_list.size() - 1)
		var room_to_grow_from:Array = room_list[room_selector]
		var direction:int = rand_range(0, 4)
		
		var macro_x = room_to_grow_from[0]
		var macro_y = room_to_grow_from[1]
		var room_number = room_to_grow_from[2]
		var room_coords:Array = []
		var replace_index_x:int
		var replace_index_y:int
		
		if direction == 0:# Rightward
			macro_x += 1
		if direction == 1:# Leftward
			macro_x -= 1
		if direction == 2:# Downward
			macro_y += 1
		if direction== 3:# Upward
			macro_y -= 1
		
		var overlap:bool
		overlap = false
		
		if macro_x < 0 || macro_y < 0:
			overlap == true
		
		for j in range(room_list.size()):
			if room_list[j][0] == macro_x && room_list[j][1] == macro_y:
				overlap = true
		
		if overlap == false:
			#change depeding on growth direction
			replace_index_x = (macro_x * 4) + 2
			replace_index_y = (macro_y * 4) + 2
			if direction == 0 && macro_x < 7:
				print("Expanding room ", room_to_grow_from[2], " in direction ", direction, "[", macro_x, "][", macro_y, "]")
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 2, replace_index_x + 2):
					for b in range(replace_index_y - 1, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 1 && macro_x > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				print("Expanding room ", room_to_grow_from[2], " in direction ", direction, "[", macro_x, "][", macro_y, "]")
				for a in range(replace_index_x - 1, replace_index_x + 3):
					for b in range(replace_index_y - 1, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 2 && macro_y < 3:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				print("Expanding room ", room_to_grow_from[2], " in direction ", direction, "[", macro_x, "][", macro_y, "]")
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 2, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 3 && macro_y > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				print("Expanding room ", room_to_grow_from[2], " in direction ", direction, "[", macro_x, "][", macro_y, "]")
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 1, replace_index_y + 3):
						replace_terrain(a, b, _floor_scene, "floor", true)
	#breakpoint
		# Done - set first room on the grid
		# Done - for subsequent rooms, check for overlap
		# Done - handle expanding rooms
		# Done - once this works, expand to generate actual spaces on the map with replace()
		# Done - via room_number, which is room_coords[2] - union expansions of rooms to the greater room
		#hallways
		
	# Place Astar nodes on floor tiles
	# Connect astar nodes
	# Note: Might have to do 2 above steps after terrain features
			
	# create terrain features
	# Create the Player on a random empty room space
	create_entity(-1, -1, _player_scene, "player", 10, 5, 10)
	player = entities[0]
	
	# generate enemies on the map
	# generate items on the map
	
	
	# Initial appearance of the info panels 
	
	update_inventory_panel()
	update_status_screen()


# Identifies any entities in a grid index tile and brints them to the console
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
	$HealthBar.value = player.health_current
	$EnergyBar.max_value = player.energy_max
	$EnergyBar.value = player.energy_current
	$TurnTracker.text = "Turn: %s" % turn_number
	var health_percent = round(100 * (player.health_current / player.health_max))
	var energy_percent = round(100 * (player.energy_current / player.energy_max))
	$StatusScreen.text = "%s%s\n%s%s" % [health_percent, "%", energy_percent, "%"]


func update_inventory_panel():
	$InventoryScreen.text = "Inventory:\n"
	var empty_slot_number:int = 9 - inventory.size()
	for i in range(inventory.size()):
		$InventoryScreen.text = "%s%s) %s\n" % [$InventoryScreen.text, i + 1, inventory[i].item_name]
	for i in range(empty_slot_number):
		$InventoryScreen.text = "%s%s) \n" % [$InventoryScreen.text, (i + inventory.size()) + 1]


func place_terrain(x, y, terrain_scene:PackedScene, terrain_name:String, walkable:bool):
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(x, y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	get_parent().add_child(terrain)
	return terrain


func replace_terrain(index_x, index_y, terrain_scene:PackedScene, terrain_name:String, walkable:bool):
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(index_x, index_y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	get_parent().add_child(terrain)
	get_parent().remove_child(map[index_x][index_y])
	return terrain


func create_entity(x, y, entity_scene:PackedScene, entity_name:String, entity_health:int,
		entity_damage:int, entity_energy_max:int = 0,  entity_walkable:bool = false, alive:bool = true ):
	var entity = entity_scene.instance()
	entity.entity_name = entity_name
	entity.position = _new_GetCoord.index_to_vector(x, y)
	entity.health_max = entity_health
	entity.health_current = entity.health_max
	entity.energy_max = entity_energy_max
	entity.energy_current = entity.energy_max
	entity.damage = entity_damage
	entity.walkable = entity_walkable
	entity.alive = alive
	entity.z_index = 1
	get_parent().add_child(entity)
	entities.append(entity)


func create_item(x, y, item_scene:PackedScene, item_name:String):
	var item = item_scene.instance()
	item.position = _new_GetCoord.index_to_vector(x, y)
	item.item_name = item_name
	get_parent().add_child(item)
	items.append(item)


func create_corpses():
	for i in range(entities.size()-1, -1, -1):
		if entities[i].alive == false:
			var corpse = _corpse_scene.instance()
			corpse.item_name = "%s corpse" % entities[i].entity_name
			corpse.position = entities[i].position
			#p rint(_new_GetCoord.vector_to_index(corpse.position.x, corpse.position.y))
			get_parent().add_child(corpse)
			items.append(corpse)
			get_parent().remove_child(entities[i])
			entities.remove(i)

# Creates terrain pieces like fountains that will replace floor tiles after base map generation
func create_room_object(x, y, object_scene:PackedScene, object_name:String):
	var room_object = object_scene.instance()
	room_object.position = _new_GetCoord.index_to_vector(x, y)
	room_object.room_object_name = object_name
	get_parent().add_child(room_object)
	map[x][y] = room_object
	# if not walkable remove astar node, ya dingus


func movement_type(moving_entity):
	if moving_entity.move_type == "AStar":
		var path_to_player:Array = astar.get_point_path(astar.get_closest_point(moving_entity.position), astar.get_closest_point(player.position))
		var dx:int = (path_to_player[1].x - path_to_player[0].x) / tile_width
		var dy:int = (path_to_player[1].y - path_to_player[0].y) / tile_height
		try_move(moving_entity, dx, dy)
	pass
