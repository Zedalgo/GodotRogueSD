extends Node2D

var white_pixel:PackedScene = preload("res://sprite/WhitePixel.tscn")
# Sprite scenes
var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _d_lower_scene:PackedScene = preload("res://sprite/d_lower.tscn")
var _door_scene:PackedScene = preload("res://sprite/Door.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")
var _chest_scene:PackedScene = preload("res://sprite/Chest.tscn")
var _fountain_scene:PackedScene = preload("res://sprite/Fountain.tscn")
var _o_scene:PackedScene = preload("res://sprite/o_lower.tscn")
# Utilities
var _new_GetCoord = preload("res://library/GetCoord.gd").new()
var _HelperFunc = preload("res://library/HelperFunctions.gd").new()
var astar = AStar2D.new()
# var map_gen_astar = AStar2D.new()
# Done for convenence, since the player has some unique stuff from everything else
var player:Sprite
# Arrays
var entities:Array = []
var inventory:Array = []
var items:Array = []
var map:Array = []
var objects:Array = []
var room_list:Array = []
# Booleans
var map_generated:bool = false
var normal_movement:bool = true
var player_turn:bool = true
# Constants
# Integers
var tile_width:int = 16
var tile_height:int = 24
var turn_number:int = 0

##### To Do After Basic Gameplay#####
# Score
# Hichscore tracking
# Morgue File - Cogmind


func _ready():
	randomize() # Creates a new seed for randomization

# Handles player inputs
func _unhandled_input(Input):
	# Handles start screen input (space to start)
	if Input.is_action_pressed("start_game") && map_generated == false:
		$SpaceToGenMap.visible = false
		map_generated = true
		$Text_Log.set_text("Generating map...")
		create_entity(-1, -1, _player_scene, "player", 20, 5, 10, "Player", false, ["Meat"])
		player = entities[0]
		player.view_range = 3
		generate_map()
		$Text_Log.set_text("Map generated.\n%s" % $Text_Log.get_text())
	
	if (map_generated == true) && (player_turn == true) && (player.alive == true) && (normal_movement == true):
		if Input.is_action_pressed("select"):
			print(entities)
		if Input.is_action_pressed("debug_key"):
			print(astar.is_point_disabled(astar.get_closest_point(player.position)), astar.get_closest_point(player.position))
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
				elif i == 0:
					text_out("There's nothing there")
				elif inventory.size() >= 9:
					$Text_Log.text = "You can't carry any more!\n%s" % $Text_Log.text
				else:
					pass
		
		# Need a way to do line of sight before aiming weapon works properly
		if normal_movement == false:
			if Input.is_action_pressed("move_down"):
				pass
			if Input.is_action_pressed("move_up"):
				pass
			if Input.is_action_pressed("move_right"):
				pass
			if Input.is_action_pressed("move_left"):
				pass
		
		if player_turn == false:
			turn_number += 1
			# Heal back 1 health every ten turns
			if (player.health_current < player.health_max) && (turn_number % 10 == 0):
				player.health_current += 1
			trim_text_readout()
			update_inventory_panel()
			update_status_screen()
			update_floor_tiles()
			create_corpses()
			enemy_phase()
			update_fov(player)


