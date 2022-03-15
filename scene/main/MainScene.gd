extends Node2D

var score_file = "user://score.save"

var white_pixel:PackedScene = preload("res://sprite/WhitePixel.tscn")
# Sprite scenes
var _floor_scene:PackedScene = preload("res://sprite/Floor.tscn")
var _wall_scene:PackedScene = preload("res://sprite/Wall.tscn")
var _player_scene:PackedScene = preload("res://sprite/Player.tscn")
var _b_lower:PackedScene = preload("res://sprite/b_lower.tscn")
var _b_upper:PackedScene = preload("res://sprite/b_upper.tscn")
var _c_lower:PackedScene = preload("res://sprite/c_lower.tscn")
var _d_lower_scene:PackedScene = preload("res://sprite/d_lower.tscn")
var _d_upper:PackedScene = preload("res://sprite/d_upper.tscn")
var _n_upper:PackedScene = preload("res://sprite/n_upper.tscn")
var _o_scene:PackedScene = preload("res://sprite/o_lower.tscn")
var _o_entity:PackedScene = preload("res://sprite/o_lower_entity.tscn")
var _o_upper:PackedScene = preload("res://sprite/o_upper.tscn")
var _s_scene:PackedScene = preload("res://sprite/s_lower.tscn")
var _s_upper_scene:PackedScene = preload("res://sprite/s_upper.tscn")
var _w_upper:PackedScene = preload("res://sprite/w_upper.tscn")
var _door_scene:PackedScene = preload("res://sprite/Door.tscn")
var _corpse_scene:PackedScene = preload("res://sprite/Corpse.tscn")
var _chest_scene:PackedScene = preload("res://sprite/Chest.tscn")
var _fountain_scene:PackedScene = preload("res://sprite/Fountain.tscn")
var _stairs_scene:PackedScene = preload("res://sprite/Stairs.tscn")
var _plus_scene:PackedScene = preload("res://sprite/PlusSign.tscn")
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
var died_message:bool = false
var game_won:bool = false
var map_generated:bool = false
var player_turn:bool = true
var shoot_mode:bool = false
var inventory_mode:bool = false
# Constants
# Integers
var floor_number:int = 0
var highscore:int
var life_support_timer:int = 200
var score:int = 0
var slot_number:int = 0 # Used for item selection in use_mode
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
	if Input.is_action_pressed("Reset Run"):
		for i in range(entities.size()-1, -1, -1):
			get_parent().remove_child(entities[i])
			entities.remove(i)
		print(entities)
		for i in range(items.size()-1, -1, -1):
			get_parent().remove_child(items[i])
			items.remove(i)
		print(items)
		for i in range(objects.size()-1, -1, -1):
			get_parent().remove_child(objects[i])
			objects.remove(i)
		print(objects)
		for i in range(inventory.size()-1, -1, -1):
			inventory.remove(i)
		score = 0
		for i in range(map.size()-1, -1, -1):
			for j in range(map[i].size()-1, -1, -1):
				get_parent().remove_child(map[i][j])
				map[i].remove(j)
			map.remove(i)
			map_generated = false
			$SpaceToGenMap.visible = true
			floor_number = 0
			turn_number = 0
			$Text_Log.text = ""
			astar.clear()
	
	# Handles start screen input (space to start)
	if Input.is_action_pressed("start_game") && map_generated == false:
		
		load_score()
		
		$SpaceToGenMap.visible = false
		map_generated = true
		text_out("WARNING: CATASTROPHIC SYSTEMS FAILURE, EVACUATE THE STATION IMMEDIATELY!")
		create_entity(-1, -1, _player_scene, "Player", 20, 5, 10, "Player", ["Meat"], 5)
		player = entities[0]
		player.view_range = 5
		player.ranged_attack_cost = 2
		generate_map()
		update_fov(player)
		# Yellow tile used for shooting
		aim_tile = _wall_scene.instance()
		aim_tile.modulate = Color(1, 1, 0, 0.5)
		aim_tile.z_index = -5
		aim_tile.visible = false
		get_parent().add_child(aim_tile)
	
	if (map_generated == true) && (player_turn == true) && (player.alive == true) && (shoot_mode == false) && (inventory_mode == false) && game_won == false:
		
		if Input.is_action_pressed("enter"):
			var new_map:bool = false
			print(player.position)
			for i in range(map.size()):
				if new_map == true:
					break
				for j in range(map[i].size()):
					if map[i][j].terrain_name == "Stairs" && map[i][j].position == player.position:
						life_support_timer += 145
						
						if floor_number < 20:
							text_out("You descend the ladder to the next floor")
							new_map = true
							break
						else:
							win_game()
			if new_map == true:
				generate_map()
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
			var is_corpse:bool = false
			for i in range(items.size() - 1, -1, -1):
				if (items[i].position == player.position):
					item_found = true
					item_index = i
					for j in range(items[i].item_tags.size()):
						if items[i].item_tags[j] == "Meat" || items[i].item_tags[j] == "Tech":
							is_corpse = true
							use_item(items[i], player)
							get_parent().remove_child(items[i])
							items.remove(i)
							player_turn = false
							break
					break
			
			if item_found == true && inventory.size() < 10 && is_corpse == false:
				inventory.append(items[item_index])
				text_out("You picked up the %s" % items[item_index].item_name)
				get_parent().remove_child(items[item_index])
				items.remove(item_index)
				player_turn = false
			elif item_found == true && inventory.size() > 9 && is_corpse == false:
				text_out("You can't carry any more!")
			elif item_found == false:
				text_out("There's nothing there")
		if Input.is_action_pressed("shoot"):
			shoot_mode = true
			aim_tile.position = player.position
			aim_tile.visible = true
		
		# Number keys to use inventory
		if Input.is_action_pressed("1"):
			if inventory.size() > 0:
				use_item(inventory[0], player)
				inventory.remove(0)
				end_player_turn()
		if Input.is_action_pressed("2"):
			if inventory.size() > 1:
				use_item(inventory[1], player)
				inventory.remove(1)
				end_player_turn()
		if Input.is_action_pressed("3"):
			if inventory.size() > 2:
				use_item(inventory[2], player)
				inventory.remove(2)
				end_player_turn()
		if Input.is_action_pressed("4"):
			if inventory.size() > 3:
				use_item(inventory[3], player)
				inventory.remove(3)
				end_player_turn()
		if Input.is_action_pressed("5"):
			if inventory.size() > 4:
				use_item(inventory[4], player)
				inventory.remove(4)
				end_player_turn()
		if Input.is_action_pressed("6"):
			if inventory.size() > 5:
				use_item(inventory[5], player)
				inventory.remove(5)
				end_player_turn()
		if Input.is_action_pressed("7"):
			if inventory.size() > 6:
				use_item(inventory[6], player)
				inventory.remove(6)
				end_player_turn()
		if Input.is_action_pressed("8"):
			if inventory.size() > 7:
				use_item(inventory[7], player)
				inventory.remove(7)
				end_player_turn()
		if Input.is_action_pressed("9"):
			if inventory.size() > 8:
				use_item(inventory[8], player)
				inventory.remove(8)
				end_player_turn()
		if Input.is_action_pressed("0"):
			if inventory.size() > 9:
				use_item(inventory[9], player)
				inventory.remove(9)
				end_player_turn()
		
	
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


