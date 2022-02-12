extends Node

var alive:bool
var energy_current:int
var energy_max:int = 10
var entity_name:String
var health_current:int
var health_max:int
var damage:int
var move_type:String
var walkable:bool

##Tags will be string labels that define traits. ex: "Machine", "Flying", "Organic"
var tags:Array = []
