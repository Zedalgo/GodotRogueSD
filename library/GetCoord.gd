extends Node

var x_offset:int = 8
var y_offset:int = 12
var char_x:int = 16
var char_y:int = 24


func vector_to_index(vx, vy) -> Vector2:
	var index_x:int = round((vx - x_offset) / char_x)
	var index_y:int = round((vy - y_offset) / char_y)
	return Vector2(index_x, index_y)


func index_to_vector(ix, iy) -> Vector2:
	var vector_x:int = (ix * char_x) + x_offset
	var vector_y:int = (iy * char_y) + y_offset
	return Vector2(vector_x, vector_y)