func generate_map():
	
	# Floor number iterates, clean slate the arrays
	floor_number += 1
	# Preserve player as first entity
	if floor_number > 1:
		while entities.size() > 1:
			get_parent().remove_child(entities[1])
			entities.remove(1)
		while map.size() > 0:
			while map[0].size() > 0:
				get_parent().remove_child(map[0][0])
				map[0].remove(0)
			map.remove(0)
		while items.size() > 0:
			get_parent().remove_child(items[0])
			items.remove(0)
		while objects.size() > 0:
			get_parent().remove_child(objects[0])
			objects.remove(0)
		astar.clear()
	
	#Fill space with walls, populate the map array
	for i in range(33):
		map.append([])
		for j in range(17):
			var _wall = place_terrain(i, j, _wall_scene, "wall", false, true)
			if floor_number <= 5:
				_wall.modulate = Color(1, 1, 1)
			elif floor_number <= 10:
				_wall.modulate = Color(0.5, 0.5, 1)
			elif floor_number <= 15:
				_wall.modulate = Color(1, 0.5, 0)
			else:
				_wall.modulate = Color(1, 0.25, 0.25)
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
		var door_there:bool
		if room_list[i][0] < 7:# Check Right wall if not in right column
			door_there = false
			for a in range(objects.size()):
				if objects[a].position == _new_GetCoord.index_to_vector(room_map_x + 2, room_map_y):
					door_there = true
			if map[room_map_x + 2][room_map_y].terrain_name == "floor":
				if map[room_map_x + 2][room_map_y + 1].terrain_name == "wall" && door_there == false:
					create_room_object(room_map_x + 2, room_map_y, _door_scene, "door", astar.get_closest_point(map[room_map_x + 2][room_map_y].position))
		if room_list[i][0] > 0:# Check Left Wall if not in left column
			door_there = false
			for a in range(objects.size()):
				if objects[a].position == _new_GetCoord.index_to_vector(room_map_x - 2, room_map_y):
					door_there = true
			if map[room_map_x - 2][room_map_y].terrain_name == "floor":
				if map[room_map_x - 2][room_map_y + 1].terrain_name == "wall" && door_there == false:
					create_room_object(room_map_x - 2, room_map_y, _door_scene, "door", astar.get_closest_point(map[room_map_x - 2][room_map_y].position))
		if room_list[i][1] < 3:# Check Bottom Wall if not in bottom row
			door_there = false
			for a in range(objects.size()):
				if objects[a].position == _new_GetCoord.index_to_vector(room_map_x, room_map_y + 2):
					door_there = true
			if map[room_map_x][room_map_y + 2].terrain_name == "floor":
				if map[room_map_x + 1][room_map_y + 2].terrain_name == "wall" && door_there == false:
					create_room_object(room_map_x, room_map_y + 2, _door_scene, "door", astar.get_closest_point(map[room_map_x][room_map_y + 2].position))
		if room_list[i][1] > 0:#Check top Wall if not in top row
			door_there = false
			for a in range(objects.size()):
				if objects[a].position == _new_GetCoord.index_to_vector(room_map_x, room_map_y - 2):
					door_there = true
			if map[room_map_x][room_map_y - 2].terrain_name == "floor":
				if map[room_map_x + 1][room_map_y - 2].terrain_name == "wall" && door_there == false:
					create_room_object(room_map_x, room_map_y - 2, _door_scene, "door", astar.get_closest_point(map[room_map_x][room_map_y - 2].position))
	
	# Places player, enemies, items and room objects randomly in rooms
	player.position = _new_GetCoord.index_to_vector(4 * room_list[0][0] + 2, 4 * room_list[0][1] + 2)
	for i in range(room_list.size()):
		var random_roll:int = randi() % 10
		var luck_roll:int = randi() % 2
		var room_vector_coords:Vector2 = Vector2(4 * room_list[i][0] + 2, 4 * room_list[i][1] + 2)
		var random_x:int = randi() % 3 - 1
		var random_y:int = randi() % 3 - 1
		var rand_item:int
		var rand_enemy:int
		var rand_object:int
		
		var occupied_index:Vector2 = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
		var occupied_tiles:Array = []
		var overlap:bool = false
		
		var scarcity_benchmark:int = (floor_number % 5) - 1
		var scarcity_var:int = randi() % 5 + 1
		# Makes items get more scarce as you approach each multiple of 5 (5, 10, 15, 20)
		
		match random_roll:
			0: # Rolled Nothing
				pass
				
			1: # 1 item
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
				
			2: # 1 enemy
				roll_enemy(floor_number, occupied_index)
				
			3: # 1 item, 1 enemy
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				
			4: # 2 enemies
				roll_enemy(floor_number, occupied_index)
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				if room_vector_coords.x + random_x == occupied_index.x && room_vector_coords.y + random_y == occupied_index.y:
					if random_x == 0 && random_y == 0:
						random_x += 1
					else:
						random_x = random_x * -1
						random_y = random_y * -1
					occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				
			5: # 2 items, 1 enemy
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				scarcity_var = randi() % 5 + 1
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, occupied_index)
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				
			6: # 2 items, 2 enemies
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, occupied_index)
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				scarcity_var = randi() % 5 + 1
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, occupied_index)
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				if room_vector_coords.x + random_x == occupied_index.x && room_vector_coords.y + random_y == occupied_index.y:
					if random_x == 0 && random_y == 0:
						random_x += 1
					else:
						random_x = random_x * -1
						random_y = random_y * -1
					occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				
			7: # 1 enemy, item, and room object
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				var door_check_passed:bool = true
				for a in range(objects.size()):
					# checks for doors being blocked by the object
					if _new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y - 1) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y + 1) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x + 1, occupied_index.y) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x - 1, occupied_index.y) == objects[a].position:
						door_check_passed = false
				if door_check_passed == true:
					var reduce_number:int = randi() % 2
					if reduce_number == 0:
						create_room_object(occupied_index.x, occupied_index.y, _fountain_scene, "Charging Station", astar.get_closest_point(_new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y)))
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				if room_vector_coords.x + random_x == occupied_index.x && room_vector_coords.y + random_y == occupied_index.y:
					if random_x == 0 && random_y == 0:
						random_x += 1
					else:
						random_x = random_x * -1
						random_y = random_y * -1
					occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				roll_enemy(floor_number, occupied_index)
				
			8: #  1 item and room object
				if scarcity_var > scarcity_benchmark:
					roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
				random_x = randi() % 3 - 1
				random_y = randi() % 3 - 1
				occupied_index = Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y)
				var door_check_passed:bool = true
				for a in range(objects.size()):
					# checks for doors being blocked by the object
					if _new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y - 1) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y + 1) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x + 1, occupied_index.y) == objects[a].position:
						door_check_passed = false
					elif _new_GetCoord.index_to_vector(occupied_index.x - 1, occupied_index.y) == objects[a].position:
						door_check_passed = false
				if door_check_passed == true:
					var reduce_number:int = randi() % 2
					if reduce_number == 0:
						create_room_object(occupied_index.x, occupied_index.y, _fountain_scene, "Charging Station", astar.get_closest_point(_new_GetCoord.index_to_vector(occupied_index.x, occupied_index.y)))
				
			9: # Empty or Loot Room
				var chance:int = randi() % 10
				var lootcount:int = randi() % 3 + 3
				if chance == 0:
					for a in range(lootcount):
						if scarcity_var > scarcity_benchmark:
							roll_item(floor_number, Vector2(room_vector_coords.x + random_x, room_vector_coords.y + random_y))
						random_x = randi() % 3 - 1
						random_y = randi() % 3 - 1
						scarcity_var = randi() % 5 + 1
	
	# Places stairs and clears the tile of the stairs of items and objects and prevents entities or objects starting on top of player
	var stairs_index:Vector2 = Vector2(4 * room_list[room_list.size() - 1][0] + 2, 4 * room_list[room_list.size() - 1][1] + 2)
	var stairs_location:Vector2 = _new_GetCoord.index_to_vector(4 * room_list[room_list.size() - 1][0] + 2, 4 * room_list[room_list.size() - 1][1] + 2)
	for i in range(items.size() - 1, -1, -1):
		if items[i].position == stairs_location:
			get_parent().remove_child(items[i])
			items.remove(i)
	for i in range(objects.size() - 1, -1, -1):
		if objects[i].position == stairs_location || objects[i].position == player.position:
			get_parent().remove_child(objects[i])
			objects.remove(i)
	for i in range(entities.size() - 1, -1, -1):
		if entities[i].position == player.position && entities[i] != player:
			get_parent().remove_child(entities[i])
			entities.remove(i)
	
	replace_terrain(stairs_index.x, stairs_index.y, _stairs_scene, "Stairs", true, false)
	
	#Prevents overlapping enemies, clears starting room
	for i in range(entities.size() - 1, -1, -1):
		for j in range(entities.size() - 1, -1, -1):
			if entities[j].position == entities[i].position && entities[j] != entities[i]:
				get_parent().remove_child(entities[j])
				entities.remove(j)
				break
		if entities.size() < i:
			if (entities[i].position.x > player.position.x - tile_width - 1 && entities[i].position.x < player.position.x + tile_width + 1 &&
					entities[i].position.y > player.position.y - tile_height - 1 && entities[i].position.y < player.position.y + tile_height + 1 &&
					entities[i] != player):
				get_parent().remove_child(entities[i])
				entities.remove(i)
	
	for i in range(map.size()):
		for j in range(map[i].size()):
			map[i][j].visible = false
	for i in range(entities.size() - 1, 1, 1):
		for j in range(entities.size() -1, -1, -1):
			if entities[i].position == entities[j].position && entities[i] != entities[j] && entities[j] != player:
				get_parent().remove_child(entities[j])
				entities.remove(j)
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
	if object.room_object_name == "Charging Station" && object.active == true:
		var rand_roll:int = randi() % 4
		if player.energy_current == player.energy_max:
			text_out("Your energy is already at full.")
		elif rand_roll > 0:
			text_out("The charging station refills you energy and shuts down.")
			player.energy_current = player.energy_max
			object.active = false
			object.modulate = Color(0.25, 0.25, 0.25)
			update_status_screen()
			if player_turn == true:
				player_turn = false
		else:
			text_out("The charging station refills your energy.")
			player.energy_current = player.energy_max
			update_status_screen()
			if player_turn == true:
				player_turn = false


