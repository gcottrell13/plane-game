extends Node2D

var dy: float = 0;
@export var GRAVITY: float = 1;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	dy += delta * GRAVITY;
	move_local_y(dy);
	
	var height = DisplayServer.window_get_size(0).y
	if self.global_position.y >= height:
		dy = -abs(dy);
		self.global_position.y = height;