func generate_map():
	#Fill space with walls, populate the map array
	for i in range(33):
		map.append([])
		for j in range(17):
			var _wall = place_terrain(i, j, _wall_scene, "wall", false)
			map[i].append(_wall)
		
	# Room Generation
	room_list = []
	var number_of_rooms:int = randi() % 2 + 6
	var growth_ticks:int = 3 * number_of_rooms
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
			if room_list[j][0] == room_coords[0] && room_list[j][1] == room_coords[1]:
				overlap = true
		
		var not_overlapping:bool = false
		while overlap == true:
			macro_x = rand_range(0, 7)
			macro_y = rand_range(0, 3)
			not_overlapping = false
			room_coords = [macro_x, macro_y, room_number]
			for j in range(room_list.size()):
				if room_list[j] == room_coords:
					break
				if j == room_list.size()-1:
					not_overlapping = true
			if not_overlapping == true:
				overlap = false
		
		room_list.append(room_coords)
		replace_index_x = (macro_x * 4) + 2
		replace_index_y = (macro_y * 4) + 2
		for a in range(replace_index_x - 1, replace_index_x + 2):
			for b in range(replace_index_y - 1, replace_index_y + 2):
				replace_terrain(a, b, _floor_scene, "floor", true)
	
	#Create Hallways between rooms, ensuring there's a route to every one without being spaghetti
	for i in range(room_list.size()):
		var root_x:int = (4 * room_list[i][0]) + 2
		var root_y:int = (4 * room_list[i][1]) + 2
		var target_x:int = (4 * room_list[i - 1][0]) + 2
		var target_y:int = (4 * room_list[i - 1][1]) + 2
		var first_direction:int = randi() % 2 # Determines if vertical or horizontal first hallway shape
		var x_inc_dec:int = 1
		var y_inc_dec:int = 1
		
		if target_x < root_x:
			x_inc_dec = -1
		if target_y < root_y:
			y_inc_dec = -1
		
		if first_direction == 0: # Horizontal First
			for a in range(root_x, target_x, x_inc_dec):
				replace_terrain(a, root_y, _floor_scene, "floor", true)
			for b in range(root_y, target_y, y_inc_dec):
				replace_terrain(target_x, b, _floor_scene, "floor", true)
			
		if first_direction == 1: # Vertical First
			for b in range(root_y, target_y, y_inc_dec):
				replace_terrain(root_x, b, _floor_scene, "floor", true)
			for a in range(root_x, target_x, x_inc_dec):
				replace_terrain(a, target_y, _floor_scene, "floor", true)
		
	#Expands the initial rooms in a similar way to initial gen, just tethered to the room selected for growth
	var growth_var:int = 0
	while growth_var < growth_ticks:
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
		
		var overlap:bool = false
		
		if macro_x < 0 || macro_y < 0:
			overlap == true
		
		for j in range(room_list.size()):
			if room_list[j][0] == macro_x && room_list[j][1] == macro_y:
				overlap = true
		
		if overlap == false:
			#rectangle of floor changes depeding on growth direction
			replace_index_x = (macro_x * 4) + 2
			replace_index_y = (macro_y * 4) + 2
			if direction == 0 && macro_x < 7:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 2, replace_index_x + 2):
					for b in range(replace_index_y - 1, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 1 && macro_x > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 3):
					for b in range(replace_index_y - 1, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 2 && macro_y < 3:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 2, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true)
			if direction == 3 && macro_y > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 1, replace_index_y + 3):
						replace_terrain(a, b, _floor_scene, "floor", true)
			growth_var += 1
	
	# Generates the astar array and connects the points of the grid
	var k:int = 0
	for i in range(map.size()):
		for j in range(map[i].size()):
			if map[i][j].walkable == true:
				astar.add_point(k, map[i][j].position)
				k += 1
			if astar.get_point_count() > 0:
				if map[i-1][j].walkable == true && map[i][j].walkable == true:
					astar.connect_points(astar.get_closest_point(map[i-1][j].position), astar.get_closest_point(map[i][j].position))
				if map[i][j-1].walkable == true && map[i][j].walkable == true:
					astar.connect_points(astar.get_closest_point(map[i][j-1].position), astar.get_closest_point(map[i][j].position))
	
	# Detects where doors should be placed and puts one there, disables astar node underneath. Reenabled on door open
	for i in range(room_list.size()):
		var room_map_x:int = (4*room_list[i][0]) + 2
		var room_map_y:int = (4*room_list[i][1]) + 2
		var room_number:int = room_list[i][2]
		var same_room:bool = false
		if room_list[i][0] < 7:# Check Right wall if not in right column
			if map[room_map_x + 2][room_map_y].terrain_name == "floor":
				if map[room_map_x + 2][room_map_y + 1].terrain_name == "wall":
					create_room_object(room_map_x + 2, room_map_y, _door_scene, "door", astar.get_closest_point(map[room_map_x + 2][room_map_y].position))
		if room_list[i][0] > 0:# Check Left Wall if not in left column
			if map[room_map_x - 2][room_map_y].terrain_name == "floor":
				if map[room_map_x - 2][room_map_y + 1].terrain_name == "wall":
					create_room_object(room_map_x - 2, room_map_y, _door_scene, "door", astar.get_closest_point(map[room_map_x - 2][room_map_y].position))
		if room_list[i][1] < 3:# Check Bottom Wall if not in bottom row
			if map[room_map_x][room_map_y + 2].terrain_name == "floor":
				if map[room_map_x + 1][room_map_y + 2].terrain_name == "wall":
					create_room_object(room_map_x, room_map_y + 2, _door_scene, "door", astar.get_closest_point(map[room_map_x][room_map_y + 2].position))
		if room_list[i][1] > 0:#Check top Wall if not in top row
			if map[room_map_x][room_map_y - 2].terrain_name == "floor":
				if map[room_map_x + 1][room_map_y - 2].terrain_name == "wall":
					create_room_object(room_map_x, room_map_y - 2, _door_scene, "door", astar.get_closest_point(map[room_map_x][room_map_y - 2].position))
	
	# Places player, enemies, items and room objects randomly in rooms
	var spawn_room:int = randi() % room_list.size()
	player.position = _new_GetCoord.index_to_vector(4 * room_list[spawn_room][0] + 2, 4 * room_list[spawn_room][1] + 2)
	var occupied_space:Array = [player.position]
	for i in range(room_list.size()):
		for j in range(2):
			var random_roll:int = randi() % 10 #Random number 0-9
			var rand_x = 4 * room_list[i][0] + 1 + randi() % 3
			var rand_y = 4 * room_list[i][1] + 1 + randi() % 3
			if random_roll <=1:
				var occupied:bool = false
				for l in range(occupied_space.size()):
					if occupied_space[l] == _new_GetCoord.index_to_vector(rand_x, rand_y):
						occupied == true
				if occupied == false:
					create_entity(rand_x, rand_y, _d_lower_scene, "Drone", 10, 3, 0, "AStar", false, ["Machine"])
					occupied_space.append(_new_GetCoord.index_to_vector(rand_x, rand_y))
			if random_roll == 2:
				create_item(rand_x, rand_y, _o_scene, "Power Cell")
			if random_roll == 3:
				var door_check:bool = false
				for l in range(objects.size()):
					if objects[l].position == _new_GetCoord.index_to_vector(rand_x+1, rand_y):
						door_check = true
					if objects[l].position == _new_GetCoord.index_to_vector(rand_x-1, rand_y):
						door_check = true
					if objects[l].position == _new_GetCoord.index_to_vector(rand_x, rand_y+1):
						door_check = true
					if objects[l].position == _new_GetCoord.index_to_vector(rand_x, rand_y-1):
						door_check = true
				if door_check == false:
					create_room_object(rand_x, rand_y, _fountain_scene, "Battery Charger", astar.get_closest_point(_new_GetCoord.index_to_vector(rand_x, rand_y)))
	
		# Done - set first room on the grid
		# Done - for subsequent rooms, check for overlap
		# Done - handle expanding rooms
		# Done - once this works, expand to generate actual spaces on the map with replace()
		# Done - via room_number, which is room_coords[2] - union expansions of rooms to the greater room
		# Done - hallways
		# Done - doors, detection done, door entity done, astar disabling done, astar enabling wip
		# Done - random player start
		# Done - Sorta - Enemy spawning
		
		# Ranged Attack
		# items, spawn done, functionality wip
		# recharge station - energy, spawn done, func wip
		
	
	# generate enemies on the map
	# generate items on the map
	
	
	# Initial appearance of the info panels 
	update_inventory_panel()
	update_status_screen()
	trim_text_readout()
	update_floor_tiles()


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
		for i in range(objects.size()):
			if objects[i].position == Vector2(try_vec_x, try_vec_y):
				var blocking_object = objects[i]
				try_object(blocking_object)
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