func use_item(item, entity):
	for i in range(item.item_tags.size()):
		# Restoratives and Buffs
		if item.item_tags[i] == "restore":
			entity.health_current += item.health
			entity.energy_current += item.energy
		if item.item_tags[i] == "increase":
			entity.health_current += item.health
			entity.health_max += item.health
			entity.energy_current += item.energy
			entity.energy_max += item.energy
		if item.item_tags[i] == "damage_buff":
			entity.damage += 1
		if item.item_tags[i] == "ranged_buff":
			entity.ranged_damage += 1
		# Prevent rstoration going over max
		if entity.energy_current > entity.energy_max:
			entity.energy_current = entity.energy_max
		if entity.health_current > entity.health_max:
			entity.health_current = entity.health_max
		
		# Corpse Scavenging
		if item.item_tags[i] == "Meat":
			var random_chance:int = randi() % 20
			var player_index:Vector2 = _new_GetCoord.vector_to_index(player.position.x, player.position.y)
			if random_chance == 0:
				text_out("As you pull apart the viscera, a warm lump falls from the corpse's innards.")
				create_item(player_index.x, player_index.y, _o_scene, "Stable Mutagen", 2, 0, ["increase", "damage_buff"], Color(0.7, 0, 0))
			elif random_chance > 0 && random_chance < 6:
				text_out("As you dig through the viscera, a small lump falls from the corpse's innards.")
				create_item(player_index.x, player_index.y, _o_scene, "Semi-Stable Mutagen", 2, 0, ["increase"], Color(1, 0, 0))
			else:
				text_out("You find nothing useful on the corpse.")
		if item.item_tags[i] == "Tech":
			var random_chance:int = randi() % 10
			var player_index:Vector2 = _new_GetCoord.vector_to_index(player.position.x, player.position.y)
			if random_chance == 0:
				text_out("As you pull an actuator from its socket, something clatters to the floor.")
				create_item(player_index.x, player_index.y, _o_scene, "Small Capacitor", 0, 1, ["increase"], Color(0.5, 0.5, 1))
			elif random_chance < 4:
				text_out("As you pull on a bundle of wiring, something falls at your feet.")
				create_item(player_index.x, player_index.y, _o_scene, "Micro Energy Cell", 0, 3, ["restore"], Color(0.5, 0.5, 1))
			else:
				text_out("You find nothing useful in the scrap.")


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
		score += defender.score


