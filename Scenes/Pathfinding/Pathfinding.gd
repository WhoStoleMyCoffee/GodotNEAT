extends Node2D


const CONFIGPATH : String = 'res://Scenes/Pathfinding/configs.cfg'
const SAVEPATH : String = 'res://Scenes/Pathfinding/nn.json'
const AGENT = preload("res://Scenes/Pathfinding/Agent.tscn")

const RUN_TIME : float = 2.0

onready var Displayer = $CanvasLayer/UI/NEATDisplayer

var pop : NEATPopulation
var di : int = 0


func _ready():
	randomize()
	
	yield(get_tree(), "idle_frame")
	
	var bg : NEATNN = NEATNN.new(7, 4)
	pop = NEATPopulation.new(20, bg, CONFIGPATH)
	
	for g in pop.genomes:
		for _i in range(20):
			pop.mutate(g)
	pop.speciate()
	next_genome()
	
	$Timer.start(RUN_TIME)


func next_genome():
	update_info()
	
	$Agent.reset()
	$Agent.set_brain(pop.get_genome(di))
	Displayer.set_drawing_nn(pop.get_genome(di))
	di += 1


func _on_Timer_timeout():
	if di < pop.size():
		next_genome()
		return
	
	$Agent.evaluate()
	
	pop.gen_over()
	pop.print_data()
	
	di = 0
	next_genome()


func update_info():
	$CanvasLayer/UI/Info.bbcode_text = 'Gen %s  genome %s\n Species %s' % [pop.gen, di, pop.get_genome(di).species_id]
