extends CharacterBody2D


@export var SPEED = 300.0
@export var JUMP_VELOCITY = 300.0

@export var MAX_FALL_SPEED = 500;
@export var MAX_FALL_HORIZ_SPEED = 100;
@export var FALL_HORIZ_ACCEL = 200;

@export var GRAVITY_FLYING_DAMP: float = 0.1;
const DEFAULT_GRAVITY_DAMP = 1;
var gravity_damp: float = DEFAULT_GRAVITY_DAMP;

@export var INIT_GLIDE_SPEED: float = 500;
@export var PITCH_SPEED: float = 0.05;
@export var GLIDE_MAX_SPEED: float = 300;
@export var GLIDE_FRICTION = 200;
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

var floorNormal: Vector2 = Vector2.ZERO;
var pvel = Vector2.ZERO;

var holding_glide_angle = -1;

var local_velocity = Vector2.ZERO;
var local_rotation = Vector2.RIGHT;

@onready var _smp = $StateMachinePlayer
@onready var _sprite = $Sprite
@onready var _camera = $Camera2D
@onready var _collision = $CollisionShape2D

const MAX_ZOOM = 1.7;
const MIN_ZOOM = 0.5;
var prev_camerazoom = MAX_ZOOM;
var previous_up_direction = Vector2.UP;

func _physics_process(delta):
	var gnorm = get_gravity();
	handle_camera(gnorm, delta);
	
	var LEFT = Vector2.LEFT;
	var RIGHT = Vector2.RIGHT;
	var UP = Vector2.UP;
	var DOWN = Vector2.DOWN;
	
	var lr_direction: float = Input.get_axis("left", "right");
	var lr_vec = lr_direction * RIGHT;
	
	var ud_direction: float = Input.get_axis("down", "up");
	var ud_vec = ud_direction * UP;
	
	var velocity_x_before = local_velocity.x;
	
	if state == "Glide" or state == "Flight":
		var vang = local_velocity.angle_to(DOWN) * facing;
		var holding = facing == lr_direction and deg10 < vang and vang < deg80;
		var speed = local_velocity.length();
		
		var pitching = false;
		if ud_direction != 0:
			local_rotation = local_rotation.rotated(facing * PITCH_SPEED * -ud_direction);
			pitching = true;
			
		if holding:
			set_hold_glide(true)
		else:
			set_hold_glide(false)
			holding_glide_angle = -1;
			local_velocity.y = move_toward(local_velocity.y, GLIDE_MAX_SPEED, GLIDE_FRICTION * delta);
			
		if speed > MIN_FLIGHT_SPEED_CONTROL:
			var rotationDiff = abs(local_rotation.angle_to(velocity) / (PI / 4));
			if rotationDiff <= 1:
				var control = 1 - rotationDiff;
				if not pitching:
					var ang = local_rotation.angle_to(velocity) * control;
					local_rotation = local_rotation.rotated(ang);
				else:
					var angle = velocity.angle_to(local_rotation);
					local_velocity = local_velocity.rotated(control * angle);
		
		_sprite.rotation = get_sprite_rotation().angle();
		if facing == FACING_LEFT:
			_sprite.rotation += PI;
			
	elif state == "Walk" or state == "Idle":
		if lr_direction != 0:
			local_velocity.x = move_toward(local_velocity.x, WALK_MAX * lr_direction, WALK_ACCEL * delta);
			local_velocity.y += 1;
		else:
			local_velocity.x = move_toward(local_velocity.x, 0, WALK_ACCEL * delta);
			local_velocity.y += 1;
		facing = get_facing_from_velocity();
		
	elif state == "Falling" or state == "Jump":
		local_velocity.y = move_toward(local_velocity.y, MAX_FALL_SPEED, gravity.length() * delta);
		local_velocity.x = move_toward(local_velocity.x, lr_direction * MAX_FALL_HORIZ_SPEED, FALL_HORIZ_ACCEL * delta);
		_sprite.rotation = gravity.angle() - PI / 2
		facing = get_facing_from_velocity();
		
	elif state == "Hover":
		if ud_vec == Vector2.UP:
			on_drain_stamina(1.0);
		elif lr_direction != 0:
			on_drain_stamina(0.5);
		
		if lr_direction != 0 or ud_direction != 0:
			var target_velocity = (lr_vec + ud_vec) * HOVER_MAX;
			local_velocity = local_velocity.move_toward(target_velocity, HOVER_ACCEL * delta);
		else:
			local_velocity = local_velocity.move_toward(Vector2.ZERO, HOVER_ACCEL * delta);
		facing = get_facing_from_velocity();
		_sprite.rotation = gravity.angle() - PI / 2
			
	if state == "Jump":
		_smp.set_param("facing_down", local_velocity.y > 0)
	else:
		_smp.set_param("facing_down", false)
	
	#if sign(velocity_x_before) != sign(local_velocity.x) && local_velocity.x != 0:
		#signal_velocity_x_dir.emit(sign(local_velocity.x))
		
	set_split_velocity();
	
	move_and_slide()
	
	local_velocity = velocity.rotated(up_direction.angle_to(Vector2.UP));
	
	if _smp.get_param("on_floor") != is_on_floor():
		match is_on_floor():
			true:
				signal_falling.emit();
			false:
				signal_running.emit();
				
	var new_is_moving = abs(local_velocity.x) > 0.01;
	if _smp.get_param("moving") != new_is_moving:
		match new_is_moving:
			true:
				signal_move_horizontal.emit();
			false:
				signal_stop_horizontal.emit();
	
	if _smp.get_param("facing") != facing:
		match facing:
			FACING_LEFT:
				signal_set_facing.emit(-1);
			FACING_RIGHT:
				signal_set_facing.emit(1);
				
	_smp.set_param("moving", new_is_moving);
	_smp.set_param("on_floor", is_on_floor())
	_smp.set_param("holding_jump", Input.is_action_pressed("jump"));
	_smp.set_param("facing", facing);
	
	if is_on_floor():
		_sprite.rotation = get_floor_normal().angle() + PI / 2;