func enemy_phase():
	for i in range(1, entities.size()): 
		if entities[i].alive == true && player.alive == true:
			movement_type(entities[i])
	create_corpses()
	update_status_screen()
	check_player_alive()
	player_turn = true


func update_status_screen():
	$HealthBar.max_value = player.health_max
	$HealthBar.value = player.health_current
	$EnergyBar.max_value = player.energy_max
	$EnergyBar.value = player.energy_current
	if score <= highscore:
		$StatusNumbers.text = "Melee Attack Damage: %s\nRanged Attack Damage: %s\n\n\nHighscore: %s\nScore: %s" % [player.damage, player.ranged_damage, highscore, score]
	else:
		$StatusNumbers.text = "Melee Attack Damage: %s\nRanged Attack Damage: %s\n\n\n!!Highscore: %s!!\nScore: %s" % [player.damage, player.ranged_damage, score, score]
	$TurnTracker.text = "Floor Number: %s\nTurn: %s" % [floor_number, turn_number]
	$StatusScreen.text = "%s%s%s\n%s%s%s" % [player.health_current, "/", player.health_max , player.energy_current, "/", player.energy_max]


func update_inventory_panel(inventory_slot_num):
	$InventoryScreen.text = "Inventory:\n\n"
	var empty_slot_number:int = 10 - inventory.size()
	var slot_number:int
	for i in range(inventory.size()):
		if i == 9:
			slot_number = 0
		else:
			slot_number = i + 1
		$InventoryScreen.text = "%s%s) %s\n" % [$InventoryScreen.text, slot_number, inventory[i].item_name]
	for i in range(empty_slot_number):
		if (inventory.size() + i + 1) == 10:
			slot_number = 0
		else:
			slot_number = inventory.size() + i + 1
		$InventoryScreen.text = "%s%s) \n" % [$InventoryScreen.text, slot_number]

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
		descriptor_tags:Array = [], ranged_attack_damage:int = 1, entity_color:Color = Color(1, 1, 1), score_value:int = 0,
		entity_walkable:bool = false):
	var entity = entity_scene.instance()
	entity.entity_name = entity_name
	entity.position = _new_GetCoord.index_to_vector(x, y)
	entity.health_max = entity_health
	entity.health_current = entity.health_max
	entity.energy_max = entity_energy_max
	entity.energy_current = entity.energy_max
	entity.damage = entity_damage
	entity.ranged_damage = ranged_attack_damage
	entity.modulate = entity_color
	entity.walkable = entity_walkable
	entity.alive = true
	entity.move_type = movement_style
	entity.score = score_value
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
func create_room_object(x, y, object_scene:PackedScene, object_name:String, astar_node:int, blocks_vision:bool = true, active:bool = true):
	var room_object = object_scene.instance()
	room_object.position = _new_GetCoord.index_to_vector(x, y)
	room_object.room_object_name = object_name
	room_object.blocks_vision = blocks_vision
	room_object.astar_node = astar_node
	room_object.active = active
	astar.set_point_disabled(astar_node)
	objects.append(room_object)
	get_parent().add_child(room_object)
	map[x][y].walkable = false