func try_object(object):
	if object.room_object_name == "door":
		object.modulate = Color(0.5, 0.5, 0.5)
		var map_position:Vector2 = _new_GetCoord.vector_to_index(object.position.x, object.position.y)
		map[map_position.x][map_position.y].walkable = true
		text_out("You open the door")
		astar.set_point_disabled(object.astar_node, false)
		if player_turn == true:
			player_turn = false


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
	update_floor_tiles()
	player_turn = true


func update_status_screen():
	$HealthBar.max_value = player.health_max
	$HealthBar.value = player.health_current
	$EnergyBar.max_value = player.energy_max
	$EnergyBar.value = player.energy_current
	$TurnTracker.text = "Turn: %s" % turn_number
	$StatusScreen.text = "%s%s%s\n%s%s%s" % [player.health_current, "/", player.health_max , player.energy_current, "/", player.energy_max]


func update_inventory_panel():
	$InventoryScreen.text = "Inventory:\n"
	var empty_slot_number:int = 9 - inventory.size()
	for i in range(inventory.size()):
		$InventoryScreen.text = "%s%s) %s\n" % [$InventoryScreen.text, i + 1, inventory[i].item_name]
	for i in range(empty_slot_number):
		$InventoryScreen.text = "%s%s) \n" % [$InventoryScreen.text, (i + inventory.size()) + 1]

# Cosmetic function that makes occupied floor tiles invisible
func update_floor_tiles():
	for i in range(map.size()):
		for j in range(map[i].size()):
			map[i][j].visible = true
	for i in range(entities.size()):
		var index_position:Vector2 = _new_GetCoord.vector_to_index(entities[i].position.x, entities[i].position.y)
		map[index_position.x][index_position.y].visible = false
	for i in range(items.size()):
		var index_position:Vector2 = _new_GetCoord.vector_to_index(items[i].position.x, items[i].position.y)
		map[index_position.x][index_position.y].visible = false

