extends Node

var alive:bool
var energy_current:int
var energy_max:int = 10
var entity_name:String
var health_current:int
var health_max:int
var damage:int
var move_type:String
var ranged_attack_cost:int
var ranged_damage:int
var score:int
var seen_by_player:bool = false # Might be unused
var view_range:int
var walkable:bool

##Tags will be string labels that define traits. ex: "Machine", "Flying", "Meat"
var tags:Array = []
