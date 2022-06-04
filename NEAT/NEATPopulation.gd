class_name NEATPopulation extends Reference


var base_size : int = 0
var base_genome : NEATNN

var size : int = 0
var genomes : Array = [] #NEATNN[]
var species_data : Dictionary = {} #Dict<int id, Dict data>
var species_counter : int = 0
var gen : int = 0

var NN_INPUTS : int
var NN_OUTPUTS : int

var compatibility_threshold : float = 4

var connections_innovs : Dictionary = {} ##Dict<int[2], int>	{ [in0, out0] : innov0, ...}
var configs : ConfigFile = ConfigFile.new()

signal gen_over


func _init(s : int, base_g : NEATNN, config_path : String):
	load_configs(config_path)
	
	NN_INPUTS = base_g.INPUT_COUNT
	NN_OUTPUTS = base_g.OUTPUT_COUNT
	base_size = s
	base_genome = base_g
	size = s
	
	for i in range(size):
		genomes.append(NEATNN.new(0,0).copy(base_genome))
		genomes[i].species_id = 0
		genomes[i].owner = self
	
	create_species(size)


#get a connection's innovation id given its input and output nodes
# if the connection isn't in the innov list (ie its new), then add it
func get_connection_innov(in_node : int, out_node : int) -> int:
	var c = PoolIntArray([in_node, out_node])
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
	#adjust compatibility threshold
	compatibility_threshold *= species_data.size() / float(configs.get_value('speciation', 'target_species'))
	
	#clear pop real quick
	for g in genomes:
		g.is_speciated = false
	
	var new_species_len : Dictionary = {} #Dict<int sid, int len>
	for i in range(genomes.size()):
		var specimen : NEATNN = genomes[i]
		if specimen.is_speciated:
			continue
		
		if specimen.species_id == -1:
			specimen.species_id = species_counter
			create_species(1)
		
		var sid : int = specimen.species_id
		new_species_len[sid] = 1
		for j in range(genomes.size()-1, i, -1):
			var g : NEATNN = genomes[j]
			if g.is_speciated:
				continue
			
			#COMPARE GENOMES
			if is_compatible(specimen, g):
				g.species_id = sid
				g.is_speciated = true
				new_species_len[sid] += 1
				continue
			
			#if same species but not compatible
			#set its id to "hmm not sure" and move it to the end
			if g.species_id == sid:
				g.species_id = -1
				genomes.remove(j)
				genomes.append(g)
		
		specimen.is_speciated = true
	genomes.sort_custom(self, '_compare_species')
	
	#remove empty species
	for k in species_data.keys():
		species_data[k].len = new_species_len.get(k, 0)
		if species_data[k].len <= 0:
			species_data.erase(k)



func reproduce():
	var survival_rate : float = configs.get_value('speciation', 'survival_rate')
	var max_staleness : int = configs.get_value('speciation', 'max_staleness')
	var avg_global_adj_fitness : float = 0.0
	#"Adjusted Fitness Sum" for each species
	var afs : Dictionary = {} #Dict<int sid, float sum>
	var pools : Dictionary = {}
	
	genomes.sort_custom(self, '_compare_genomes')
	
	#ADJUST FITNESS
	for g in genomes:
		var sid : int = g.species_id
		var af : float = g.fitness / float(species_data[sid].len) #adjusted fitness
		afs[sid] = afs.get(sid, 0.0) + af
		avg_global_adj_fitness += af
		
		#create pool while we're at it
		if !pools.has(sid):
			pools[sid] = MatingPool.new()
		if pools[sid].data.size() < ceil(species_data[sid].len * survival_rate):
			pools[sid].add(g)
	avg_global_adj_fitness /= float(size)
	
	
	#CREATE OFFSPRINGS
	var new_genomes : Array = []
	var gi : int = 0
	for sid in species_data.keys():
		var sd : Dictionary = species_data[sid]
		var best_boi : NEATNN = genomes[gi]
		
		if best_boi.fitness > sd.best:
			sd.best = best_boi.fitness
			sd.age = 0
		else:
			sd.age += 1
		
		#	(avg_adjusted_fitness / avg_global_adjused_fitness) * N
		#	( (afs[sid] / N)      / avg_global_adj_fitness ) * N
		#Ns cancel out:		afs[sid] / avg_global_adj_fitness
		var allowed_genomes : int = round(afs[sid] / avg_global_adj_fitness)
		if sd.age > max_staleness:
			allowed_genomes = 0
		
		_reproduce_species(sid, allowed_genomes, pools, new_genomes)
		
		gi += sd.len
		sd.len = allowed_genomes
	
	genomes = new_genomes
	size = genomes.size()
	print('new population size: %s' % size)
	speciate()


