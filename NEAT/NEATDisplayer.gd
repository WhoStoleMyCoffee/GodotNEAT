tool
class_name NEATDisplayer extends ReferenceRect
#Class for drawing a NEAT nn


export(Vector2) var size = Vector2(512, 256) setget set_bounds
export(Color) var node_color = Color.whitesmoke
export(float) var node_radius = 8.0
export(Color) var connection_positive_color = Color.blue
export(Color) var connection_negative_color = Color.red
export(float) var connection_width = 2.0
export(float) var max_connection_width = 10.0
export(Color) var recurrent_connection_color = Color.white
export(bool) var do_draw_node_id = false
export(Color) var font_color = Color.black
export(float) var padding = 48.0

onready var font : Font = Control.new().get_font('font')

var NN setget set_drawing_nn


func _ready():
	connect("visibility_changed", self, '_on_visibility_changed')


func set_drawing_nn(_nn):
	NN = _nn
	if !visible: return
	update()


func _draw():
	if NN == null: return
	
	var node_positions : PoolVector2Array = PoolVector2Array()
	node_positions.resize(NN.nodes.size())
	#loop input and output nodes
	for i in range(NN.INPUT_COUNT+NN.OUTPUT_COUNT):
		#idk what half of these numbers are but it works
		if NN.is_node_input(i): #INPUT NODE
			node_positions[i] = Vector2( 0,
				(size.y/(NN.INPUT_COUNT+1))*(i+1) )
		elif NN.is_node_output(i): #OUTPUT NODE
			node_positions[i] = Vector2( size.x,
				(size.y/(NN.OUTPUT_COUNT+1))*(i-NN.INPUT_COUNT+1))
	
	#we loop _k to make sure everything is nice and centered
	for _k in range(2):
		#loop hidden nodes
		#avg of all input and output nodes
		for i in range(NN.INPUT_COUNT+NN.OUTPUT_COUNT, NN.nodes.size()):
			#put the node in the middle of the furtherest positions
			var minx : float = size.x
			var miny : float = size.y
			var maxx : float = 0
			var maxy : float = 0
			
			for c in range(NEATNN.INDEX_CONNECTIONS, NN.genes.size(), NEATNN.C_LEN):
				if !NN.is_c_enabled(c): continue
				var nidx : int
				
				#check incoming connections
				if NN.get_c_out(c) == i:	nidx = NN.get_c_in(c)
				#check outgoing connections
				elif NN.get_c_in(c) == i:	nidx = NN.get_c_out(c)
				#connection has nothing to do with this node so skip it
				else: continue
				
				#check to make sure nidx is cached
				if node_positions.size() >= nidx:
					continue
				
				var p : Vector2 = node_positions[nidx]
				minx = min(minx, p.x)
				miny = min(miny, p.y)
				maxx = max(maxx, p.x)
				maxy = max(maxy, p.y)
			
			node_positions[i] = Vector2(
				clamp((minx+maxx)*0.5, padding, size.x-padding),
				clamp((miny+maxy)*0.5 + 10, padding, size.y-padding)
			)
	
	
	#outline rect
	draw_rect(Rect2(0, 0, size.x, size.y), NN.get_color(), false)
	
#	DRAW CONNECTIONS
	for c in range(NEATNN.INDEX_CONNECTIONS, NN.genes.size(), NEATNN.C_LEN):
		#skip disabled
		if !NN.is_c_enabled(c): continue
		
		if NN.genes[c+1] < 0:
			print('aaaah')
		
		var in_pos : Vector2 = node_positions[NN.get_c_in(c)]
		var out_pos : Vector2 = node_positions[NN.get_c_out(c)]
		
		var col = connection_negative_color if NN.get_c_w(c) < 0 else connection_positive_color
		if NN.is_node_input(NN.get_c_out(c)): #recurrent connection
			col = recurrent_connection_color
		
		var w : float = clamp(connection_width*abs(NN.get_c_w(c)), 1.0, max_connection_width)
		draw_line(in_pos, out_pos, col, w)
	
	
#	DRAW NODES
	for i in range(NN.nodes.size()):
		var p : Vector2 = node_positions[i]
		draw_circle(p, node_radius, node_color)
		
		if do_draw_node_id:
			draw_string(font, p + Vector2(-4, 4), str(i), font_color)



#i wanted to call this set_size but it didnt let me...
func set_bounds(v : Vector2):
	size = v
	rect_min_size = v


func _on_visibility_changed():
	if visible:
		update()
