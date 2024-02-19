extends Node2D


var VALUE: float = -1;
var MAX: float = -1;

var RADIUS: float = 10;

var last_update_time: int = 0;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	last_update_time = Time.get_unix_time_from_system()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Time.get_unix_time_from_system() > last_update_time + 4 and VALUE >= MAX:
		visible = false;


func _draw():
	if MAX < 0 or VALUE < 0:
		return
	
	var width = 5;
	var radius = RADIUS;
	var color = Color.GREEN;
	var value = VALUE;
	
	draw_arc(Vector2.ZERO, radius, 0, 2*PI, 30, Color(Color.GRAY, 0.5), width, false);
	
	while value > MAX:
		draw_arc(Vector2.ZERO, radius, 0, 2*PI, 30, color, width, false);
		radius += 2.5 + width / 2 + 2;
		width = 3;
		value -= MAX;
	
	var partial = value / MAX;
	var points = max(3, int(partial * 30));
	draw_arc(Vector2.ZERO, radius, 0, partial* 2*PI, points, color, width, false);



func _on_dragon_stamina_depleted(new_value: float, max: float) -> void:
	VALUE = new_value;
	MAX = max;
	last_update_time = Time.get_unix_time_from_system()
	visible = true;
	queue_redraw();