#pool : pool of ALL species
func _reproduce_species(sid : int, count : int, pools : Dictionary, new_genomes : Array):
	if count == 0:
		if species_data.size() == 1: #if last species, reset
			print('%s --- POPULATION FAILED. Resetting...' % [self])
			reset(new_genomes)
		return

	var pool : MatingPool = pools[sid]
	
	var do_elitism : bool = configs.get_value('speciation', 'elitism')
	var P_interspecies_breeding : float = configs.get_value('speciation', 'P_interspecies_breeding')
	if do_elitism:
		#pool.data.keys()[0] = best genome in this species.
		# its index 0 bc genomes have been sorted in reproduce()
		new_genomes.append(NEATNN.new(NN_INPUTS, NN_OUTPUTS).copy(pool.data.keys()[0]))
	
	for _i in range(count - int(do_elitism)):
		var p1 : NEATNN = pool.pick()
		var p2 : NEATNN = pool.pick()
		
		#CROSS SPECIES BREEDING
		if randf() < P_interspecies_breeding:
			var rsp : int = species_data.keys()[randi()%species_data.size()]
			p2 = pools[ rsp ].pick()
		
		var child : NEATNN = NeatUtil.crossover(p2, p1) if p2.fitness > p1.fitness else NeatUtil.crossover(p1, p2)
		child.owner = self
		mutate(child)
		new_genomes.append(child)


func reset(arr : Array):
	arr.clear()
	species_counter = 0
	gen = 0
	create_species(base_size)
	for i in range(base_size):
		var g : NEATNN = NEATNN.new(0,0).copy(base_genome)
		mutate(g)
		g.species_id = 0
		g.owner = self
		arr.append(g)



#returns whether 2 genomes are compatible (ie same species)
func is_compatible(n1 : NEATNN, n2 : NEATNN) -> bool:
	return NeatUtil.calc_distance(
		n1, n2,
		configs.get_value('speciation', 'excess_weight'),
		configs.get_value('speciation', 'disjoint_weight'),
		configs.get_value('speciation', 'weight_weight')) < compatibility_threshold


func mutate(nn : NEATNN):
	nn.mutate(configs)


func gen_over():
	gen += 1
	emit_signal("gen_over")
	reproduce()


class MatingPool:
	var data : Dictionary = {}
	var t : float = 0.0
	
	func add(k : NEATNN):
		data[k] = k.fitness
		t += k.fitness
	
	func pick() -> NEATNN:
		var v : float = randf()*t
		for k in data.keys():
			if v <= data[k]:
				return k
			v -= data[k]
		return data.keys()[0] #just in case



func _compare_genomes(a, b):
	if a.species_id != b.species_id:
		return a.species_id < b.species_id
	return a.fitness > b.fitness

func _compare_species(a, b):
	return a.species_id < b.species_id


# UTIL ----------------------------------------------------------------------
func add_genome() -> NEATNN:
	var g : NEATNN = NEATNN.new(NN_INPUTS, NN_OUTPUTS)
	genomes.append(g)
	g.species_id = 0 if genomes.empty() else genomes[0].species_id
	g.owner = self
	size += 1
	return g

func size() -> int:
	return size

func is_empty() -> bool:
	return size==0


func print_data():
	print(self, '================')
	print(' Gen %s\n SPECIES (len=%s):' % [gen, species_data.size()])
	for k in species_data.keys():
		var sd : Dictionary = species_data[k]
		print('  [%s]\t len=%s\tage=%s\tbest=%s' % [k, sd.len, sd.age, sd.best])



# CONFIGS
func set_config(section : String, key : String, value): #-> NEATPopulation
	configs.set_value(section, key, value)
	return self

func get_config(section : String, key : String, _default=null):
	return configs.get_value(section, key, _default)

func save_configs(path : String):
	configs.save(path)

func load_configs(path : String):
	var err : int = configs.load(path)
	if err != OK:
		configs = NeatUtil.create_configfile()
		save_configs(path)
		printerr('Config file %s did not exist, please set it up and restart the program' % path)
