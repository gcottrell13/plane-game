extends CharacterBody2D


@export var SPEED = 300.0
@export var JUMP_VELOCITY = -600.0

@export var GRAVITY_FLYING_DAMP: float = 0.1;
const DEFAULT_GRAVITY_DAMP = 1;
var gravity_damp: float = DEFAULT_GRAVITY_DAMP;

@export var INIT_GLIDE_SPEED: float = 500;
@export var PITCH_SPEED: float = 0.05;
@export var GLIDE_FRICTION = 0.001;
@export var GLIDE_GRAVITY_BOOST = 1.2;

const FACING_RIGHT = -1;
const FACING_LEFT = 1;
var facing = FACING_RIGHT;

# Get the gravity from the project settings so you can sync with rigid body nodes.
var dgravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var state: String = "";

var gravity: Vector2 = Vector2.ZERO;

@onready var _animation_player = $AnimationPlayer
@onready var _smp = $StateMachinePlayer
@onready var _sprite = $Sprite2D

func _physics_process(delta):
	var rid = get_rid()
	var direct_state = PhysicsServer2D.body_get_direct_state(rid)
	gravity = direct_state.get_total_gravity()
	var gnorm = gravity.normalized();
	
	if state == "Glide" or state == "Flight":
		var vang = velocity.angle_to(gravity);
		var new_angle = sign(vang) * delta;
		velocity = velocity.rotated(new_angle);
		velocity += gnorm * clamp(velocity.dot(gravity), 0, 1) * GLIDE_GRAVITY_BOOST;
		velocity *= 1 - GLIDE_FRICTION;
		_sprite.rotation = velocity.angle()
		if facing == FACING_LEFT:
			_sprite.rotation += PI;
	else:
		if gravity.y != dgravity:
			velocity += gravity * delta * gravity_damp
			up_direction = -gravity.normalized()
			velocity *= 0.95
			_sprite.rotation = gravity.angle() - PI / 2
			
	if state == "Jump":
		_smp.set_param("facing_down", velocity.dot(gravity) > 0)
	else:
		_smp.set_param("facing_down", false)
		
		
	move_and_slide()
	_smp.set_param("moving", velocity.length_squared() < 0.01);
	_smp.set_param("on_floor", is_on_floor())
	_smp.set_param("holding_jump", Input.is_action_pressed("jump"));


func _input(event):
	if event.is_action_pressed("jump"):
		_on_jump();


func _on_jump():
	if state == "Hover":
		if Input.is_action_pressed("left") or Input.is_action_pressed("right"):
			if Input.is_action_pressed("left"):
				facing = FACING_LEFT
			else:
				facing = FACING_RIGHT
			_smp.set_trigger("sideways")
		else:
			_smp.set_trigger("glide")
	else:
		_smp.set_trigger("fall_to_hover")
		_smp.set_trigger("jump")
	

func on_transit_state(from, to):
	gravity_damp = DEFAULT_GRAVITY_DAMP
	state = to;
	match to:
		"Hover":
			_animation_player.play("hover")
			gravity_damp = GRAVITY_FLYING_DAMP
		"Glide":
			_animation_player.play("glide");
			if from == "Hover":
				velocity = gravity.normalized().rotated(facing * PI / 2) * INIT_GLIDE_SPEED;
		"Flight":
			_animation_player.play("fly");
		"Walk":
			_animation_player.play("hover");
			gravity_damp = GRAVITY_FLYING_DAMP
		"Jump":
			velocity.y = JUMP_VELOCITY;
		"Falling":
			if from == "Jump" and Input.is_action_pressed("jump"):
				_smp.set_trigger("fall_to_hover");
			else:
				_animation_player.play("glide");
				gravity_damp = DEFAULT_GRAVITY_DAMP;

func _on_smp_updated(state, delta):
	_sprite.flip_h = (facing == FACING_LEFT);
	match state:
		"Cling":
			pass
		"Walk":
			pass
		"Glide":
			if Input.is_action_pressed("up"):
				_smp.set_param("pitching", true);
			elif Input.is_action_pressed("down"):
				_smp.set_param("pitching", true);
		"Hover":
			#if Input.is_action_pressed("jump"):
				#_smp.set_trigger("glide")
			pass
		"Flight":
			if Input.is_action_pressed("up"):
				velocity = velocity.rotated(facing * PITCH_SPEED);
				_smp.set_param("pitching", true);
			elif Input.is_action_pressed("down"):
				velocity = velocity.rotated(-facing * PITCH_SPEED);
				_smp.set_param("pitching", true);
			else:
				_smp.set_param("pitching", false);
