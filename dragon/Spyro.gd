extends Sprite2D

@export var DebugDrawSprite : bool = false:
	set(value): 
		set_debug_draw(value)

var shader : ShaderMaterial = material;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_debug_draw(b: bool):
	shader.set_shader_parameter("debug", b);
