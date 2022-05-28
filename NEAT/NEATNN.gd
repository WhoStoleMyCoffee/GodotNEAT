class_name NEATNN extends Reference


var connections : Array = [] #Dict[]
var nodes : PoolRealArray = PoolRealArray()

var fitness : float = 0.0
var species_id : int = 0
var owner #: NEATPopulation #CYCLIC DEPENDENCIES AAAAAAAAH JUAN PLS FIX

var INPUT_COUNT : int
var OUTPUT_COUNT : int



func _init(input_count : int, output_count : int) -> void:
	INPUT_COUNT = input_count
	OUTPUT_COUNT = output_count
	
	nodes.resize(INPUT_COUNT + OUTPUT_COUNT)


func feed_forward(X : Array) -> Array:
	var y : Array = []
	var new_nodes : PoolRealArray = PoolRealArray()
	new_nodes.resize(nodes.size())
	y.resize(OUTPUT_COUNT)
	
	#set inputs
	for i in range(INPUT_COUNT):
		var x : float = float(X[i])
		
		#recurrent connections
		for c in connections:
			if c.n[1] != i or !c.e: continue
			x += nodes[c.n[0]]*c.w
		nodes[i] = activation_func(x) #TODO this needs to be activated, right????
	
	#the rest
	for c in connections:
		if is_node_input(c.n[1]) or !c.e: continue #skip if recurrent (or not enabled)
		new_nodes[c.n[1]] += nodes[c.n[0]]*c.w
	
	#activate and apply
	for i in range(nodes.size()):
		nodes[i] = activation_func( new_nodes[i] )
		if is_node_output(i):
			y[i-INPUT_COUNT] = nodes[i]
	
	return y


func add_connection(c : Dictionary) -> void:
	nodes.resize(max(nodes.size(), max(c.n[0], c.n[1])+1))
	var i : int = connections.bsearch_custom(c.i, self, "_compare_connections", true)
	connections.insert(i, c)


func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Dictionary:
	return {
		'i' : owner.get_connection_innov(_in, _out) if owner else connections.size(),
		'n' : PoolIntArray([_in, _out]),
		'w' : _w,
		'e' : _enabled
	}


func activation_func(x : float):
	return 1/(1+exp(-4*x))


func is_node_input(i : int) -> bool:
	return i<INPUT_COUNT

func is_node_output(i : int) -> bool:
	return i>=INPUT_COUNT and i<INPUT_COUNT+OUTPUT_COUNT


func set_connection_enabled(i : int, v : bool):
	connections[i].e = v


func print_data():
	print(self, ' ----------')
	print('%s nodes' % nodes.size())
	print('CONNECTIONS:')
	for c in connections:
		var s : String = '(%s) [%s -> %s]' % [c.i, c.n[0], c.n[1]]
		
		if !c.e:
			s += ' DISABLED'
		
		print(s)


func _compare_connections(a, b) -> bool:
	return a.i < b

func get_connection(innov : int):
	var i : int = connections.bsearch_custom(innov, self, "_compare_connections", true)
	return connections[i] if i < connections.size() and connections[i].i == innov else null

func has_connection(innov : int) -> bool:
	var i : int = connections.bsearch_custom(innov, self, "_compare_connections", true)
	return i < connections.size()


func get_biggest_innov() -> int:
	var result : int = 0
	for c in connections:
		result = max(result, c.i)
	return result


func copy(nn):
	INPUT_COUNT = nn.INPUT_COUNT
	OUTPUT_COUNT = nn.OUTPUT_COUNT
	
	nodes.empty()
	nodes.resize(nn.nodes.size())
	connections = nn.connections.duplicate(true)
	fitness = nn.fitness
	species_id = nn.species_id
	return self

""" Unused?
func sort_connections():
	connections.sort_custom(self, '_connection_sort_func')

#oh boy i cant wait for lambdas
func _connection_sort_func(a, b):
	return a.i < b.i
"""

func get_color() -> Color:
	return owner.get_species_color(species_id) if owner else Color.white



# MUTATION --------------------------------------------------------------------
func mutate_weights(per_weight_chance : float, pertub_chance : float, amt : float):
	for c in connections:
		if randf() > per_weight_chance: continue
		c.w = c.w+rand_range(-1,1)*amt if randf() < pertub_chance else rand_range(-2,2)


#add a connection going from in_node to out_node
func mutate_add_connection(allow_recurrent : bool):
	var in_node : int = randi() % nodes.size()
	var out_node : int = floor(rand_range(INPUT_COUNT, nodes.size())) if !allow_recurrent else randi() % nodes.size()
	
	if in_node == out_node:
		return
	
	#if connection already exists, skip
	for c in connections:
		if (c.n[0]==in_node and c.n[1]==out_node) or (c.n[1]==in_node and c.n[0]==out_node): return
	
	#add connection
	add_connection( create_connection(in_node, out_node, 0.0, true) )


func mutate_add_node():
	if connections.empty(): return
	
#	find a random connection that is enabled
	#[in_node -> out_node]
	var bridge_con : Dictionary = connections[randi() % connections.size()]
	var t : int = 0
	while !bridge_con.e and t<5:
		bridge_con = connections[randi() % connections.size()]
		t += 1
	
	#add next node
	var next_node_id : int = nodes.size()
	nodes.append(0.0)
	
	#disable [in_node -> out_node]
	bridge_con.e = false
	#add [in_node -> next_node]
	add_connection(create_connection(bridge_con.n[0], next_node_id, 1.0, true))
	#add [next_node -> out_node]
	add_connection(create_connection(next_node_id, bridge_con.n[1], bridge_con.w, true))


func mutate_enabled(enable : bool):
	if connections.empty(): return
	connections[randi() % connections.size()].is_enabled = enable