extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.

func _process(delta):
	var parent = get_parent();
	var floor: Node = parent.get_parent().get_node("floor");
	var diff = floor.position - self.position;
	if diff.length() > 1000:
		parent.remove_child(self)

func _draw():
	draw_circle(Vector2(0, 0), 50, Color.RED);
