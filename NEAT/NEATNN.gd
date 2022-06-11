class_name NEATNN extends Reference


var connections : Array = [] #Dict[]
var nodes : PoolRealArray = PoolRealArray()

var fitness : float = 0.0
var species_id : int = 0
var is_speciated : bool = true
var owner #: NEATPopulation #CYCLIC DEPENDENCIES AAAAAAAAH JUAN PLS FIX

var INPUT_COUNT : int
var OUTPUT_COUNT : int



func _init(input_count : int, output_count : int) -> void:
	INPUT_COUNT = input_count
	OUTPUT_COUNT = output_count
	resize_nodes(INPUT_COUNT + OUTPUT_COUNT)


func feed_forward(X : Array) -> Array:
	var y : Array = []
	var new_nodes : PoolRealArray = PoolRealArray()
	new_nodes.resize(nodes.size())
	y.resize(OUTPUT_COUNT)
	
	#set inputs
	for i in range(INPUT_COUNT):
		nodes[i] = float(X[i])
		
		#recurrent connections
		for c in connections:
			if c.n[1] != i or !c.e: continue
			nodes[i] += nodes[c.n[0]]*c.w
	
	#rest of the connections
	for c in connections:
		if is_node_input(c.n[1]) or !c.e: continue #skip if recurrent (or not enabled)
		new_nodes[c.n[1]] += nodes[c.n[0]]*c.w
	
	#activate
	for i in range(nodes.size()):
		nodes[i] = activation_func( new_nodes[i] )
		if is_node_output(i):
			y[i-INPUT_COUNT] = nodes[i]
	
	return y


func add_connection(c : Dictionary) -> void:
	resize_nodes(max(nodes.size(), max(c.n[0], c.n[1])+1))
	var i : int = connections.bsearch_custom(c.i, self, "_compare_connections", true)
	connections.insert(i, c)


func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Dictionary:
	return {
		'i' : owner.get_connection_innov(_in, _out) if owner else connections.size(),
		'n' : PoolIntArray([_in, _out]),
		'w' : _w,
		'e' : _enabled
	}



func is_node_input(i : int) -> bool:
	return i<INPUT_COUNT

func is_node_output(i : int) -> bool:
	return i>=INPUT_COUNT and i<INPUT_COUNT+OUTPUT_COUNT


func set_connection_enabled(i : int, v : bool):
	connections[i].e = v



func get_biggest_innov() -> int:
	var result : int = 0
	for c in connections:
		result = max(result, c.i)
	return result


func copy(nn): #-> NEATNN
	INPUT_COUNT = nn.INPUT_COUNT
	OUTPUT_COUNT = nn.OUTPUT_COUNT
	
	resize_nodes(nn.nodes.size())
	connections = nn.connections.duplicate(true)
	fitness = nn.fitness
	species_id = nn.species_id
	owner = nn.owner
	return self


func get_color() -> Color:
	return owner.get_species_color(species_id) if owner else Color.white


func reset():
	nodes.resize(0)
	connections.clear()
	fitness = 0.0
	species_id = 0
	return self


#connect every input node with every hidden node (if any) and every hidden with every output
func connect_all_nodes(): #-> NEATNNs
	connections.clear()
	var hidden_count = get_hidden_nodes_count()
	
	if hidden_count == 0:
		for i in range(INPUT_COUNT):
			for o in range(OUTPUT_COUNT):
				add_connection(create_connection(i, INPUT_COUNT+o, 1, true))
		return self
		
	for i in range(INPUT_COUNT):
		for o in range(hidden_count):
			add_connection(create_connection(i, INPUT_COUNT+OUTPUT_COUNT+o, 1, true))
	for i in range(hidden_count):
		for o in range(OUTPUT_COUNT):
			add_connection(create_connection(INPUT_COUNT+OUTPUT_COUNT+i, INPUT_COUNT+o, 1, true))
	return self


func set_hidden_nodes_count(count : int):
	resize_nodes(INPUT_COUNT + OUTPUT_COUNT + count)


func resize_nodes(size : int):
	if size < nodes.size():
		nodes.resize(size)
		return
	
	for _i in range(size-nodes.size()):
		nodes.append(0.0)


#sets all nodes to 0
func zero_out_nodes():
	for i in range(nodes.size()):
		nodes[i] = 0



# MUTATION --------------------------------------------------------------------
func mutate(configs : ConfigFile):
	if randf() < configs.get_value('mutation', 'P_weight', 0.8):
		mutate_weights(
			configs.get_value('mutation', 'P_per_weight', 0.5),
			configs.get_value('mutation', 'P_weight_pertub', 0.95),
			configs.get_value('mutation', 'weight_amt', 2.5))
	if randf() < configs.get_value('mutation', 'P_connection', 0.05):
		mutate_add_connection( configs.get_value('mutation', 'allow_recurrent', true) )
	if randf() < configs.get_value('mutation', 'P_node', 0.01):
		mutate_add_node()
	if randf() < configs.get_value('mutation', 'P_enable', 0.01):
		mutate_enabled(true)
	if randf() < configs.get_value('mutation', 'P_disable', 0.01):
		mutate_enabled(false)


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


# SAVE & LOAD -------------------------------------------------------------
func save_json(path : String):
	var f : File = File.new()
	f.open(path, File.WRITE)
	f.store_line(to_json(get_compressed()))
	f.close()


func load_json(path : String):
	var f : File = File.new()
	f.open(path, File.READ)
	var d : Array = parse_json(f.get_as_text())
	f.close()
	load_compressed(d)


func get_compressed() -> Array:
	var data : Array = [
		INPUT_COUNT,
		OUTPUT_COUNT,
		nodes.size(),
		fitness,
		species_id
	]
	for c in connections:
		data.append_array(NeatUtil.compress_connection(c))
	
	return data


func load_compressed(d : Array):
	INPUT_COUNT = int(d[0])
	OUTPUT_COUNT = int(d[1])
	resize_nodes(int(d[2]))
	fitness = d[3]
	species_id = int(d[4])
	
	connections.clear()
	for i in range(5, d.size(), 3):
		connections.append(NeatUtil.uncompress_connection(int(d[i]), int(d[i+1]), d[i+2]))
	return self



# UTIL --------------------------------------------------------------------
func get_hidden_nodes_count() -> int:
	return nodes.size() - (INPUT_COUNT+OUTPUT_COUNT)


func _compare_connections(a, b) -> bool:
	return a.i < b

func get_connection(innov : int):
	var i : int = connections.bsearch_custom(innov, self, "_compare_connections", true)
	return connections[i] if i < connections.size() and connections[i].i == innov else null

func has_connection(innov : int) -> bool:
	var i : int = connections.bsearch_custom(innov, self, "_compare_connections", true)
	return i < connections.size()


func print_data():
	print(self, ' ----------')
	print('%s nodes' % nodes.size())
	print('CONNECTIONS:')
	for c in connections:
		var s : String = '(%s) [%s -> %s]' % [c.i, c.n[0], c.n[1]]
		
		if !c.e:
			s += ' DISABLED'
		
		print(s)


func activation_func(x : float):
#	return 1/(1+exp(-x)) #sigmoid
	return 1/(1+exp(-4*x)) #steeper sigmoid
#	return tanh(x)*0.5 + 0.5 #tanh
