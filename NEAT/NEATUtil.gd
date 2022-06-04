extends Node



func create_configfile() -> ConfigFile:
	var cf : ConfigFile = ConfigFile.new()
	
	cf.set_value('mutation', 'P_weight', 0.8)
	cf.set_value('mutation', 'P_per_weight', 0.5)
	cf.set_value('mutation', 'P_weight_pertub', 0.95)
	cf.set_value('mutation', 'weight_amt', 2.5)
	cf.set_value('mutation', 'P_connection', 0.05)
	cf.set_value('mutation', 'allow_recurrent', true)
	cf.set_value('mutation', 'P_node', 0.01)
	cf.set_value('mutation', 'P_enable', 0.01)
	cf.set_value('mutation', 'P_disable', 0.01)
	
	cf.set_value('speciation', 'excess_weight', 1.0)
	cf.set_value('speciation', 'disjoint_weight', 1.0)
	cf.set_value('speciation', 'weight_weight', 0.4)
	cf.set_value('speciation', 'target_species', 10)
	cf.set_value('speciation', 'survival_rate', 0.4)
	cf.set_value('speciation', 'P_interspecies_breeding', 0.001)
	cf.set_value('speciation', 'elitism', true)
	cf.set_value('speciation', 'max_staleness', 20)
	
	return cf


# CROSSOVER ---------------------------------------------------------------
#https://github.com/F3R70/NEAT/blob/master/src/genome.cpp#L2085 onwards
# p1 is expected to be more fit than p2
# both parents' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort, call NEAT::sort_connections())
#oh boy i cant wait for lambdas.
func crossover(p1 : NEATNN, p2 : NEATNN) -> NEATNN:
	var offspring : NEATNN = NEATNN.new(0,0).copy(p1)
	
	var p1genes : Array = p1.connections
	var p2genes : Array = p2.connections
	for i in range(p2genes.size()):
		var c2 : Dictionary = p2genes[i] # <- connection/gene
		
		#EXCESS GENES (skip the rest of the worse parent)
		if !p1genes.empty() and c2.i > p1genes[-1].i:
			break
		
		var co = offspring.get_connection(c2.i)
		#DISJOINT GENES
		if co == null:
			offspring.add_connection(c2.duplicate(true))
			continue
		
		#MATCHING GENES
		if randf() < 0.5:
			#set weight to p2's weight
			co.w = c2.w
		
		#if one gene is disabled, the corresponding gene in the offspring will likely be disabled
		if !c2.e and randf() < 0.75:
			co.e = false
		
	
	offspring.nodes.resize( max(p1.nodes.size(), p2.nodes.size()) )
	offspring.species_id = p1.species_id if p1.fitness > p2.fitness else p2.species_id
	return offspring



# Calculates how compatible / similar 2 genomes are
# both genomes' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort, call NEAT::sort_connections())
# d = (c1*E)/N  +  (c2*D)/N  +  c3*W
func calc_distance(n1 : NEATNN, n2 : NEATNN, EXCESS_WEIGHT : float, DISJOINT_WEIGHT : float, WEIGHT_WEIGHT : float) -> float:
	var E : int = 0
	var D : int = 0
	var W : float = 0.0
	var matching_genes_count : int = 0
	
	
	#loop both NNs' genes
	var i1 : int = 0
	var i2 : int = 0
	var n1_genes_size : int = n1.connections.size()
	var n2_genes_size : int = n2.connections.size()
	while (i1 < n1_genes_size) or (i2 < n2_genes_size):
		
#		EXCESS GENES
		if i1 == n1_genes_size or i2 == n2_genes_size:
			E += 1
			#increment the one with the excess genes
			i1 += int(i1 < n1_genes_size)
			i2 += int(i2 < n2_genes_size)
			continue
		
		var c1 : Dictionary = n1.connections[i1]
		var c2 : Dictionary = n2.connections[i2]
		
#		MATCHING GENES
		if c1.i == c2.i:
			W += abs(c1.w - c2.w)
			matching_genes_count += 1
			i1 += 1
			i2 += 1
		
#		DISJOINT GENES
		else:
			D += 1
			#increment the smaller one
			i1 += int(c1.i < c2.i)
			i2 += int(c2.i < c1.i)
	
	
	#calc avg weight difference of matching genes
	W /= max(float(matching_genes_count), 1.0)
	
	var N : int = max(n1.nodes.size(), n2.nodes.size())
	return (EXCESS_WEIGHT * E / N) + (DISJOINT_WEIGHT * D / N) + (WEIGHT_WEIGHT * W)




#hmm, currently re-doing neatpopulation::reproduce...
#pool : Dict<NEATNN genome, float weight>	with {'t' : float}
#total : total of all weights
func pick_from_pool(pool : Dictionary) -> NEATNN:
	var total : float = pool.t
	pool.erase('t')
	var v : float = randf() * total
	
	for k in pool.keys():
		if v <= pool[k]:
			pool['t'] = total
			return k
		v -= pool[k]
	return pool.keys()[1] #just in case


func compress_connection(c : Dictionary) -> Array:
	var a : int = c.i * (int(c.e)-int(!c.e)) #c.i if enabled, -c.i if disabled
	var b : int = ((c.n[0] & 0xFFFF) << 16) | (c.n[1] & 0xFFFF)
	var w : float = c.w
	return [a, b, w]


func uncompress_connection(a : int, b : int, c : float) -> Dictionary:
	return {
		'i' : abs(a),
		'n' : PoolIntArray([b >> 16, b & 0xFFFF]),
		'w' : c,
		'e' : (a >= 0)
	}
