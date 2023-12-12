extends CharacterBody2D


@export var SPEED = 300.0
@export var JUMP_VELOCITY = 600.0

@export var MAX_FALL_SPEED = 500;

@export var GRAVITY_FLYING_DAMP: float = 0.1;
const DEFAULT_GRAVITY_DAMP = 1;
var gravity_damp: float = DEFAULT_GRAVITY_DAMP;

@export var INIT_GLIDE_SPEED: float = 500;
@export var PITCH_SPEED: float = 0.05;
@export var GLIDE_MAX_SPEED: float = 300;
@export var GLIDE_FRICTION = 1.5;
@export var GLIDE_ACCEL = 600;
@export var MIN_FLIGHT_SPEED_CONTROL = 20;

@export var WALK_ACCEL = 600;
@export var WALK_MAX = 150;

@export var HOVER_ACCEL = 300;
@export var HOVER_MAX = 100;

const FACING_RIGHT = 1;
const FACING_LEFT = -1;
var facing = FACING_RIGHT;

# Get the gravity from the project settings so you can sync with rigid body nodes.
var dgravity = ProjectSettings.get_setting("physics/2d/default_gravity")

const deg10 = PI / 18;
const deg80 = PI * 8 / 18;

var state: String = "";
var is_hold_gliding = false;

var spriteRotation: Vector2 = Vector2.RIGHT;

var gravity: Vector2 = Vector2.ZERO;
var leftDir: Vector2 = Vector2.ZERO;
var rightDir: Vector2 = Vector2.ZERO;

var floorNormal: Vector2 = Vector2.ZERO;
var pvel = Vector2.ZERO;

@onready var _animation_player = $AnimationPlayer
@onready var _smp = $StateMachinePlayer
@onready var _sprite = $Sprite2D
@onready var _camera = $Camera2D
@onready var _collision = $CollisionShape2D

const MAX_ZOOM = 1.7;
const MIN_ZOOM = 0.5;
var prev_camerazoom = MAX_ZOOM;

func _physics_process(delta):
	var gnorm = get_gravity();
	handle_camera(gnorm, delta);
	
	leftDir = up_direction.rotated(-PI / 2)
	rightDir = up_direction.rotated(PI / 2)
	
	var lr_direction = Input.get_axis("left", "right");
	var lr_vec = lr_direction * rightDir;
	
	var ud_direction = Input.get_axis("down", "up");
	var ud_vec = ud_direction * up_direction;
	
	if state == "Glide" or state == "Flight":
		var vang = velocity.angle_to(gnorm) * facing;
		if facing == lr_direction and deg10 < vang and vang < deg80:  
			set_hold_glide(true)
		else:
			set_hold_glide(false)
			velocity = rotate_toward_vec2(velocity, gnorm * GLIDE_MAX_SPEED, GLIDE_FRICTION * delta);
		
		var speed = velocity.length();
		var pitching = false;
		if ud_direction != 0:
			spriteRotation = spriteRotation.rotated(facing * PITCH_SPEED * -ud_direction);
			pitching = true;
			
		if speed > MIN_FLIGHT_SPEED_CONTROL:
			var rotationDiff = abs(spriteRotation.angle_to(velocity) / (PI / 4));
			if rotationDiff <= 1:
				var control = 1 - rotationDiff;
				if not pitching:
					var ang = spriteRotation.angle_to(velocity) * control;
					spriteRotation = spriteRotation.rotated(ang);
				else:
					var angle = velocity.angle_to(spriteRotation);
					velocity = velocity.rotated(control * angle);
		
		_sprite.rotation = spriteRotation.angle();
		if facing == FACING_LEFT:
			_sprite.rotation += PI;
			
	elif state == "Walk" or state == "Idle":
		if lr_direction != 0:
			velocity = velocity.move_toward(lr_vec * WALK_MAX, WALK_ACCEL * delta);
		else:
			velocity = velocity.move_toward(Vector2.ZERO, WALK_ACCEL * delta);
		_sprite.rotation = gravity.angle() + get_floor_angle(up_direction) - PI / 2
		facing = get_facing_from_velocity();
		
	elif state == "Falling" or state == "Jump":
		var horiz = velocity.dot(get_dir_from_facing()) * get_dir_from_facing();
		var verti = velocity.dot(up_direction) * up_direction;
		verti = verti.move_toward(gnorm * MAX_FALL_SPEED, gravity.length() * delta);
		velocity = horiz + verti;
		_sprite.rotation = gravity.angle() - PI / 2
		
	elif state == "Hover":
		if lr_direction != 0 or ud_direction != 0:
			var target_velocity = (lr_vec + ud_vec) * HOVER_MAX;
			velocity = velocity.move_toward(target_velocity, HOVER_ACCEL * delta);
		else:
			velocity = velocity.move_toward(Vector2.ZERO, HOVER_ACCEL * delta);
		facing = get_facing_from_velocity();
		_sprite.rotation = gravity.angle() - PI / 2
			
	if state == "Jump":
		_smp.set_param("facing_down", velocity.dot(gravity) > 0)
	else:
		_smp.set_param("facing_down", false)
		
	move_and_slide()
	_smp.set_param("moving", velocity.length_squared() > 0.01);
	_smp.set_param("on_floor", is_on_floor())
	_smp.set_param("holding_jump", Input.is_action_pressed("jump"));


