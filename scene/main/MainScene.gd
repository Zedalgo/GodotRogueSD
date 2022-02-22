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
var aim_tile:Sprite
# Arrays
var entities:Array = []
var inventory:Array = []
var items:Array = []
var map:Array = []
var objects:Array = []
var room_list:Array = []
# Booleans
var map_generated:bool = false
var player_turn:bool = true
var shoot_mode:bool = false
var inventory_mode:bool = false
# Constants
# Integers
var slot_number:int = 0 # Used for item selection in use_mode
var tile_width:int = 16
var tile_height:int = 24
var turn_number:int = 0
# Update floor tiles after LoS, or floor will be visible under sprites


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
		text_out("Generating Map...")
		create_entity(-1, -1, _player_scene, "player", 20, 5, 10, "Player", ["Meat"], 5)
		player = entities[0]
		player.view_range = 3
		player.ranged_attack_cost = 2
		generate_map()
		text_out("Map Generated")
		update_fov(player)
		# Yellow tile used for shooting
		aim_tile = _wall_scene.instance()
		aim_tile.modulate = Color(1, 1, 0, 0.5)
		aim_tile.z_index = -5
		aim_tile.visible = false
		get_parent().add_child(aim_tile)
	
	#Normal movement, melee attacking
	if (map_generated == true) && (player_turn == true) && (player.alive == true) && (shoot_mode == false) && (inventory_mode == false):
		if Input.is_action_pressed("select"):
			pass
		if Input.is_action_pressed("debug_key"):
			var coords:Vector2 = _new_GetCoord.vector_to_index(player.position.x, player.position.y)
			create_item(coords.x, coords.y, _o_scene, "Test Cell", 1, 1, ["increase", "restore"], Color(1, 0, 1))
		if Input.is_action_pressed("move_down"):
			try_move(player, 0, 1)
		if Input.is_action_pressed("move_up"):
			try_move(player, 0, -1)
		if Input.is_action_pressed("move_right"):
			try_move(player, 1, 0)
		if Input.is_action_pressed("move_left"):
			try_move(player, -1, 0)
		if Input.is_action_pressed("get"):
			var item_found:bool = false
			var item_index:int
			for i in range(items.size() - 1, -1, -1):
				if (items[i].position == player.position):
					item_found = true
					item_index = i
			if item_found == true && inventory.size() < 10:
				inventory.append(items[item_index])
				text_out("You picked up the %s" % items[item_index].item_name)
				get_parent().remove_child(items[item_index])
				items.remove(item_index)
				player_turn = false
			elif item_found == true && inventory.size() > 9:
				text_out("You can't carry any more!")
			elif item_found == false:
				text_out("There's nothing there")
		if Input.is_action_pressed("shoot"):
			shoot_mode = true
			aim_tile.position = player.position
			aim_tile.visible = true
		
		if Input.is_action_pressed("open_inventory"):
			slot_number = 0
			inventory_mode = true
	
		if player_turn == false:
			end_player_turn()
	
	# Aiming the target tile and doing ranged damage
	if shoot_mode == true:
		if Input.is_action_pressed("move_down"):
			aim_tile.position.y += 24
		if Input.is_action_pressed("move_up"):
			aim_tile.position.y -= 24
		if Input.is_action_pressed("move_right"):
			aim_tile.position.x += 16
		if Input.is_action_pressed("move_left"):
			aim_tile.position.x -= 16
		if Input.is_action_pressed("cancel"):
			shoot_mode = false
			aim_tile.visible = false
		if Input.is_action_pressed("enter"):
			if player.energy_current >= player.ranged_attack_cost:
				for i in range(entities.size()):
					if entities[i].position == aim_tile.position:
						attack(player, entities[i], true)
				aim_tile.visible = false
				player.energy_current -= player.ranged_attack_cost
				shoot_mode = false
				player_turn = false
				end_player_turn()
			else:
				text_out("Not enough energy!")
	
	# Using inventory items
	if inventory_mode == true:
		if inventory.size() > 0:
			update_inventory_panel(slot_number)
			if Input.is_action_pressed("move_up"):
				if slot_number > 0:
					slot_number -= 1
					update_inventory_panel(slot_number)
			if Input.is_action_pressed("move_down"):
				if slot_number < 9:
					slot_number += 1
					update_inventory_panel(slot_number)
			if Input.is_action_pressed("enter"):
				if slot_number < inventory.size():
					use_item(inventory[slot_number], player)
					inventory.remove(slot_number)
					inventory_mode = false
					end_player_turn()
			if Input.is_action_pressed("drop"):
				var player_index:Vector2 = _new_GetCoord.vector_to_index(player.position.x, player.position.y)
				create_item(player_index.x, player_index.y, inventory[slot_number].image_scene, inventory[slot_number].item_name,
						inventory[slot_number].health, inventory[slot_number].energy, inventory[slot_number].item_tags, inventory[slot_number].image_color)
				inventory.remove(slot_number)
				inventory_mode = false
				end_player_turn()
			if Input.is_action_pressed("cancel"):
				inventory_mode = false
				update_inventory_panel(-1)
		else:
			text_out("There is nothing in your inventory.")
			inventory_mode = false