# Determines pathfinding based on entity.move_type tag
# Astar - Most direct pursuit of player, sees doors as obstacles
func movement_type(moving_entity):
	if moving_entity.move_type == "AStar":
		var path_to_player:Array = astar.get_point_path(astar.get_closest_point(moving_entity.position), astar.get_closest_point(player.position))
		if path_to_player.size() > 1:
			var dx:int = (path_to_player[1].x - path_to_player[0].x) / tile_width
			var dy:int = (path_to_player[1].y - path_to_player[0].y) / tile_height
			try_move(moving_entity, dx, dy)


func end_player_turn():
	turn_number += 1
	# Heal back 1% health every 10 turns (minimum of 1 health)
	if (player.health_current < player.health_max) && (turn_number % 10 == 0):
		player.health_current += round(clamp((player.health_max / 100), 1, 100))
	
	update_inventory_panel(-1)
	update_status_screen()
	
	enemy_phase()
	update_fov(player)
	
	if life_support_timer - turn_number == 150:
		text_out("Warning: Life Support at 75%")
	elif life_support_timer - turn_number == 100:
		text_out("Warning: Life Support at 50%")
	elif life_support_timer - turn_number == 50:
		text_out("Warning: Life support at 25%")
	elif life_support_timer - turn_number == 20:
		text_out("Warning: Life support at 10%")
	elif life_support_timer - turn_number == 10:
		text_out("Warning: Life support at 5%")
	elif life_support_timer - turn_number == 0:
		text_out("Warning: Life Support at 0%")
	elif life_support_timer - turn_number == -1:
		for i in range(map.size()):
			for j in range(map[i].size()):
				map[i][j].modulate.a = 0.8
	elif life_support_timer - turn_number == -2:
		for i in range(map.size()):
			for j in range(map[i].size()):
				map[i][j].modulate.a = 0.6
	elif life_support_timer - turn_number == -3:
		for i in range(map.size()):
			for j in range(map[i].size()):
				map[i][j].modulate.a = 0.4
	elif life_support_timer - turn_number == -4:
		for i in range(map.size()):
			for j in range(map[i].size()):
				map[i][j].modulate.a = 0.2
	elif life_support_timer - turn_number == -5:
		for i in range(map.size()):
			for j in range(map[i].size()):
				map[i][j].modulate.a = 0.2
				player.alive = false
	
	create_corpses()
	check_player_alive()


