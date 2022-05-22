class_name NEATPopulation extends Reference


var size : int = 0
var genomes : Array = [] #NEATNN[]
var species_counter : int = 0
var gen : int = 0

var compatibility_threshold : int = 4

var connections_innovs : Dictionary = {} ##Dict<int[2], int>	{ [in0, out0] : innov0, ...}

#----------------------------------------------------------------------------------
# ** CONFIGS **
#----------------------------------------------------------------------------------
# MUTATION CONFIGS ---------------------------------------------------------
# tweak weight mutation
var MUTATION_WEIGHT_TWEAK_CHANCE = 0.8
#chance for each connection
var MUTATION_PER_WEIGHT_TWEAK_CHANCE = 0.5
#chance for a weight to be tuned instead of "reset"
var MUTATION_WEIGHT_PERTUB_CHANCE : float  = 0.95
#mutation amount
var MUTATION_WEIGHT_MUTATION_AMT = 2.5

#add connection mutation
var MUTATION_ADD_CONNECTION_CHANCE = 0.05
var MUTATION_ALLOW_RECURRENT_CONNECTIONS = false

#add node mutation
var MUTATION_ADD_NODE_CHANCE = 0.01

#toggle mutation
var MUTATION_CONNECTION_DISABLE_CHANCE = 0.02
var MUTATION_CONNECTION_ENABLE_CHANCE = 0.01


# SPECIATION CONFIGS ------------------------------------------------------
var SPECIATION_EXCESS_WEIGHT = 1.0
var SPECIATION_DISJOINT_WEIGHT = 1.0
var SPECIATION_WEIGHT_WEIGHT = 0.4 #weight weight haha
var SPECIATION_TARGET_SPECIES = 4
# % of genomes in each species that survive
var SPECIATION_SURVIVAL_RATE = 0.2
#var SPECIATION_INTERSPECIES_BREEDING_CHANCE = 0.001 #TODO
#var SPECIATION_BEST_GENOME_BREEDING_CHANCE = 0.002 #TODO
#how stale a species can be before it is "reset"
var SPECIATION_MAX_STALENESS = 20


signal gen_over


func _init(_size : int, init_permutations : int, nn_inputs : int, nn_outputs : int):
	size = _size
	genomes.resize(size)
	for i in range(size):
		genomes[i] = NEATNN.new(nn_inputs, nn_outputs)
		genomes[i].owner = self
#	speciate()





#get a connection's innovation id given its input and output nodes
# if the connection isn't in the innov list (ie its new), then add it
func get_connection_innov(in_node : int, out_node : int) -> int:
	var c = [in_node, out_node]
	var innov = connections_innovs.get(c, null)
	if innov == null:
		innov = connections_innovs.size()
		connections_innovs[c] = innov
	return innov



func get_species_color(sid : int) -> Color:
	return Color(
		fposmod(sid*0.17, 1.0),
		fposmod(sid*0.37 + 0.2, 1.0),
		fposmod(sid*0.216 + 0.7, 1.0)
	)