# Reveals tiles on player view and dims visited tiles outside it
func update_fov(entity):
	for i in range(map.size()):
		for j in range(map[i].size()):
			if map[i][j].seen == true:
				map[i][j].modulate = Color(0, 1, 0)
			if map[i][j].seen == false:
				map[i][j].modulate = Color(0, 0, 0)
	# Figure out what's in view
	# Reveal things
	# Dim revealed stuff out of view
	var start_x:int = entity.position.x - (entity.view_range * tile_width)
	var start_y:int = entity.position.y - (entity.view_range * tile_height)
	var entity_position_node:int = astar.get_closest_point(entity.position)
	for i in range(entity.view_range * 2 + 1):
		for j in range(entity.view_range * 2 + 1):
			var xpos = i * tile_width + start_x
			var ypos = j * tile_height + start_y
			var astar_node_at_position = astar.get_closest_point(Vector2(xpos, ypos))
			var astar_array:Array = astar.get_point_path(astar_node_at_position, entity_position_node)
			# ToDo - Prevent wrapping view around walls, and seeing through walls
			# Missing view on certain door directions
			
			if astar_array.size() - 1 == (abs(entity.position.x - xpos) / tile_width) + (abs(entity.position.y - ypos) / tile_height):
				for k in range(astar_array.size()):
					var index_pos_x = astar_array[k][0] / tile_width
					var index_pos_y = astar_array[k][1] / tile_height
					map[index_pos_x][index_pos_y].modulate = Color(1, 0, 0)
	pass


func trim_text_readout():
	var line_count = $Text_Log.get_line_count()
	if line_count > 30:
		for i in range(line_count - 30, -1, -1):
			$Text_Log.remove_line(i)


func text_out(string:String):
	$Text_Log.text = "%s\n%s" % [string, $Text_Log.text]


func place_terrain(x, y, terrain_scene:PackedScene, terrain_name:String, walkable:bool):
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(x, y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	get_parent().add_child(terrain)
	return terrain


func replace_terrain(index_x, index_y, terrain_scene:PackedScene, terrain_name:String, walkable:bool) -> void:
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(index_x, index_y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	get_parent().add_child(terrain)
	get_parent().remove_child(map[index_x][index_y])
	map[index_x][index_y] = terrain

# Creates a creature with stats, some form of movement type, and optional tags
func create_entity(x, y, entity_scene:PackedScene, entity_name:String, entity_health:int,
		entity_damage:int, entity_energy_max:int = 0, movement_style:String = "AStar",  entity_walkable:bool = false, descriptor_tags:Array = []):
	var entity = entity_scene.instance()
	entity.entity_name = entity_name
	entity.position = _new_GetCoord.index_to_vector(x, y)
	entity.health_max = entity_health
	entity.health_current = entity.health_max
	entity.energy_max = entity_energy_max
	entity.energy_current = entity.energy_max
	entity.damage = entity_damage
	entity.walkable = entity_walkable
	entity.alive = true
	entity.move_type = movement_style
	entity.tags = descriptor_tags
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
			for j in range(entities[i].tags.size()):
				if entities[i].tags[j] == "Machine":
					corpse.item_name = "%s scrap" % entities[i].entity_name
					corpse.modulate = Color(0.5, 0.5, 0.5)
				# Check for meat creature tag second so cyborgs will have corpses instead of scrap
				if entities[i].tags[j] == "Meat":
					corpse.item_name = "%s corpse" % entities[i].entity_name
					corpse.modulate = Color(1, 0, 0)
			corpse.position = entities[i].position
			get_parent().add_child(corpse)
			items.append(corpse)
			get_parent().remove_child(entities[i])
			entities.remove(i)

# Creates terrain pieces like fountains that will replace floor tiles after base map generation
func create_room_object(x, y, object_scene:PackedScene, object_name:String, astar_node:int):
	var room_object = object_scene.instance()
	room_object.position = _new_GetCoord.index_to_vector(x, y)
	room_object.room_object_name = object_name
	room_object.astar_node = astar_node
	astar.set_point_disabled(astar_node)
	objects.append(room_object)
	get_parent().add_child(room_object)
	map[x][y].walkable = false

# Determines pathfinding based on entity.move_type tag
# ToDo - Coward - Flees from player
# ToDo - Ambush - Waits until the player has interacted with it first
# Astar - Most direct pursuit of player, sees doors as obstacled
# ToDo - Roam - Wandering until player spotted, switch tag to AStar once seen
# ToDo - Smart - Once player seen, takes more direct routes, factoring in door shortcuts, might require a second astar node array
func movement_type(moving_entity):
	if moving_entity.move_type == "AStar":
		var path_to_player:Array = astar.get_point_path(astar.get_closest_point(moving_entity.position), astar.get_closest_point(player.position))
		if path_to_player.size() > 1:
			var dx:int = (path_to_player[1].x - path_to_player[0].x) / tile_width
			var dy:int = (path_to_player[1].y - path_to_player[0].y) / tile_height
			try_move(moving_entity, dx, dy)
