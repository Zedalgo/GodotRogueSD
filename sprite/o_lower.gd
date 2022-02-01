extends Sprite

var item_name = "shield"
var is_magic:bool = false


func determine_if_magic(percent_chance):
	var i = rand_range(1, 100)
	if i <= percent_chance:
		is_magic = true
	else:
		is_magic = false
