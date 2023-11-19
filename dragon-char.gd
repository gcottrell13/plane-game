extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var GRAVITY_FLYING_DAMP: float = 0.1;
const DEFAULT_GRAVITY_DAMP = 1;
var gravity_damp: float = DEFAULT_GRAVITY_DAMP;

# Get the gravity from the project settings so you can sync with rigid body nodes.
var dgravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var _animation_player = $AnimationPlayer
@onready var _smp = $StateMachinePlayer
@onready var _sprite = $Sprite2D

func _physics_process(delta):
	var rid = get_rid()
	var direct_state = PhysicsServer2D.body_get_direct_state(rid)
	var g = direct_state.get_total_gravity()
	
	if g.y != dgravity:
		velocity += g * delta * gravity_damp
		up_direction = -g.normalized()
		velocity *= 0.95
		_sprite.rotation = velocity.angle() - PI / 2
		
	move_and_slide()
	_smp.set_param("on_floor", is_on_floor())
	_smp.set_param("is_jumping", Input.is_action_pressed("jump"));


func _input(event):
	if event.is_action_pressed("jump"):
		_on_jump()


func _on_jump():
	_smp.set_trigger("jump")
	_smp.set_trigger("glide")
	

func on_transit_state(from, to):
	gravity_damp = DEFAULT_GRAVITY_DAMP
	match to:
		"Hover":
			_animation_player.play("hover")
			gravity_damp = GRAVITY_FLYING_DAMP
		"Glide":
			_animation_player.play("glide")
		"Walk":
			_animation_player.play("hover");
			gravity_damp = GRAVITY_FLYING_DAMP

func _on_smp_updated(state, delta):
	match state:
		"Cling":
			pass
		"Walk":
			pass
		"Hover":
			if Input.is_action_pressed("jump"):
				_smp.set_trigger("glide")
