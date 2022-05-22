class_name NEATPopulation extends Reference


var size : int = 0
var genomes : Array = [] #NEATNN[]
var species_len : Dictionary = {} #Dict<int id, int count> how many members each species has
var species_counter : int = 0
var gen : int = 0

var NN_INPUTS : int
var NN_OUTPUTS : int

var compatibility_threshold : int = 4

var connections_innovs : Dictionary = {} ##Dict<int[2], int>	{ [in0, out0] : innov0, ...}

#----------------------------------------------------------------------------------
# ** CONFIGS **
#----------------------------------------------------------------------------------
var ALLOW_RECURRENT_CONNECTIONS : bool = false

# MUTATION CONFIGS ---------------------------------------------------------
var MUTATION_WEIGHT_TWEAK_CHANCE : float = 0.8	#tweak weight mutation
var MUTATION_PER_WEIGHT_TWEAK_CHANCE : float = 0.5	#chance for each connection
var MUTATION_WEIGHT_PERTUB_CHANCE : float  = 0.95	#chance for a weight to be tuned instead of "reset"
var MUTATION_WEIGHT_AMT : float = 2.5	#mutation amount

#add connection mutation
var MUTATION_ADD_CONNECTION_CHANCE : float = 0.05

#add node mutation
var MUTATION_ADD_NODE_CHANCE : float = 0.01

#toggle mutation
var MUTATION_CONNECTION_DISABLE_CHANCE : float = 0.02
var MUTATION_CONNECTION_ENABLE_CHANCE : float = 0.01


# SPECIATION CONFIGS ------------------------------------------------------
var SPECIATION_EXCESS_WEIGHT : float = 1.0
var SPECIATION_DISJOINT_WEIGHT : float = 1.0
var SPECIATION_WEIGHT_WEIGHT : float = 0.4 #weight weight haha
var TARGET_SPECIES : int = 4
# % of genomes in each species that survive
var SPECIATION_SURVIVAL_RATE : float = 0.2
#var SPECIATION_INTERSPECIES_BREEDING_CHANCE = 0.001 #TODO
#var SPECIATION_BEST_GENOME_BREEDING_CHANCE = 0.002 #TODO
#how stale a species can be before it is "reset"
var SPECIATION_MAX_STALENESS : int = 20


signal gen_over


func _init(_size : int, init_permutations : int, nn_inputs : int, nn_outputs : int):
	NN_INPUTS = nn_inputs
	NN_OUTPUTS = nn_outputs
	
	size = _size
	genomes.resize(size)
	for i in range(size):
		genomes[i] = NEATNN.new(NN_INPUTS, NN_OUTPUTS)
		genomes[i].owner = self
		
		for _j in range(init_permutations):
			mutate(genomes[i])
	
	species_len[0] = size
	compatibility_threshold *= 1 / float(TARGET_SPECIES)
	speciate()
	
	for g in genomes:
		print(g.species_id)



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


func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Dictionary:
	return {
		'i' : get_connection_innov(_in, _out),
		'in' : _in,
		'out' : _out,
		'w' : _w,
		'e' : _enabled
	}


func speciate():
	var new_genomes : Array = [] #new speciated population
	
	while !genomes.empty():
		var sid : int = genomes[0].species_id
		var specimen : NEATNN = genomes[randi() % species_len[sid]]
		species_len[sid] = 1
		
		#foreach un-speciated genome (backwards)
		for i in range(genomes.size()-1, -1, -1):
			var g : NEATNN = genomes[i]
			if g == specimen: continue
			
			#if compatible
			if is_compatible(specimen, g):
				species_len[sid] += 1
				g.species_id = specimen.species_id
				new_genomes.append(g)
				genomes.remove(i) #TODO swap with last genome before removing bc performance is ouchie
				continue
			
			#if same species but not compatible
			if g.species_id == specimen.species_id:
				g.species_id += 1
				if !species_len.has(g.species_id):
					species_len[g.species_id] = 1
		
		new_genomes.append(specimen)
		genomes.erase(specimen)
	
	genomes = new_genomes
	
	
	#remove empty species
	for k in species_len.keys():
		if species_len[k] <= 0:
			species_len.erase(k)
	
	#adjust compatibility threshold
	compatibility_threshold *= species_len.size() / float(TARGET_SPECIES)


#returns whether 2 genomes are compatible (ie same species)
func is_compatible(n1 : NEATNN, n2 : NEATNN) -> bool:
	return NeatUtil.calc_distance(
		n1, n2,
		SPECIATION_EXCESS_WEIGHT,
		SPECIATION_DISJOINT_WEIGHT,
		SPECIATION_WEIGHT_WEIGHT) < compatibility_threshold


func mutate(nn : NEATNN):
	if randf() < MUTATION_WEIGHT_TWEAK_CHANCE:
		nn.mutate_weights(MUTATION_PER_WEIGHT_TWEAK_CHANCE, MUTATION_WEIGHT_PERTUB_CHANCE, MUTATION_WEIGHT_AMT)
	if randf() < MUTATION_ADD_CONNECTION_CHANCE:
		nn.mutate_add_connection(ALLOW_RECURRENT_CONNECTIONS)
	if randf() < MUTATION_ADD_NODE_CHANCE:
		nn.mutate_add_node()
	if randf() < MUTATION_CONNECTION_ENABLE_CHANCE:
		nn.mutate_enabled(true)
	if randf() < MUTATION_CONNECTION_DISABLE_CHANCE:
		nn.mutate_enabled(false)