func generate_map():
	#Fill space with walls, populate the map array
	for i in range(33):
		map.append([])
		for j in range(17):
			var _wall = place_terrain(i, j, _wall_scene, "wall", false, true)
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
				replace_terrain(a, b, _floor_scene, "floor", true, false)
	
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
				replace_terrain(a, root_y, _floor_scene, "floor", true, false)
			for b in range(root_y, target_y, y_inc_dec):
				replace_terrain(target_x, b, _floor_scene, "floor", true, false)
			
		if first_direction == 1: # Vertical First
			for b in range(root_y, target_y, y_inc_dec):
				replace_terrain(root_x, b, _floor_scene, "floor", true, false)
			for a in range(root_x, target_x, x_inc_dec):
				replace_terrain(a, target_y, _floor_scene, "floor", true, false)
		
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
						replace_terrain(a, b, _floor_scene, "floor", true, false)
			if direction == 1 && macro_x > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 3):
					for b in range(replace_index_y - 1, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true, false)
			if direction == 2 && macro_y < 3:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 2, replace_index_y + 2):
						replace_terrain(a, b, _floor_scene, "floor", true, false)
			if direction == 3 && macro_y > 0:
				room_coords = [macro_x, macro_y, room_number]
				room_list.append(room_coords)
				for a in range(replace_index_x - 1, replace_index_x + 2):
					for b in range(replace_index_y - 1, replace_index_y + 3):
						replace_terrain(a, b, _floor_scene, "floor", true, false)
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
	player.position = _new_GetCoord.index_to_vector(4 * room_list[0][0] + 2, 4 * room_list[0][1] + 2)
	for i in range(room_list.size()):
		var random_roll:int = randi() % 2
		var luck_roll:int = randi() % 2
		var room_index:Vector2 = Vector2(4 * room_list[i][0] + 2, 4 * room_list[i][1] + 2)
		var random_x:int = randi() % 3 - 1
		var random_y:int = randi() % 3 - 1
		var rand_item:int
		var rand_enemy:int
		var rand_object:int
		match random_roll:
			0: # Rolled Nothing
				pass
			1: # 1 item
				rand_item = randi() % 2
				if rand_item == 0:
					create_item(room_index.x + random_x, room_index.y + random_y, _o_scene, "Energy Cell",
							0, 4, ["restore"], Color(0.5, 0.5, 1))
				elif rand_item == 1:
					create_item(room_index.x + random_x, room_index.y + random_y, _o_scene, "Medical Kit",
							6, 0, ["restore"], Color(1, 0.5, 0.5))
			2: # 1 enemy
				pass
			3: # 1 enemy, 1 item
				pass
			4: # 2 enemies
				pass
			5: # 2 items
				pass
			6: # 2 enemies & an item
				pass
			7: # 1 enemy, item, and room object
				pass
			8: #  1 item and room object
				pass
			9: # Monster Room or Loot Room
				pass
		# Done - set first room on the grid
		# Done - for subsequent rooms, check for overlap
		# Done - handle expanding rooms
		# Done - once this works, expand to generate actual spaces on the map with replace()
		# Done - via room_number, which is room_coords[2] - union expansions of rooms to the greater room
		# Done - hallways
		# Done - doors, detection done, door entity done, astar disabling done, astar enabling wip
		# Done - random player start
		# Done - Enemy spawning
		
		# Ranged Attack
		# items, spawn done, functionality wip
		# recharge station - energy, spawn done, func wip
		
	for i in range(map.size()):
		for j in range(map[i].size()):
			map[i][j].visible = false
	for i in range(entities.size() - 1, 1, 1):
		entities[i].visible = false
	
	# Initial appearance of the info panels 
	update_inventory_panel(-1)
	update_status_screen()
	trim_text_readout()
	update_fov(player)


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
		object.blocks_vision = false
		text_out("You open the door")
		astar.set_point_disabled(object.astar_node, false)
		if player_turn == true:
			player_turn = false


