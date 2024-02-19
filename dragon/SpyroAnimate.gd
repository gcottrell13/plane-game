extends Node2D


@onready var anim = $AnimationPlayer;
@onready var sprite = $Spyro;

enum State {
	Falling,
	Null,
}

var state = State.Null;

var turnAroundTargetFlip = false;
var nextQueuedAnimation : String = "";
var priorityQueue : bool = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# anim.animation_finished.connect(animation_finished)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if nextQueuedAnimation != "":
		var animation: Animation = anim.get_animation(anim.current_animation)
		if animation == null:
			dequeue();
			return
			
		var mode = animation.loop_mode;
		if animation.loop_mode != 0 || priorityQueue:
			animation_finished(anim.current_animation)
			dequeue()
		# else, animation_finished will trigger and we can update there


func queue(name: String, _priorityQueue = false):
	nextQueuedAnimation = name;
	priorityQueue = _priorityQueue
	
	
func queue_if_not_queue(name: String, _priorityQueue = false):
	if nextQueuedAnimation == "":
		nextQueuedAnimation = name;
		priorityQueue = _priorityQueue


func dequeue():
	anim.play(nextQueuedAnimation)
	nextQueuedAnimation = ""


func animation_finished(name: String):
	match name:
		"Stand":
			queue_if_not_queue("Stand2")
		"Stand2":
			queue_if_not_queue("Stand")
		"JumpLand":
			queue_if_not_queue("Stand")
		"TurnAround":
			sprite.flip_h = turnAroundTargetFlip
		"TurnAroundAir":
			sprite.flip_h = turnAroundTargetFlip


func on_animation_finished(name: String):
	animation_finished(name);
	dequeue();


func _on_dragon_signal_running() -> void:
	if state == State.Falling:
		queue("JumpLand", true)
		state = State.Null
	else:
		queue("Run", true)


func _on_dragon_signal_jump() -> void:
	queue("Jump", true)


func _on_dragon_signal_falling() -> void:
	queue("JumpLoop")
	state = State.Falling;


func _on_dragon_signal_hover() -> void:
	queue("Glide")


func _on_dragon_signal_move_horizontal() -> void:
	match anim.current_animation:
		"Hover":
			queue("Glide")
		"Stand":
			queue("Run")
		"Stand2":
			queue("Run")


func _on_dragon_signal_stop_horizontal() -> void:
	if state == State.Falling:
		queue("JumpLand")
		
	match anim.current_animation:
		"Walk":
			queue("Stand", true)
		"Run":
			queue("Stand", true)
		"Hover":
			queue("Glide", true)
	state = State.Null


func _on_dragon_signal_set_facing(facing: int) -> void:
	turnAroundTargetFlip = (facing == -1)
	match anim.current_animation:
		"Run":
			queue("TurnAround", true)
		"Glide":
			queue("TurnAroundAir", true)
		_:
			sprite.flip_h = turnAroundTargetFlip
			queue("Run")
