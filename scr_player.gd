extends CharacterBody3D

var BASE_SPEED = 6.0
var SPEED = 6.0
var MAX_SPEED = 15

const JUMP_VELOCITY = 7
const ACCELERATION = 4.0
const FRICTION = 0.1
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var mouse_sensitivity = 0.006
var controller_sensitivity = 0.03
@onready var camera = $Camera3D

@export var tiltAngle = 1.5
@export var tiltOn = true

@export var wobbleOn = true
@export var wobble_amplitude := 0.03  # Maximum height of the wobble
@export var wobble_base_speed := 5.0  # Base speed of the wobble
var base_camera_height := 0.0  # To store the camera's initial Y position
var wobble_time := 0.0  # To keep track of time

@export var bumpOn = true
@export var crouchOn = true
@export var slideOn = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_camera_height = camera.position.y  # Store the initial camera height

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# So you can't 360 your head
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(87))

func _process(_delta):
	# Close game on Escape
	if Input.is_action_just_pressed("ui_escape"):
		get_tree().quit()
	
	# Handle controller rotation (Right analog stick)
	var look_right = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_up = Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
	
	rotate_y(-look_right * controller_sensitivity)
	camera.rotate_x(-look_up * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(87))
	
	run()
	bump()
	crouch()
	slide()
	tiltCamera(tiltAngle)
	wobbleCamera(_delta, SPEED)

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Handle controller input (Left analog stick)
	var controller_input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)
	
	if controller_input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(controller_input_dir.x, 0, controller_input_dir.y)).normalized()

	if direction:
		# Apply movement
		pass
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(direction * SPEED, ACCELERATION * delta)
	if direction.length() == 0 and velocity.length() < FRICTION:
		velocity = Vector3.ZERO
	velocity.y = y_velocity

	move_and_slide()

func crouch():
	if (crouchOn == true):
		if Input.is_action_pressed("move_crouch"):
			scale.y = 0.5
			SPEED = SPEED/2
		else:
			scale.y = 1.047

var isSliding = false

func slide():
	if (slideOn == true):
		if SPEED <= BASE_SPEED:
			isSliding = false
			SPEED = BASE_SPEED
		
		if Input.is_action_pressed("move_crouch") && Input.is_action_pressed("move_fast") && isSliding == false:
			isSliding = true
			SPEED = SPEED*100
		elif isSliding == true:
			SPEED = SPEED*0.01
	
func run():
	if is_on_floor():
		if Input.is_action_pressed("move_fast"):
			SPEED = MAX_SPEED
		else:
			SPEED = BASE_SPEED

func bump():
	if !is_on_floor() && bumpOn == true:
		if Input.is_action_just_pressed("move_bump"):
			velocity.y = -100

func tiltCamera(tiltAngle):
	if tiltOn == true:
		if Input.is_action_pressed("move_left"):
			camera.rotation_degrees.z = tiltAngle
		elif Input.is_action_pressed("move_right"):
			camera.rotation_degrees.z = -tiltAngle
		else:
			camera.rotation_degrees.z = 0

func wobbleCamera(delta: float, player_speed: float):
	if is_on_floor() && wobbleOn == true:
		if Input.is_action_pressed("move_forward") || Input.is_action_pressed("move_backward") || Input.is_action_pressed("move_left") || Input.is_action_pressed("move_right"):
			# Update the wobble time
			wobble_time += delta * wobble_base_speed * player_speed

			# Calculate the wobble effect using a sine wave
			var wobble_effect := wobble_amplitude * sin(wobble_time)
			camera.position.y = base_camera_height + wobble_effect
		else:
			# Reset to the original height
			camera.position.y = base_camera_height
			wobble_time = 0.0  # Reset wobble time to avoid discontinuity
