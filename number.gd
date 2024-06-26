extends Area2D
signal MergeNumber
@onready var label:Label =$Area2D/Label
@onready var number:Area2D = $Area2D

@export var num:='7'
@export var beIn=false
@export var beSelect=false
@export var movToOp:=false
const MOVE_SPEED = 10.0


var isMoving=false

var relPos=Vector2.ZERO
var operators=[]
var otherRect=null
var dir=Vector2.ZERO
var inScreenPos=Vector2.ZERO
var touchIndex=-1
func _init():
	pass
func _enter_tree() -> void:
	set_multiplayer_authority(get_parent().name.to_int())

# Called when the node enters the scene tree for the first time.
func _ready():
	operators.append($operator)
	operators.append($operator2)
	operators.append($operator3)
	operators.append($operator4)
func releasedOrBeIn():
	if movToOp:
		MovingNum()
		var res=Globals.Calc2Num(Globals.rectNumber[Globals.beSelectRect],Globals.rectNumber[self],Globals.operatorIndex)
		if res>=0:
			self.collision_layer=2
			number.collision_layer=2
			Globals.rectNumber[Globals.beSelectRect]=res
			Globals.beSelectRect.num=str(Globals.rectNumber[Globals.beSelectRect])
			while Globals.history.size()>Globals.historyIndex+1:
#						print("popback:",Globals.history)
				Globals.history.pop_back()
			var now={}
			for r in Globals.rectNumber.keys():
				if r!=self:
					now[r.name]=[r.num,r.position,r.collision_layer]
			now[self.name]=[self.num,Globals.beSelectRect.position,self.collision_layer]
			Globals.history.push_back(now)
			Globals.historyIndex+=1
#					print(Globals.history)
			emit_signal("MergeNumber")
			Globals.moveToHide(self,self.position,Globals.beSelectRect.position)

	for o in operators:
		o.modulate=Color(1,1,1,0.6)
	self.isMoving=false
	self.touchIndex=-1
	number.z_index=4
#			print(self.isMoving)
	number.monitorable=false
	self.monitorable=true
func MovingNum():
	if beIn && beSelect:
		if otherRect.global_position.x<self.position.x:
			Globals.operatorIndex=0
		else:
			Globals.operatorIndex=1
		if otherRect.global_position.y>self.position.y:
			Globals.operatorIndex+=2
		for o in operators:
			o.modulate=Color(1,1,1,0.6)
		operators[Globals.operatorIndex].modulate=Color(0.5,0.5,0.5,1)
	else:
		for o in operators:
			o.modulate=Color(1,1,1,0.6)
func _unhandled_input(event):
	if (!Globals.pkMode)||is_multiplayer_authority():
		if OS.get_name()=="iOS" || OS.get_name()=="Android":
			if self.isMoving:
				if event is InputEventScreenTouch && !event.pressed && event.index==self.touchIndex:
					releasedOrBeIn()
				elif event is InputEventScreenDrag && event.index==self.touchIndex:	
					self.position=event.position-relPos
			else:
				if event is InputEventScreenDrag:
					MovingNum()
		else:
			if self.isMoving:
				if event is InputEventMouseButton &&!event.pressed && event.button_index==MOUSE_BUTTON_LEFT:
					releasedOrBeIn()
				elif event is InputEventMouseMotion:	
					self.position=event.position-relPos
			else:
				if event is InputEventMouseMotion:
					MovingNum()
			
func chosen(event):
	self.monitorable=false
	self.monitoring=false
	self.isMoving=true
	for o in operators:
		o.modulate=Color(1,1,1,0)
#		print(self.isMoving)
	number.monitorable=true
	number.z_index=3
	relPos=event.position-self.position
	
func _on_input_event(viewport, event, shape_idx):
	if (!Globals.pkMode)||is_multiplayer_authority():
		if OS.get_name()=="iOS" || OS.get_name()=="Android":
			if event is InputEventScreenTouch && event.pressed:
				#print(event)
				#print(self.position,self.global_position)
				chosen(event)
				#print(event.position,self.position)
				self.touchIndex=event.index
		else:
			#print(event)
			if event is InputEventMouseButton && event.pressed && event.button_index==MOUSE_BUTTON_LEFT:
				chosen(event)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	self.label.text=num
	if (!Globals.pkMode)||is_multiplayer_authority():
		if !self.isMoving && self.collision_layer==1:
			inScreenPos=self.position.clamp(Vector2.ZERO,get_viewport_rect().size-$CollisionShape2D.shape.size)
			dir=Vector2.ZERO
			if inScreenPos.distance_squared_to(self.position) > 4.0:
	#			self.position=self.position.lerp(inScreenPos,delta*MOVE_SPEED)
				dir=self.position.direction_to(inScreenPos)
			if self.monitoring && self.get_overlapping_areas().size()>0:
				for a in self.get_overlapping_areas():
					if a in Globals.rectNumber:
	#					print(a)
						if a.monitorable==true:
	#						self.position=self.position.move_toward(a.position,-MOVE_SPEED)
							dir+=a.position.direction_to(self.position)
							break
			if dir!=Vector2.ZERO:
				self.position+=dir*MOVE_SPEED
			else:
				self.monitoring=true
	#			self.monitorable=true

#many can be in,but only one can be select
func _on_area_entered(area):
#	print("_on_area_entered",area)
	var tmp=area.get_parent()
	if tmp in Globals.rectNumber.keys():
		otherRect=tmp
		otherRect.movToOp=true
		beIn=true
		beSelect=true
	else:
		pass
	pass # Replace with function body.


func _on_area_exited(_area):
	beIn=false
	beSelect=false
	for o in operators:
		o.modulate=Color(1,1,1,0.6)