func use_item(item, entity):
	for i in range(item.item_tags.size()):
		if item.item_tags[i] == "restore":
			entity.health_current += item.health
			entity.energy_current += item.energy
		if item.item_tags[i] == "increase":
			entity.health_current += item.health
			entity.health_max += item.health
			entity.energy_current += item.energy
			entity.energy_max += item.energy
		# Prevent going over max, would "clamp" be better in this case?
		if entity.energy_current > entity.energy_max:
			entity.energy_current = entity.energy_max
		if entity.health_current > entity.health_max:
			entity.health_current = entity.health_max


func attack(attacker, defender, ranged:bool = false):
	if ranged == false:
		defender.health_current -= attacker.damage
		text_out("%s strikes %s for %s damage!" % [attacker.entity_name,
				 defender.entity_name, attacker.damage])
	else:
		defender.health_current -= attacker.ranged_damage
		text_out("%s shoots %s for %s damage!" % [attacker.entity_name,
				defender.entity_name, attacker.ranged_damage])
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
	$StatusScreen.text = "%s%s%s\n%s%s%s" % [player.health_current, "/", player.health_max , player.energy_current, "/", player.energy_max]


func update_inventory_panel(inventory_slot_num):
	$InventoryScreen.text = "Inventory:\n"
	var empty_slot_number:int = 10 - inventory.size()
	for i in range(inventory.size()):
		if inventory_slot_num == i:
			$InventoryScreen.text = "%s>%s) %s<\n" % [$InventoryScreen.text, i + 1, inventory[i].item_name]
		else:
			$InventoryScreen.text = "%s%s) %s\n" % [$InventoryScreen.text, i + 1, inventory[i].item_name]
	for i in range(empty_slot_number):
		$InventoryScreen.text = "%s%s) \n" % [$InventoryScreen.text, (i + inventory.size() + 1)]


