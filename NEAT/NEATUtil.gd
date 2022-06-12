extends Node



func create_configfile() -> ConfigFile:
	var cf : ConfigFile = ConfigFile.new()
	
	cf.set_value('mutation', 'P_weight', 0.8)
	cf.set_value('mutation', 'P_per_weight', 0.5)
	cf.set_value('mutation', 'P_weight_pertub', 0.95)
	cf.set_value('mutation', 'weight_amt', 2.5)
	cf.set_value('mutation', 'P_connection', 0.05)
	cf.set_value('mutation', 'P_recurrent', 0.0)
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
# P1 IS EXPECTED TO BE MORE FIT THAN P2
# both parents' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort... good luck ;) )
func crossover(p1, p2):
	var offspring : NEATNN = NEATNN.new(p1.INPUT_COUNT,p1.OUTPUT_COUNT).copy(p1)
	
	if p1 == p2:
		return offspring
	
	for c2 in range(NEATNN.INDEX_CONNECTIONS, p2.genes.size(), NEATNN.C_LEN):
		var c2i : int = p2.get_c_innov(c2)
		
		#EXCESS GENES (skip the rest of the worse parent)
		if p1.get_connections_count()>0 and c2i > p1.get_c_innov(-3):
			break
		
		var co : int = offspring.get_connection(c2i)
		#DISJOINT GENES
		if co == -1:
			offspring.add_connection(p2.genes.slice(c2, c2+NEATNN.C_LEN))
			continue
		
		#MATCHING GENES
		if randf() < 0.5:
			#set weight to p2's weight
			offspring.genes[co+NEATNN.INDEX_WEIGHT] = p2.get_c_w(c2)
		
		#if one gene is disabled, the corresponding gene in the offspring will likely be disabled
		if !p2.is_c_enabled(c2) and randf() < 0.75:
			offspring.set_c_enabled(co, false)
	
	offspring.resize_nodes( max(p1.nodes.size(), p2.nodes.size()) )
#	var max_n : int = p1.INPUT_COUNT+p1.OUTPUT_COUNT
#	for c in range(NEATNN.INDEX_CONNECTIONS, offspring.genes.size(), NEATNN.C_LEN):
#		max_n = max(max_n, max(offspring.get_c_in(c), offspring.get_c_out(c)))
#	offspring.resize_nodes(max_n+1)
	return offspring



# Calculates how compatible / similar 2 genomes are
# both genomes' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort, call NEAT::sort_connections())
# d = (c1*E)/N  +  (c2*D)/N  +  c3*W
func calc_distance(n1 : NEATNN, n2 : NEATNN, EXCESS_WEIGHT : float, DISJOINT_WEIGHT : float, WEIGHT_WEIGHT : float) -> float:
	var E : int = 0
	var D : int = 0
	var W : float = 0.0
	var matching_genes_count : float = 0.0
	var C_LEN : int = NEATNN.C_LEN
	
	#loop both NNs' genes
	var i1 : int = NEATNN.INDEX_CONNECTIONS
	var i2 : int = NEATNN.INDEX_CONNECTIONS
	var n1_genes_size : int = n1.genes.size()
	var n2_genes_size : int = n2.genes.size()
	while (i1 < n1_genes_size) or (i2 < n2_genes_size):
		
#		EXCESS GENES
		if i1 == n1_genes_size or i2 == n2_genes_size:
			E += 1
			#increment the one with the excess genes
			i1 += int(i1 < n1_genes_size)*C_LEN
			i2 += int(i2 < n2_genes_size)*C_LEN
			continue
		
#		MATCHING GENES
		var i1_i : int = n1.get_c_innov(i1)
		var i2_i : int = n2.get_c_innov(i2)
		if i1_i == i2_i:
			W += abs(n1.get_c_w(i1) - n2.get_c_w(i2))
			matching_genes_count += 1.0
			i1 += C_LEN
			i2 += C_LEN
		
#		DISJOINT GENES
		else:
			D += 1
			#increment the smaller one
			i1 += int(i1_i < i2_i)*C_LEN
			i2 += int(i2_i < i1_i)*C_LEN
	
	
	#calc avg weight difference of matching genes
	W /= max(matching_genes_count, 1.0)
	
	var N : int = max(n1.nodes.size(), n2.nodes.size())
	return (EXCESS_WEIGHT*E/N) + (DISJOINT_WEIGHT*D/N) + (WEIGHT_WEIGHT*W)




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


