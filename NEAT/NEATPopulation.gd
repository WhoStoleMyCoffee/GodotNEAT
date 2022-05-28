class_name NEATPopulation extends Reference


var genomes : Array = [] #NEATNN[]
var species_data : Dictionary = {} #Dict<int id, Dict data>
var species_counter : int = 0
var gen : int = 0

var NN_INPUTS : int
var NN_OUTPUTS : int

var compatibility_threshold : float = 4

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
var SPECIATION_SURVIVAL_RATE : float = 0.4
#var SPECIATION_INTERSPECIES_BREEDING_CHANCE = 0.001 #TODO
#var SPECIATION_BEST_GENOME_BREEDING_CHANCE = 0.002 #TODO
#how stale a species can be before it is "reset"
var SPECIATION_MAX_STALENESS : int = 20


signal gen_over


func init(size : int, init_permutations : int, nn_inputs : int, nn_outputs : int):
	NN_INPUTS = nn_inputs
	NN_OUTPUTS = nn_outputs
	
	genomes.resize(size)
	for i in range(size):
		genomes[i] = NEATNN.new(NN_INPUTS, NN_OUTPUTS)
		genomes[i].owner = self
		
		for _j in range(init_permutations):
			mutate(genomes[i])
	
	create_species(size)
	compatibility_threshold *= 1 / float(TARGET_SPECIES)
	speciate()



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


#unused?
func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Dictionary:
	return {
		'i' : get_connection_innov(_in, _out),
		'n' : PoolIntArray([_in, _out]),
		'w' : _w,
		'e' : _enabled
	}


func create_species(length : int) -> Dictionary:
	var s : Dictionary = {
		'len' : length, #how many memeber there are
		'age' : 0, #staleness
		'best' : 0.0 #best fitness ever
	}
	species_data[species_counter] = s
	species_counter += 1
	
	return s


func reset_fitness():
	for g in genomes:
		g.fitness = 0.0


func speciate():
	var new_genomes : Array = [] #new speciated population
	
	while !genomes.empty():
		var sid : int = genomes[0].species_id
		if sid == -1: #if new species (aka "hmm not sure")
			sid = species_counter
			genomes[0].species_id = sid
			create_species(1)
		
		var specimen : NEATNN = genomes[randi() % species_data[sid].len]
		species_data[sid].len = 1
		
		#foreach un-speciated genome (backwards)
		for i in range(genomes.size()-1, -1, -1):
			var g : NEATNN = genomes[i]
			if g == specimen: continue
			
			#if compatible
			if is_compatible(specimen, g):
				species_data[sid].len += 1
				
				if g.species_id != specimen.species_id:
					if species_data.has(g.species_id):
						species_data[g.species_id].len -= 1
					g.species_id = specimen.species_id
				
				genomes.remove(i) #TODO swap with last genome before removing bc performance is ouchie
				new_genomes.append(g)
				continue
			
			#if same species but not compatible
			if g.species_id == specimen.species_id:
				#set species_id to "hmm not sure" and move it to the end
				g.species_id = -1
				genomes.remove(i)
				genomes.append(g)
		
		new_genomes.append(specimen)
		genomes.erase(specimen)
	
	genomes = new_genomes
	
	
	#remove empty species
	for k in species_data.keys():
		if species_data[k].len <= 0:
			species_data.erase(k)
	
	#adjust compatibility threshold
	compatibility_threshold *= species_data.size() / float(TARGET_SPECIES)


#TODO species aging (staleness) + remove stale species
func reproduce():
	var avg_global_adj_fitness : float = 0.0
	#"Adjusted Fitness Sum" for each species
	var afs : Dictionary = {} #Dict<int sid, float sum>
	var pool : Dictionary = {} #Dict<int sid, Dict<NEATNN genome, float weight>>
	
	genomes.sort_custom(self, '_compare_genomes')
	
#	ADJUST FITNESS (& other stuff too)
	for g in genomes:
		#adjusted fitness shinanigans
		var af : float = g.fitness / float(species_data[g.species_id].len) #genome's adjusted fitness
		afs[g.species_id] = afs.get(g.species_id, 0.0) + af
		avg_global_adj_fitness += af
		
		#while we're at it, create pool
		if !pool.has(g.species_id):
			pool[g.species_id] = { 't' : 0.0 } #t : total of all weights
		if pool[g.species_id].size()-1 < ceil(species_data[g.species_id].len * SPECIATION_SURVIVAL_RATE):
			pool[g.species_id][g] = g.fitness
			pool[g.species_id].t += g.fitness
	
	avg_global_adj_fitness /= float(genomes.size())
	genomes.clear()
	
	
#	CREATE OFFSPRINGS
	for sid in species_data.keys():
		var best_boi : NEATNN = pool[sid].keys()[1]
		if best_boi.fitness > species_data[sid].best:
			species_data[sid].best = best_boi.fitness
		else:
			species_data[sid].age += 1
			if species_data[sid].age > SPECIATION_MAX_STALENESS:
				continue
		
		#	(avg_adjusted_fitness / avg_global_adjused_fitness) * N
		#	( (afs[sid] / N)      / avg_global_adj_fitness ) * N
		#Ns cancel out:		afs[sid] / avg_global_adj_fitness
		var allowed_genomes : int = round(afs[sid] / avg_global_adj_fitness)
		
		reproduce_species(sid, allowed_genomes, pool)
	
	print('new population size: %s' % genomes.size())
	speciate()


#pool : pool of ALL species
func reproduce_species(sid : int, count : int, pool : Dictionary):
	print('    reproducing species. sid=%s count=%s' % [sid, count])
	species_data[sid].len = 0
	for _i in range(count):
		var p1 : NEATNN = NeatUtil.pick_from_pool(pool[sid])
		var p2 : NEATNN = NeatUtil.pick_from_pool(pool[sid])
		
		#TODO cross-species breeding
		# ...
		
		var child : NEATNN = NeatUtil.crossover(p2, p1) if p2.fitness > p1.fitness else NeatUtil.crossover(p1, p2)
		child.owner = self
		mutate(child)
		genomes.append(child)
		species_data[sid].len += 1


func _compare_genomes(a, b):
	if a.species_id != b.species_id:
		return a.species_id < b.species_id
	return a.fitness > b.fitness
	


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