# Reveals tiles on player view and dims visited tiles outside it
# Setting up to be usable for enemy LoS as well, hopefully
func update_fov(entity):
	for i in range(map.size()):
		for j in range(map[i].size()):
			if map[i][j].seen == true:
				map[i][j].modulate.a = 0.5
			else:
				map[i][j].visible = false
	for i in range(entities.size()-1, 0, -1):
		entities[i].visible = false
	for i in range(objects.size()):
		if objects[i].seen != true:
			objects[i].visible = false
	for i in range(items.size()):
		items[i].visible = false
	
	# Sets anything in the given range to visible
	var top_left_x:int = entity.position.x - (entity.view_range * tile_width)
	var top_left_y:int = entity.position.y - (entity.view_range * tile_height)
	for i in range(entity.view_range * 2 + 1):
		for j in range(entity.view_range * 2 + 1):
			var tile_x:int = top_left_x + (i * tile_width)
			var tile_y:int = top_left_y + (j * tile_height)
			var total_index_displacement:int = (abs(tile_x - entity.position.x) / tile_width) + (abs(tile_y - entity.position.y) / tile_height)
			var current_position:Vector2 = entity.position
			for k in range(total_index_displacement):
				current_position.x += (tile_x - current_position.x) / (total_index_displacement - k)
				current_position.y += (tile_y - current_position.y) / (total_index_displacement - k)
				var current_index:Vector2 = _new_GetCoord.vector_to_index(current_position.x, current_position.y)
				var vision_blocked_by_object:bool = false
				for a in range(objects.size()):
					if objects[a].position == _new_GetCoord.index_to_vector(current_index.x, current_index.y) && objects[a].blocks_vision == true:
						vision_blocked_by_object = true
						objects[a].seen = true
						objects[a].visible = true
				if map[current_index.x][current_index.y].blocks_vision == true || vision_blocked_by_object == true:
					map[current_index.x][current_index.y].visible = true
					map[current_index.x][current_index.y].seen = true
					map[current_index.x][current_index.y].modulate.a = 1
					break
				else:
					map[current_index.x][current_index.y].visible = true
					map[current_index.x][current_index.y].seen = true
					for a in range(entities.size()):
						if entities[a].position == _new_GetCoord.index_to_vector(current_index.x, current_index.y):
							entities[a].visible = true
							map[current_index.x][current_index.y].visible = false
					for a in range(items.size()):
						if items[a].position == current_position:
							items[a].visible = true
							map[current_index.x][current_index.y].visible = false


func trim_text_readout():
	var line_count = $Text_Log.get_line_count()
	if line_count > 20:
		for i in range(line_count - 1, 20, -1):
			$Text_Log.remove_line(i)


func text_out(string:String):
	$Text_Log.text = "%s\n%s" % [string, $Text_Log.text]
	trim_text_readout()


