extends Node


func search_for_matching_subarray(look_through:Array, thing_to_match:Array) -> bool:
	var match_found:bool = false
	for i in range(look_through.size()):
		if look_through[i] == thing_to_match:
			match_found = true
	return match_found
