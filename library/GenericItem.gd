extends Node2D

var item_name:String
# Variables for recreating the item if dropped
var image_scene:PackedScene
var image_color:Color

# Variables for health/energy restoration/increase
var energy:int
var health:int

# Tags in use: [Increase, Restore]
# Tags I'd like to use [GradualRestore]
var item_tags:Array = []