func set_split_velocity():
	var angle = up_direction.angle_to(Vector2.UP);
	
	if previous_up_direction != up_direction:
		var gravity_change = previous_up_direction.angle_to(up_direction);
		angle += gravity_change;
	previous_up_direction = up_direction;
	
	velocity = local_velocity.rotated(-angle);

func get_sprite_rotation():
	#var angle = up_direction.angle_to(Vector2.UP);
	#return local_rotation.rotated(angle);
	return local_rotation

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
	if local_velocity.x < 0:
		return FACING_LEFT;
	elif local_velocity.x > 0:
		return FACING_RIGHT;
	return facing;

func handle_camera(gnorm: Vector2, delta: float):
	_camera.rotation = gnorm.angle() - PI / 2;
	var camerazoom = clamp(MAX_ZOOM - clamp(log(velocity.length() / 500), 0, 1), MIN_ZOOM, MAX_ZOOM);
	var new_camerazoom = move_toward(prev_camerazoom, camerazoom, delta / 5);
	prev_camerazoom = new_camerazoom;
	_camera.zoom = Vector2(new_camerazoom, new_camerazoom);
			

func set_hold_glide(b: bool):
	if state != "Glide":
		return
	if b and not is_hold_gliding:
		signal_flapping.emit()
	elif not b and is_hold_gliding:
		signal_gliding.emit()
	else:
		return
	is_hold_gliding = b


func _on_jump():
	match state:
		"Hover":
			var lr = Input.get_axis("left", "right");
			if lr != 0:
				facing = lr;
				_smp.set_trigger("glide")
			elif Input.is_action_pressed("down"):
				_smp.set_trigger("fall");
		"Falling":
			var glide_from_fall = Input.get_axis("left", "right")
			if glide_from_fall != 0:
				facing = FACING_RIGHT * glide_from_fall;
				_smp.set_trigger("glide");
			else:
				_smp.set_trigger("fall_to_hover")
		_:
			_smp.set_trigger("jump")
	

func on_transit_state(from, to):
	gravity_damp = DEFAULT_GRAVITY_DAMP
	state = to;
	match to:
		"Hover":
			signal_hover.emit()
			gravity_damp = GRAVITY_FLYING_DAMP
		"Glide":
			signal_gliding.emit()
			if from == "Hover" or from == "Falling":
				local_velocity += Vector2.RIGHT * facing * INIT_GLIDE_SPEED;
				local_rotation = velocity.normalized();
		"Flight":
			signal_flapping.emit()
			gravity_damp = GRAVITY_FLYING_DAMP
		"Walk":
			signal_running.emit();
		"Idle":
			signal_stop_horizontal.emit();
		"Jump":
			local_velocity.y -= JUMP_VELOCITY;
			signal_jump.emit();
		"Falling":
			if from == "Jump" and Input.is_action_pressed("jump"):
				if Input.is_action_pressed("left") or Input.is_action_pressed("right"):
					_smp.set_trigger("glide");
				else:
					_smp.set_trigger("fall_to_hover");
			else:
				signal_falling.emit()

func _on_smp_updated(state, delta):
	match state:
		"Cling":
			pass
		"Idle":
			on_drain_stamina(-1.0);
		"Walk":
			on_drain_stamina(-0.5);
		"Glide":
			if Input.is_action_pressed("up"):
				_smp.set_param("pitching", true);
			elif Input.is_action_pressed("down"):
				_smp.set_param("pitching", true);
		"Hover":
			if Input.is_action_pressed("jump") and Input.is_action_pressed("down"):
				_smp.set_trigger("fall");
		"Flight":
			if Input.is_action_pressed("up"):
				_smp.set_param("pitching", true);
			elif Input.is_action_pressed("down"):
				_smp.set_param("pitching", true);
			else:
				_smp.set_param("pitching", false);


signal signal_move_horizontal();
signal signal_stop_horizontal();
signal signal_falling();
signal signal_walking();
signal signal_running();
signal signal_set_facing(facing: int);
signal signal_jump();
signal signal_hover();
signal signal_gliding();
signal signal_flapping();
signal signal_hurt();
signal signal_dead();



var MAX_STAMINA = 1000;
var STAMINA_PER_BAR: float = 1000;
var stamina: float = MAX_STAMINA;
var stamina_drain_rate: float = -2;
signal stamina_depleted(new_value: float, max: float);
func on_drain_stamina(multiplier: float = 1.0):
	var new_stamina = clamp(stamina + stamina_drain_rate * multiplier, 0, MAX_STAMINA);
	if new_stamina != stamina:
		stamina = new_stamina;
		stamina_depleted.emit(stamina, STAMINA_PER_BAR);