func roll_item(floor_num:int, index_position:Vector2):
	var random_roll:int = randi() % 5
	var random_type_roll:int = randi() % 4
	var coin_toss:int = randi() % 2
	var item_name:String = "AnErrorHasOccurred"
	var type:Array = []
	var health:int = 0
	var energy:int = 0
	var item_scene:PackedScene = _o_scene
	var item_color:Color = Color(1, 1, 1)
	match random_type_roll:
		0, 1, 2:
			type.append("restore")
		3:
			type.append("increase")
	
	match floor_num + random_roll:
		1, 2, 3, 4, 5:
			if type[0] == "restore":
				if coin_toss == 0:
					health = 6
					item_name = "Small Medical Hypo"
					item_scene = _plus_scene
					item_color = Color(1, 0, 0)
				elif coin_toss == 1:
					energy = 5
					item_name = "Energy Cell"
					item_scene = _o_scene
					item_color = Color(0.5, 0.5, 1)
			if type[0] == "increase":
				if coin_toss == 0:
					health = 1
					item_name = "Glowing Hypo"
					item_scene = _plus_scene
					item_color = Color(1, 0.5, 0.5)
				elif coin_toss == 1:
					energy = 2
					item_name = "Small Capacitor"
					item_scene = _o_scene
					item_color = Color(0.25, 0.25, 1)
		6, 7, 8, 9, 10:
			if type[0] == "restore":
				if coin_toss == 0:
					health = 12
					item_name = "Medical Hypo"
					item_scene = _plus_scene
					item_color = Color(1, 0, 0)
				elif coin_toss == 1:
					energy = 5
					item_name = "Energy Cell"
					item_scene = _o_scene
					item_color = Color(0.5, 0.5, 1)
			if type[0] == "increase":
				if coin_toss == 0:
					health = 3
					item_name = "Large Glowing Hypo"
					item_scene = _plus_scene
					item_color = Color(1, 0.5, 0.5)
				elif coin_toss == 1:
					energy = 4
					item_name = "Large Capacitor"
					item_scene = _o_scene
					item_color = Color(0.25, 0.25, 1)
		11, 12, 13, 14, 15:
			if type[0] == "restore":
				if coin_toss == 0:
					health = 18
					item_name = "Medical Kit"
					item_scene = _plus_scene
					item_color = Color(1, 0, 0)
				elif coin_toss == 1:
					energy = 5
					item_name = "Energy Cell"
					item_scene = _o_scene
					item_color = Color(0.5, 0.5, 1)
			if type[0] == "increase":
				if coin_toss == 0:
					health = (randi() % 3 - 1) * 3
					if health > -1:
						type.append("damage_buff")
					item_name = "Experimental Hypo"
					item_scene = _plus_scene
					item_color = Color(1, 0.25, 0)
				elif coin_toss == 1:
					var second_coin_toss:int = randi() % 2
					if second_coin_toss == 0:
						energy = (randi() % 3 - 1) * 4
						if energy > -1:
							type.append("ranged_buff")
						item_name = "Experimental Capacitor"
						item_scene = _o_scene
						item_color = Color(0, 1, 1)
		16, 17, 18, 19, 20:
			if type[0] == "restore":
				if coin_toss == 0:
					health = 24
					item_name = "Large Medical Kit"
					item_scene = _plus_scene
					item_color = Color(1, 0, 0)
				elif coin_toss == 1:
					energy = 5
					item_name = "Energy Cell"
					item_scene = _o_scene
					item_color = Color(0, 1, 1)
			if type[0] == "increase":
				if coin_toss == 0:
					health = (randi() % 7 - 3) * 3
					if health > -1:
						type.append("damage_buff")
					item_name = "Experimental Treatment"
					item_scene = _plus_scene
					item_color = Color(1, 0.5, 0.5)
				elif coin_toss == 1:
					var second_coin_toss:int = randi() % 2
					if second_coin_toss == 0:
						energy = (randi() % 9 - 4) * 2
						if energy > -1:
							type.append("ranged_buff")
							type.append("ranged_buff")
						item_name = "Unstable Capacitor"
						item_scene = _o_scene
						item_color = Color(0.75, 0.75, 1)
		21:
			pass
		22:
			if type[0] == "restore":
				if coin_toss == 0:
					health = 32
					item_name = "Hi-Potency Capsule"
					item_scene = _plus_scene
					item_color = Color(1, 0, 0)
				elif coin_toss == 1:
					energy = 10
					item_name = "Large Energy Cell"
					item_scene = _o_scene
					item_color = Color(0, 1, 1)
			if type[0] == "increase":
				if coin_toss == 0:
					health = (randi() % 7 - 1) * 3
					if health > -1:
						type.append("damage_buff")
					item_name = "Stable Experimental Treatment"
					item_scene = _plus_scene
					item_color = Color(1, 0.5, 0.5)
				elif coin_toss == 1:
					var second_coin_toss:int = randi() % 2
					if second_coin_toss == 0:
						energy = (randi() % 9 - 1) * 2
						if energy > -1:
							type.append("ranged_buff")
							type.append("ranged_buff")
						item_name = "Stable Experimental Capacitor"
						item_scene = _o_scene
						item_color = Color(0.75, 0.75, 1)
		23, 24:
			pass
	
	if item_name != "AnErrorHasOccurred":
		create_item(index_position.x, index_position.y, item_scene, item_name, health, energy, type, item_color)

