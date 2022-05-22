class_name NEATNN extends Reference


var connections : Array = [] #Dict[]
var nodes : PoolRealArray = PoolRealArray()

var fitness : float = 0.0

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
			if c.out != i or !c.e: continue
			x += nodes[c.in]*c.w
		nodes[i] = activation_func(x) #TODO this needs to be activated, right????
	
	#the rest
	for c in connections:
		if is_node_input(c.out) or !c.e: continue #skip if recurrent (or not enabled)
		new_nodes[c.out] += nodes[c.in]*c.w
	
	#activate and apply
	for i in range(nodes.size()):
		nodes[i] = activation_func( new_nodes[i] )
		if is_node_output(i):
			y[i-INPUT_COUNT] = nodes[i]
	
	return y


func add_connection(c : Dictionary) -> void:
	#find place for connection from the back bc its more likely to be a the end
	for i in range(connections.size()-1, 0, -1):
		if connections[i-1].i < c.i:
			connections.insert(i, c)
			return
	connections.push_front(c)


func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Dictionary:
	return {
#		'i' : population.get_connection_innov(_in, _out) if population else connections.size(),
		'i' : connections.size(),
		'in' : _in,
		'out' : _out,
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
	print('CONNECTIONS:')
	for c in connections:
		var s : String = '(%s) [%s -> %s]' % [c.i, c.in, c.out]
		
		if !c.e:
			s += ' DISABLED'
		
		print(s)


func get_connection_by_innov(innov : int):
	for c in connections:
		if c.i == innov:
			return c
	return null


func has_connection(innov : int) -> bool:
	for c in connections:
		if c.i == innov:
			return true
	return false


func get_biggest_innov() -> int:
	var result : int = 0
	for c in connections:
		result = max(result, c.i)
	return result


func copy(nn):
	nodes = nn.nodes.duplicate()
	connections = nn.connections.duplicate()
	fitness = nn.fitness
#	species_id = nn.species_id
	return self

"""
func sort_connections():
	connections.sort_custom(self, '_connection_sort_func')

#oh boy i cant wait for lambdas
func _connection_sort_func(a, b):
	return a.i < b.i
"""



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
		if (c.in==in_node and c.out==out_node) or (c.out==in_node and c.in==out_node): return
	
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
	add_connection(create_connection(bridge_con.in, next_node_id, 1.0, true))
	#add [next_node -> out_node]
	add_connection(create_connection(next_node_id, bridge_con.out, bridge_con.w, true))


func mutate_enabled(enable : bool):
	if connections.empty(): return
	connections[randi() % connections.size()].is_enabled = enable
