extends Control
@export var SERVER_PORT:int=60001
@onready var menu: VBoxContainer = $menu
@onready var main=preload("res://main.tscn")
@onready var your_viewport: SubViewport = $Your/YourViewport
@onready var my_viewport: SubViewport = $My/MyViewport
@onready var dot: Label = $Label/Dot
@onready var label: Control = $Label
@onready var max_int: Label = $menu/HBoxContainer/maxInt

var peer=ENetMultiplayerPeer.new()
var midy=720
var udp := PacketPeerUDP.new()
var server := UDPServer.new()
var t=Time.get_unix_time_from_system()
var preRoundSet=Globals.round_set
var canPressJoin=true
func _init():
	preRoundSet=Globals.round_set
	OS.request_permission("INTERNET")
	if OS.get_name()!="iOS" && OS.get_name()!="Android":
		DisplayServer.window_set_size(Vector2i(450,900))
	Globals.round_set=10
func _ready() -> void:
	var s=get_viewport_rect().size
	midy=s.y/2
	my_viewport.size=Vector2(s.x,s.y/2)
	your_viewport.size=my_viewport.size
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)
	Globals.round_index=1
	Globals.history.clear()
func _exit_tree() -> void:
	Globals.round_set=preRoundSet
	print("_exit_tree ",multiplayer.get_unique_id())
	if multiplayer.is_server():
		if multiplayer.multiplayer_peer!=null:
			multiplayer.multiplayer_peer.disconnect_peer(Globals.pkCId,false)
			multiplayer.multiplayer_peer.close()
	else:
		your_viewport.remove_child(your_viewport.get_child(1))
		my_viewport.remove_child(my_viewport.get_child(1))
		if multiplayer.multiplayer_peer!=null:
			multiplayer.multiplayer_peer.disconnect_peer(1,false)
	multiplayer.multiplayer_peer=null
func _on_host_pressed() -> void:
	if !multiplayer.peer_connected.is_connected(AddPlayer):
		Globals.pkWin=false
		dot.text=""
		label.scale=Vector2.ZERO
		$Label/Title.text="Waiting for client join"
		label.show()
		peer.close()
		$My.set_position(Vector2(0,midy))
		$Your.set_position(Vector2(0,0))
		$Your.modulate=Color(0.75,0.75,0.75,1)
		$My.modulate=Color(1,1,1,1)
		peer.create_server(SERVER_PORT)
		multiplayer.multiplayer_peer=peer
		multiplayer.peer_connected.connect(AddPlayer)
		Globals.genPkSubject()
		AddPlayer()
		var tween=get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(label,"scale",Vector2.ONE,1)
		server.listen(SERVER_PORT+1)
		set_process(true)
		t=Time.get_unix_time_from_system()
		#print(t,multiplayer.multiplayer_peer)
func AddPlayer(id=1)->void:
	var player=main.instantiate()
	player.name=str(id)
	if id==1:
		while my_viewport.get_child_count()>1:
			my_viewport.get_child(1).queue_free()
			my_viewport.remove_child(my_viewport.get_child(1))
			#print("remove child ",my_viewport.get_child_count())
		my_viewport.add_child(player)
	else:
		Globals.pkCId=id
		shareSubject.rpc_id(id, Globals.pkNumbers,Globals.pkSolutions,Globals.started_at,Globals.round_set)
		your_viewport.add_child(player)
		Globals.round_index=1
		await get_tree().create_timer(0.7).timeout
		Globals.started_at=Time.get_unix_time_from_system()
		label.hide()
		$My.visible=true
		$Your.visible=true
		menu.hide()
		shakeView($My)
		print(id," join")
func _process(_delta):
	if label.visible:
		if Time.get_unix_time_from_system()-t>1:
			dot.text+='.'
			t=Time.get_unix_time_from_system()
	if server.is_listening():
		server.poll()
		if server.is_connection_available():
			var p : PacketPeerUDP = server.take_connection()
			var pkt = p.get_packet()
			print(p.get_packet_ip(),":",p.get_packet_port()," ",pkt.get_string_from_utf8())
			p.put_packet(pkt)
			server.stop()
	if udp.get_available_packet_count() > 0:
		print(udp.get_packet().get_string_from_utf8()," client found:",udp.get_packet_ip())
		var error =peer.create_client(udp.get_packet_ip(),SERVER_PORT)
		if error == OK:
			multiplayer.multiplayer_peer=peer
		else:
			print("peer.create_client error:",error)