# Number range is min:0, max:24
func roll_enemy(floor_num:int, index_position:Vector2):
	var rng:int
	if floor_num < 5:
		rng = randi() % 3 - 1
	elif floor_num < 10:
		rng = randi() % 5 - 2
	elif floor_num < 15:
		rng = randi() % 7 - 3
	else:
		rng = randi() % 9 - 4
	match floor_num + rng:
		0: # Weak scuttler
			create_entity(index_position.x, index_position.y, _s_scene, "Scuttle Bug", 5, 4, 0, "AStar", ["Meat"], 0, Color(1, 0.5, 0), 50)
		1: # Weak Roomba with a knife
			create_entity(index_position.x, index_position.y, _s_scene, "Sweeping Bot", 6, 3, 0, "AStar", ["Machine"], 0, Color(0.5, 0.5, 0.5), 75)
		2: # Basic Drone Enemy
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Cleaning Drone", 10, 5, 0, "AStar", ["Machine"], 0, Color(0.75, 0.75, 0.75), 100)
		3: # Small Mutated Mass
			create_entity(index_position.x, index_position.y, _o_entity, "Small Lump", 15, 4, 0, "AStar", ["Meat"], 0, Color(1, 0.25, 0.5), 125)
		4:
			create_entity(index_position.x, index_position.y, _s_upper_scene, "Slithering Beast", 12, 5, 0, "AStar", ["Meat"], 0, Color(0.75, 0.25, 0), 150)
		5:
			create_entity(index_position.x, index_position.y, _o_upper, "Flesh Mound", 20, 3, 0, "AStar", ["Meat"], 0, Color(1, 0.5, 0), 175)
		6:
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Delivery Drone", 12, 6, 0, "AStar", ["Machine"], 0, Color(0.8, 0.7, 0.3), 200)
		7:
			create_entity(index_position.x, index_position.y, _b_lower, "Cargo Bot", 18, 5, 0, "AStar", ["Machine"], 0, Color(0.7, 0.6, 0.3), 225)
		8: # Haywire Medical Drone
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Medical Drone", 18, 7, 0, "AStar", ["Machine"], 0, Color(0.5, 0.5, 1), 250)
		9: # Writhing mass of flesh
			create_entity(index_position.x, index_position.y, _o_entity, "Writhing Mass", 22, 6, 0, "AStar", ["Meat"], 0, Color(1, 0.25, 0), 275)
		10:
			create_entity(index_position.x, index_position.y, _c_lower, "Reanimated Crewman", 15, 7, 0, "AStar", ["Meat"], 0, Color(0.6, 0.7, 0.3), 300)
		11: # ND
			create_entity(index_position.x, index_position.y, _c_lower, "Rotting Crewman", 11, 6, 0, "AStar", ["Meat"], 0, Color(0.4, 0.5, 0.1), 325)
		12:
			create_entity(index_position.x, index_position.y, _b_upper, "Heavy Cargo Bot", 20, 7, 0, "AStar", ["Machine"], 0, Color(0.5, 0.5, 0.5), 350)
		13: # Haywire Maintenance Drone
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Maintenance Drone", 20, 9, 0, "AStar", ["Machine"], 0, Color(1, 0.5, 0), 375)
		14: # Lumbering mass of flesh
			create_entity(index_position.x, index_position.y, _o_upper, "Lumbering Mass", 25, 8, 0, "AStar", ["Meat"], 0, Color(1, 0, 0.5), 400)
		15:
			create_entity(index_position.x, index_position.y, _d_upper, "Bulky Maintenance Drone", 25, 9, 0, "AStar", ["Machine"], 0, Color(0.8, 0.4, 0), 425)
		16:
			create_entity(index_position.x, index_position.y, _c_lower, "Mutating Crewman", 20, 9, 0, "AStar", ["Meat"], 0, Color(0.5, 0.25, 0.5), 450)
		17:
			create_entity(index_position.x, index_position.y, _b_lower, "Freight Bot", 25, 9, 0, "AStar", ["Machine"], 0, Color(0.7, 0.6, 0.3), 475)
		18:
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Security Drone", 25, 11, 0, "AStar", ["Machine"], 0, Color(0.8, 0, 0), 500)
		19: # Hulking Mass of flesh
			create_entity(index_position.x, index_position.y, _o_upper, "Hulking Growth", 30, 10, 0, "AStar", ["Meat"], 0, Color(0.6, 0, 0.5), 525)
		20:
			create_entity(index_position.x, index_position.y, _s_upper_scene, "Overgrown Scuttle Bug", 15, 7, 0, "AStar", ["Machine"], 0, Color(1, 0.5, 0), 550)
		21:
			create_entity(index_position.x, index_position.y, _d_lower_scene, "Riot Drone", 30, 12, 0, "AStar", ["Machine"], 0, Color(0.9, 0, 0), 575)
		22:
			create_entity(index_position.x, index_position.y, _b_upper, "Heavy Freight Bot", 35, 11, 0, "AStar", ["Machine"], 0, Color(0.7, 0.6, 0.3), 600)
		23: # Peak drone
			create_entity(index_position.x, index_position.y, _w_upper, "Half-assembled War Drone", 50, 13, 0, "AStar", ["Machine"], 0, Color(0.9, 0.5, 0.5), 625)
		24: # Peak mass of flesh
			create_entity(index_position.x, index_position.y, _b_upper, "Hulking Beast", 55, 12, 0, "AStar", ["Meat"], 0, Color(0.5, 0, 0.5), 650)
		
	pass