func get_gravity():
	var rid = get_rid()
	var direct_state = PhysicsServer2D.body_get_direct_state(rid)
	gravity = direct_state.get_total_gravity()
	var gnorm = gravity.normalized();
	up_direction = -gnorm;
	return gnorm;


func rotate_toward_vec2(from: Vector2, to: Vector2, by: float):
	var angle = rotate_toward(from.angle(), to.angle(), by);
	return Vector2.from_angle(angle) * from.length();

func _input(event):
	if event.is_action_pressed("jump"):
		_on_jump();

func get_facing_from_velocity():
	if velocity.dot(leftDir) > 0:
		return FACING_LEFT;
	elif velocity.dot(rightDir) > 0:
		return FACING_RIGHT;
	return facing;

func get_dir_from_facing():
	match facing:
		FACING_LEFT:
			return leftDir;
		FACING_RIGHT:
			return rightDir;

func handle_camera(gnorm: Vector2, delta: float):
	_camera.rotation = gnorm.angle() - PI / 2;
	var camerazoom = clamp(MAX_ZOOM - clamp(log(velocity.length() / 500), 0, 1), MIN_ZOOM, MAX_ZOOM);
	var new_camerazoom = move_toward(prev_camerazoom, camerazoom, delta / 5);
	prev_camerazoom = new_camerazoom;
	_camera.zoom = Vector2(new_camerazoom, new_camerazoom);
			
func _draw():
	if state == "Walk" or state == "Idle":
		var ang = up_direction.angle_to(floorNormal);
		var _left = leftDir.rotated(ang);
		var _right = rightDir.rotated(ang);
		#draw_line(Vector2.ZERO, _left*100, Color.RED);
		#draw_line(Vector2.ZERO, _right*100, Color.BLUE);
		#draw_line(Vector2.ZERO, floorNormal*100, Color.WHITE);
		#draw_line(Vector2.ZERO, pvel.normalized() * 100, Color.GREEN);

func set_hold_glide(b: bool):
	if state != "Glide":
		return
	if b and not is_hold_gliding:
		_animation_player.play("fly");
	elif not b and is_hold_gliding:
		_animation_player.play("glide");
	else:
		return
	is_hold_gliding = b


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
			if from == "Hover" or from == "Falling":
				velocity += up_direction.rotated(facing * PI / 2) * INIT_GLIDE_SPEED;
				spriteRotation = velocity.normalized();
		"Flight":
			_animation_player.play("fly");
			gravity_damp = GRAVITY_FLYING_DAMP
		"Walk":
			_animation_player.play("hover");
		"Idle":
			_animation_player.play('idle');
		"Jump":
			velocity += up_direction * JUMP_VELOCITY;
		"Falling":
			if from == "Jump" and Input.is_action_pressed("jump"):
				if Input.is_action_pressed("left") or Input.is_action_pressed("right"):
					_smp.set_trigger("sideways");
				elif Input.is_action_just_pressed("down"):
					_smp.set_trigger("sideways");
				else:
					_smp.set_trigger("fall_to_hover");
			else:
				_animation_player.play("falling");

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
				_smp.set_param("pitching", true);
			elif Input.is_action_pressed("down"):
				_smp.set_param("pitching", true);
			else:
				_smp.set_param("pitching", false);
