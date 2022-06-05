extends KinematicBody2D


const TARGET_COUNT : int = 4
const TARGET_RADIUS : float = 32.0
const RAYS_COUNT : int = 4
const VIEWDIST = 512.0

const TARGET_WEIGHT : float = 500.0
const DIST_WEIGHT : float = 0.2
const COMPLETED_WEIGHT : float = 1000.0

const spd : float = 100.0
const friction : float = 0.9
const refresh_rate : float = 0.1

var current_target : Position2D
var targets_hit : int = 0
var completed : bool = false
var brain : NEATNN
var tt : float = 0.0
"""
inputs: rays(4) + dir to target(2) + bias -> 7
outputs: left force, right, up, down -> 4
"""


var vel : Vector2 = Vector2(0, 0)


func _ready():
	yield(get_tree(), "idle_frame")
	reset()
	
	#setup rays
	if RAYS_COUNT == 0: return
	var astep : float = PI*2.0/RAYS_COUNT
	for i in range(RAYS_COUNT):
		var r : RayCast2D = RayCast2D.new()
		r.enabled = true
		r.cast_to = Vector2(cos(astep*i), sin(astep*i))*VIEWDIST
		$Rays.add_child(r)


func set_brain(nn : NEATNN):
	brain = nn
	brain.fitness = 0.0
	modulate = brain.get_color()


func reset():
	position = Vector2(512.0, 300.0)
	tt = 0.0
	current_target = get_node('../Targets/t0')


func _process(delta):
	if completed or current_target == null:
		return
	
	
	vel = move_and_slide(vel) * friction
	if position.distance_squared_to(current_target.position) < TARGET_RADIUS*TARGET_RADIUS:
		if targets_hit == TARGET_COUNT-1:
			completed = true
			return

		targets_hit += 1
		current_target = get_node('../../Targets/t%s' % targets_hit)
	
	
	tt += delta
	if tt < refresh_rate:
		return
	tt = 0.0
	
	think()


func think():
	var X : Array = get_inputs()
	var y : Array = brain.feed_forward(X)
	
	var m : float = y.max()
	if m == y[0]:	vel += Vector2.LEFT*spd
	elif m == y[1]:	vel += Vector2.RIGHT*spd
	elif m == y[2]:	vel += Vector2.UP*spd
	elif m == y[3]:	vel += Vector2.DOWN*spd


func evaluate():
	pass
	brain.fitness = (1024.0-position.distance_to(current_target.position))*DIST_WEIGHT\
		+ targets_hit*TARGET_WEIGHT\
		+ int(completed)*COMPLETED_WEIGHT


func get_inputs() -> Array:
	var dir : Vector2 = position.direction_to(current_target.position)
	var X : Array = [
		1.0, #bias
		dir.x*0.5 + 0.5,
		dir.y*0.5 + 0.5
	]
	
	for i in range(RAYS_COUNT):
		var r : RayCast2D = $Rays.get_child(i)
		var v : float = position.distance_to(r.get_collision_point())/VIEWDIST if r.is_colliding() else 1.0
		X.append(v)
	
	return X