func save_highscore():
	var file = File.new()
	file.open(score_file, File.WRITE)
	file.store_var(highscore)
	file.close()


func load_score():
	var file = File.new()
	if file.file_exists(score_file):
		file.open(score_file, File.READ)
		highscore = file.get_var()
		file.close()
	else:
		highscore = 0


func check_player_alive():
	if player.alive == false && died_message == false:
		text_out("You have died!")
		died_message = true
		if score > highscore:
			text_out("New Highscore!\n%s -> %s" % [highscore, score])
			highscore = score
			save_highscore()


func win_game():
	$Line2D.visible = false
	$Line2D2.visible = false
	$Line2D3.visible = false
	$Line2D4.visible = false
	$Text_Log.visible = false
	$Text_Log2.visible = false
	$StatusScreen.visible = false
	$TurnTracker.visible = false
	$StatusNumbers.visible = false
	$HealthBar.visible = false
	$EnergyBar.visible = false
	$InventoryScreen.visible = false
	$VictoryScreen.bbcode_text = "[center]You Win!\n\nScore: %s\n\n" % score
	for i in range(map.size()):
		for j in range(map[i].size()):
			map[i][j].visible = false
	for i in range(entities.size()):
		entities[i].visible = false
	for i in range(items.size()):
		items[i].visible = false
	for i in range(objects.size()):
		objects[i].visible = false
	
	if score > highscore:
		$VictoryScreen.bbcode_text = ("%s[center]!!New Highscore!!") % $VictoryScreen.bbcode_text
		highscore = score
		save_highscore()


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
