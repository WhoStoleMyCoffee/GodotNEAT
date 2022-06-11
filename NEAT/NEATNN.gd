class_name NEATNN extends Reference


enum {
	INDEX_INPUTS=0,
	INDEX_OUTPUTS=1,
	INDEX_SIZE=2,
	INDEX_FITNESS=3,
	INDEX_SPECIES=4,
	
	#connections index
	INDEX_CONNECTIONS=5, #index from which connections data start at in genes
	C_LEN=3, #length of one connection in genes
	INDEX_INNOV=0,
	INDEX_NODES=1,
	INDEX_WEIGHT=2
}
var genes : Array
var nodes : PoolRealArray = PoolRealArray()

var is_speciated : bool = true
var owner #: NEATPopulation #CYCLIC DEPENDENCIES AAAAAAAAH JUAN PLS FIX

#var fitness : float = 0.0
#var species_id : int = 0
var INPUT_COUNT : int
var OUTPUT_COUNT : int



func _init(input_count : int, output_count : int) -> void:
	INPUT_COUNT = input_count
	OUTPUT_COUNT = output_count
	genes = [
		INPUT_COUNT,
		OUTPUT_COUNT,
		INPUT_COUNT+OUTPUT_COUNT,
		0.0,
		0
	]
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
		for c in range(INDEX_CONNECTIONS, genes.size(), C_LEN):
			#check if connecion.out is this node && its enabled
			if get_c_out(c) != i or !is_c_enabled(c): continue
			nodes[i] += nodes[get_c_in(c)]*get_c_w(c)
	
	#rest of the connections
	for c in range(INDEX_CONNECTIONS, genes.size(), C_LEN):
		#skip if recurrent (or not enabled)
		if is_node_input(get_c_out(c)) or !is_c_enabled(c): continue
		new_nodes[get_c_out(c)] += nodes[get_c_in(c)]*get_c_w(c)
	
	#activate
	for i in range(nodes.size()):
		nodes[i] = activation_func( new_nodes[i] )
		if is_node_output(i):
			y[i-INPUT_COUNT] = nodes[i]
	
	return y


func add_connection(c : Array) -> void:
	resize_nodes(max(nodes.size(), max((c[INDEX_NODES]>>16)&0xFFFF, c[INDEX_NODES]&0xFFFF)+1))
	var i : int = search_connection(abs(c[INDEX_INNOV]))
	genes.insert(i, c[0])
	genes.insert(i+1, c[1])
	genes.insert(i+2, c[2])


func create_connection(_in : int, _out : int, _w : float, _enabled : bool) -> Array:
	var i : int = owner.get_connection_innov(_in, _out) if owner else get_connections_count()
	return [
		i * (int(_enabled)-int(!_enabled)), #i if enabled, -i if disabled
		((_in&0xFFFF)<<16) | (_out&0xFFFF),
		_w
	]



func is_node_input(i : int) -> bool:
	return i<INPUT_COUNT

func is_node_output(i : int) -> bool:
	return i>=INPUT_COUNT and i<INPUT_COUNT+OUTPUT_COUNT


func copy(nn): #-> NEATNN
	INPUT_COUNT = nn.INPUT_COUNT
	OUTPUT_COUNT = nn.OUTPUT_COUNT
	
	resize_nodes(nn.nodes.size())
	genes = nn.genes.duplicate()
	owner = nn.owner
	return self


func get_color() -> Color:
	return owner.get_species_color(get_species_id()) if owner else Color.white


func reset():
	nodes.resize(0)
	genes.resize(INDEX_CONNECTIONS)
	genes[INDEX_FITNESS] = 0.0
	genes[INDEX_SPECIES] = 0
	return self


func set_hidden_nodes_count(count : int):
	resize_nodes(INPUT_COUNT + OUTPUT_COUNT + count)


func resize_nodes(size : int):
	genes[INDEX_SIZE] = size
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
	for c in range(INDEX_CONNECTIONS, genes.size(), C_LEN):
		if randf() > per_weight_chance: continue
		genes[c+INDEX_WEIGHT] = (get_c_w(c)+rand_range(-amt,amt)) if randf()<pertub_chance else (rand_range(-amt,amt))


#add a connection going from in_node to out_node
func mutate_add_connection(allow_recurrent : bool):
	var in_node : int = randi() % nodes.size()
	var out_node : int = floor(rand_range(INPUT_COUNT, nodes.size())) if !allow_recurrent else randi() % nodes.size()
	
	if in_node == out_node:
		return
	
	#if connection already exists, skip
	for c in range(INDEX_CONNECTIONS, genes.size(), C_LEN):
		if (get_c_in(c)==in_node and get_c_out(c)==out_node) or \
			(get_c_out(c)==in_node and get_c_in(c)==out_node): return
	
	#add connection
	add_connection( create_connection(in_node, out_node, 0.0, true) )


