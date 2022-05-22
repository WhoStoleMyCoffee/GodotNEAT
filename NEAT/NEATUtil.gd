extends Node



# CROSSOVER ---------------------------------------------------------------
#https://github.com/F3R70/NEAT/blob/master/src/genome.cpp#L2085 onwards
# p1 is expected to be more fit than p2
# both parents' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort, call NEAT::sort_connections())
#oh boy i cant wait for lambdas.
func crossover(p1 : NEATNN, p2 : NEATNN) -> NEATNN:
	var offspring : NEATNN = NEATNN.new(p1.INPUT_COUNT, p1.OUTPUT_COUNT)
	var biggest_node_id : int = 0
	
	#loop both parents' genes
	var i1 : int = 0
	var i2 : int = 0
	var p1_genes_size : int = p1.connections.size()
	var p2_genes_size : int = p2.connections.size()
	while (i1 < p1_genes_size) or (i2 < p2_genes_size):
		
#		EXCESS GENES (skip the rest of the worse parent)
		if i1 == p1_genes_size:
			break
		
		var chosengene : Dictionary
		
		#P1 "EXCESS", just add the rest of p1
		if i2 == p2_genes_size:
			chosengene = p1.connections[i1].duplicate()
			#ADD GENE TO OFFSPRING
			if !offspring.has_connection(chosengene.i):
				offspring.add_connection(chosengene)
				biggest_node_id = max(biggest_node_id, max(chosengene.in, chosengene.out))
			i1 += 1
			continue
		
		var c1 : Dictionary = p1.connections[i1]
		var c2 : Dictionary = p2.connections[i2]
		
#		MATCHING GENES
		if c1.i == c2.i:
			#choose gene randomly from parents
			chosengene = c2.duplicate() if randf() < 0.5 else c1.duplicate()
			
			#if one gene is disabled, the corresponding gene in the offspring will likely be disabled
			if !c1.e or !c2.e:
				if randf() < 0.75:
					chosengene.e = false
			
			i1 += 1
			i2 += 1
		
#		DISJOINT GENES
		else:
			#choose gene from smallest innov
			chosengene = c1.duplicate() if c1.i < c2.i else c2.duplicate()
			#increment the smaller one
			i1 += int(c1.i < c2.i)
			i2 += int(c2.i < c1.i)
		
#		ADD GENE TO OFFSPRING
		if !offspring.has_connection(chosengene.i):
			offspring.add_connection(chosengene)
			biggest_node_id = max(biggest_node_id, max(chosengene.in, chosengene.out))
	
	#add new hidden nodes
	# biggest_node_id is essentially the index of the last hidden node.
	#  So, we just need to have that many nodes in total in the end
	#  Input and output nodes have already been added on  offspring::_init()
	for _i in range(biggest_node_id - p1.INPUT_COUNT+1-p1.OUTPUT_COUNT):
		offspring.nodes.append(0.0)
	
	return offspring



# Calculates how compatible / similar 2 genomes are
# both genomes' genes are expected to be already sorted.
#	(genes are automatically sorted when adding a connection. to manually sort, call NEAT::sort_connections())
# d = (c1*E)/N  +  (c2*D)/N  +  c3*W
func calc_distance(n1 : NEATNN, n2 : NEATNN, EXCESS_WEIGHT : float, DISJOINT_WEIGHT : float, WEIGHT_WEIGHT : float) -> float:
	var N : int = max(n1.nodes.size(), n2.nodes.size())
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
	W /= max(float(matching_genes_count), 0.0)
	
	return (EXCESS_WEIGHT * E / N) + (DISJOINT_WEIGHT * D / N) + (WEIGHT_WEIGHT * W)


#returns whether 2 genomes are compatible (ie same species)
func is_compatible(n1 : NEATNN, n2 : NEATNN, EXCESS_WEIGHT : float, DISJOINT_WEIGHT : float, WEIGHT_WEIGHT : float, threshold : int) -> bool:
	return calc_distance(n1, n2, EXCESS_WEIGHT, DISJOINT_WEIGHT, WEIGHT_WEIGHT)<threshold