func place_terrain(x, y, terrain_scene:PackedScene, terrain_name:String, walkable:bool, blocks_vision:bool):
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(x, y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	terrain.blocks_vision = blocks_vision
	get_parent().add_child(terrain)
	return terrain


func replace_terrain(index_x, index_y, terrain_scene:PackedScene, terrain_name:String, walkable:bool, blocks_vision:bool) -> void:
	var terrain = terrain_scene.instance()
	terrain.position = _new_GetCoord.index_to_vector(index_x, index_y)
	terrain.terrain_name = terrain_name
	terrain.walkable = walkable
	terrain.blocks_vision = blocks_vision
	get_parent().add_child(terrain)
	get_parent().remove_child(map[index_x][index_y])
	map[index_x][index_y] = terrain

# Creates a creature with stats, some form of movement type, and optional tags
func create_entity(x, y, entity_scene:PackedScene, entity_name:String, entity_health:int,
		entity_damage:int, entity_energy_max:int = 0, movement_style:String = "AStar",
		descriptor_tags:Array = [], ranged_attack_damage:int = 1,  entity_walkable:bool = false):
	var entity = entity_scene.instance()
	entity.entity_name = entity_name
	entity.position = _new_GetCoord.index_to_vector(x, y)
	entity.health_max = entity_health
	entity.health_current = entity.health_max
	entity.energy_max = entity_energy_max
	entity.energy_current = entity.energy_max
	entity.damage = entity_damage
	entity.ranged_damage = ranged_attack_damage
	entity.walkable = entity_walkable
	entity.alive = true
	entity.move_type = movement_style
	entity.tags = descriptor_tags
	entity.z_index = 1
	get_parent().add_child(entity)
	entities.append(entity)


func create_item(x, y, item_scene:PackedScene, item_name:String, health:int = 0, energy:int = 0, string_tags:Array = [], item_color:Color = Color(1, 1, 1)):
	var item = item_scene.instance()
	item.position = _new_GetCoord.index_to_vector(x, y)
	item.item_name = item_name
	item.health = health
	item.energy = energy
	item.modulate = item_color
	item.image_scene = item_scene
	item.image_color = item_color
	for i in range(string_tags.size()):
		item.item_tags.append(string_tags[i])
	get_parent().add_child(item)
	items.append(item)

# Checks for anything dead and calls create_corpse
func create_corpses():
	for i in range(entities.size() - 1, -1, -1):
		if entities[i].alive == false:
			create_corpse(entities[i])

# Specific create_item function for dead entities
func create_corpse(entity):
	var corpse_position:Vector2 = _new_GetCoord.vector_to_index(entity.position.x, entity.position.y)
	var item_name:String = entity.entity_name
	var corpse_color:Color = Color(0.5, 0.5, 0.5)
	var corpse_tags:Array = ["Corpse"]
	for i in range(entity.tags.size()):
		if entity.tags[i] == "Machine":
			item_name = "%s scrap" % entity.entity_name
			corpse_color = Color(0.5, 0.5, 0.5)
			corpse_tags.append("Tech")
		# Check for meat creature tag second so cyborgs will have corpses instead of scrap
		if entity.tags[i] == "Meat":
			item_name = "%s corpse" % entity.entity_name
			corpse_color = Color(1, 0, 0)
			corpse_tags.append("Meat")
	create_item(corpse_position.x, corpse_position.y, _corpse_scene, item_name, 0, 0, corpse_tags, corpse_color)
	get_parent().remove_child(entity)
	for i in range(entities.size()):
		if entities[i] == entity:
			entities.remove(i)
			break

# Creates terrain pieces like fountains that will replace floor tiles after base map generation
func create_room_object(x, y, object_scene:PackedScene, object_name:String, astar_node:int, blocks_vision:bool = true):
	var room_object = object_scene.instance()
	room_object.position = _new_GetCoord.index_to_vector(x, y)
	room_object.room_object_name = object_name
	room_object.blocks_vision = blocks_vision
	room_object.astar_node = astar_node
	astar.set_point_disabled(astar_node)
	objects.append(room_object)
	get_parent().add_child(room_object)
	map[x][y].walkable = false

# Determines pathfinding based on entity.move_type tag
# ToDo - Coward - Flees from player
# ToDo - Ambush - Waits until the player has interacted with it first
# Astar - Most direct pursuit of player, sees doors as obstacles
# ToDo - Roam - Wandering until player spotted, switch tag to AStar once seen
# ToDo - Smart - Once player seen, takes more direct routes, factoring in door shortcuts, might require a second astar node array
func movement_type(moving_entity):
	if moving_entity.move_type == "AStar":
		var path_to_player:Array = astar.get_point_path(astar.get_closest_point(moving_entity.position), astar.get_closest_point(player.position))
		if path_to_player.size() > 1:
			var dx:int = (path_to_player[1].x - path_to_player[0].x) / tile_width
			var dy:int = (path_to_player[1].y - path_to_player[0].y) / tile_height
			try_move(moving_entity, dx, dy)


func end_player_turn():
	turn_number += 1
	# Heal back 1 health every ten turns
	if (player.health_current < player.health_max) && (turn_number % 10 == 0):
		player.health_current += 1
	update_inventory_panel(-1)
	update_status_screen()
	create_corpses()
	enemy_phase()
	update_fov(player)


func astar_debug():
	for i in range(map.size()):
		for j in range(map[i].size()):
			if map[i][j].position == astar.get_point_position(astar.get_closest_point(map[i][j].position)):
				var astar_node = astar.get_closest_point(map[i][j].position)
				var wpxl = white_pixel.instance()
				wpxl.position = map[i][j].position
				var connections:Array = astar.get_point_connections(astar_node)
				get_parent().add_child(wpxl)
				for k in range(connections.size()):
					var rpxl = white_pixel.instance()
					rpxl.modulate = Color(1, 0, 0)
					rpxl.position = (astar.get_point_position(astar_node) + astar.get_point_position(connections[k])) / 2
					get_parent().add_child(rpxl)