func RemovePlayer(id=1)->void:
	print("RemovePlayer:",id)
	#your_viewport.remove_child(your_viewport.get_child(1))

@rpc("any_peer","call_remote","reliable")
func myclose(id):
	print("my close ",id)
	multiplayer.multiplayer_peer.disconnect_peer(id,false)
	your_viewport.remove_child(your_viewport.get_child(1))
	
@rpc("any_peer","call_remote","reliable")
func shareSubject(numbers,solutions,started_at,rounds)->void:
	Globals.pkNumbers=numbers
	Globals.pkSolutions=solutions
	Globals.numbers=Globals.pkNumbers[Globals.round_index-1]
	Globals.solution=Globals.pkSolutions[Globals.round_index-1]
	#Globals.started_at=started_at
	
	Globals.round_set=rounds
	Globals.genSolution.emit()
	print("get shareSubject",numbers,solutions)
func _on_connected_fail():
	print("_on_connected_fail")
	$My.visible=false
	$Your.visible=false
	menu.show()
func _on_connected_ok():
	await get_tree().create_timer(0.7).timeout
	Globals.started_at=Time.get_unix_time_from_system()
	$My.visible=true
	$Your.visible=true
	menu.hide()
	shakeView($Your)
func shakeView(view)->void:
	var tween=get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(view,"rotation",0.15,0.1)
	tween.tween_property(view,"rotation",-0.12,0.1)
	tween.tween_property(view,"rotation",0.09,0.1)
	tween.tween_property(view,"rotation",-0.06,0.1)
	tween.tween_property(view,"rotation",0,0.1)
	
func _on_join_pressed() -> void:
	if canPressJoin:
		canPressJoin=false
		Globals.pkWin=false
		#Globals.restart()
		while my_viewport.get_child_count()>1:
			my_viewport.get_child(1).queue_free()
			my_viewport.remove_child(my_viewport.get_child(1))
		multiplayer.peer_connected.disconnect(AddPlayer)
		if multiplayer.multiplayer_peer!=null:
			multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer=null
		server.stop()
		Globals.round_index=1
		set_process(true)
		udp.set_broadcast_enabled(true)
		udp.set_dest_address("255.255.255.255", SERVER_PORT+1)
		udp.put_packet("Search Host".to_utf8_buffer())
		for j in [0,1,43]:
			for i in range(2,255):
				udp.set_dest_address("192.168.%d.%d"%[j,i],SERVER_PORT+1)
				udp.put_packet("Search Host".to_utf8_buffer())
		$My.set_position(Vector2(0,0))
		$Your.set_position(Vector2(0,midy))
		$My.modulate=Color(0.75,0.75,0.75,1)
		$Your.modulate=Color(1,1,1,1)
		await get_tree().create_timer(2.1).timeout
		if !server.is_listening():
			label.scale=Vector2.ZERO
			dot.text=""
			$Label/Title.text="No server found\nPlease try again later"
			label.show()
			var tween=get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
			tween.tween_property(label,"scale",Vector2.ONE,1)
		canPressJoin=true
	
func _on_server_disconnected()->void:
	print("_on_server_disconnected")
	if(your_viewport.get_child_count()>1):
		your_viewport.remove_child(your_viewport.get_child(1))
	if(my_viewport.get_child_count()>1):
		my_viewport.remove_child(my_viewport.get_child(1))
	$My.visible=false
	$Your.visible=false
	label.hide()
	menu.show()
	if multiplayer.multiplayer_peer!=null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=null
	
func _on_back_pressed() -> void:
	if multiplayer.multiplayer_peer!=null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=null
	Globals.go_to_world("res://ui/menu.tscn")


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	print("_on_multiplayer_spawner_spawned ",node.name)


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	Globals.round_set=int(max_int.text)

func _on_h_slider_value_changed(value: float) -> void:
	if label.visible && multiplayer.is_server():
		server.stop()
		label.visible=false
		multiplayer.peer_connected.disconnect(AddPlayer)
		if multiplayer.multiplayer_peer!=null:
			multiplayer.multiplayer_peer.close()
	max_int.text=str(value)
	Globals.round_set=value