func mutate_add_node():
	var ccount : int = get_connections_count()
	if ccount==0: return
	
#	find a random connection that is enabled
	#[in_node -> out_node]
	var bridge_con : int = (randi()%ccount)*3 + INDEX_CONNECTIONS
	var t : int = 0 # # of tries
	while !is_c_enabled(bridge_con) and t<5: #haha magic numbers go brrrrr
		bridge_con = (randi()%ccount)*3 + INDEX_CONNECTIONS
		t += 1
	
	#add next node
	var next_node_id : int = nodes.size()
	nodes.append(0.0)
	genes[INDEX_SIZE] += 1
	
	#disable [in_node -> out_node]
	set_c_enabled(bridge_con, false)
	#add [in_node -> next_node]
	add_connection(create_connection(get_c_in(bridge_con), next_node_id, 1.0, true))
	#add [next_node -> out_node]
	add_connection(create_connection(next_node_id, get_c_out(bridge_con), get_c_w(bridge_con), true))


func mutate_enabled(enable : bool):
	if get_connections_count()==0: return
	var i : int = (randi()%get_connections_count())*3 + INDEX_CONNECTIONS
	set_c_enabled(i, enable)


# SAVE & LOAD -------------------------------------------------------------
func save_json(path : String):
	var f : File = File.new()
	f.open(path, File.WRITE)
	f.store_line(to_json(genes))
	f.close()


func load_json(path : String):
	var f : File = File.new()
	f.open(path, File.READ)
	var d : Array = parse_json(f.get_as_text())
	f.close()
	load_genes(d)


func load_genes(_genes : Array):
	genes = _genes.duplicate()
	INPUT_COUNT = genes[INDEX_INPUTS]
	OUTPUT_COUNT = genes[INDEX_OUTPUTS]
	resize_nodes(INDEX_SIZE)



# UTIL --------------------------------------------------------------------
func get_fitness() -> float:
	return genes[INDEX_FITNESS]

func set_fitness(v : float):
	genes[INDEX_FITNESS] = v

func get_species_id() -> int:
	return genes[INDEX_SPECIES]

func set_species_id(v : int):
	genes[INDEX_SPECIES] = v


func get_hidden_nodes_count() -> int:
	return nodes.size() - (INPUT_COUNT+OUTPUT_COUNT)


#get connection idx by innov
#returns -1 if not found
func get_connection(innov : int) -> int:
	var i : int = search_connection(innov)
	return i if i<genes.size() and get_c_innov(i)==innov else -1


func print_data():
	print(self, ' ----------')
	print('%s nodes' % nodes.size())
	print('CONNECTIONS:')
	for c in range(INDEX_CONNECTIONS, genes.size(), C_LEN):
		var s : String = '(%s) [%s -> %s]' % [get_c_innov(c), get_c_in(c), get_c_out(c)]
		if !is_c_enabled(c):
			s += ' DISABLED'
		print(s)


func activation_func(x : float):
#	return 1/(1+exp(-x)) #sigmoid
	return 1/(1+exp(-4*x)) #steeper sigmoid
#	return tanh(x)*0.5 + 0.5 #tanh


#i : the start of the connection in genes
func get_c_in(i : int) -> int:
	return (int(genes[i+INDEX_NODES])>>16)&0xFFFF

func get_c_out(i : int) -> int:
	return int(genes[i+INDEX_NODES])&0xFFFF

func get_c_w(i : int) -> float:
	return genes[i+INDEX_WEIGHT]

func get_c_innov(i : int) -> int:
	return int(abs(genes[i]))

func is_c_enabled(i : int) -> bool:
	return genes[i] >= 0

func set_c_enabled(i : int, enable : bool):
	genes[i] = abs(genes[i]) * (1 if enable else -1)


func get_connections_count() -> int:
	return (genes.size()-INDEX_CONNECTIONS) / 3


#finds a connection by innov
#if not found, return the index where it should be inserted
func search_connection(innov : int) -> int:
	for c in range(genes.size()-C_LEN, INDEX_CONNECTIONS-1, -1):
		if get_c_innov(c) == innov: return c
		if get_c_innov(c) < innov: return c+C_LEN
	return INDEX_CONNECTIONS
