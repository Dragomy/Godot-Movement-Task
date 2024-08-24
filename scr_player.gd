extends CharacterBody3D

#Envoirenment: Physics
var gravity = 9.81 * 2

#Movement: Walking
const BASE_SPEED = 8
var CURRENT_SPEED = BASE_SPEED
const MAX_SPEED = 16.5
const ACCELERATION = 10

#Movement: jumping
const JUMP_VELOCITY = 10

#Camera: Input
var mouse_sensitivity = 0.006
var controller_sensitivity = 0.03
@onready var camera = $Camera3D

#Camera: Option Tilt
var tilt_angle = 1.9
var tilt_on = true

#Camera: Option Wobble
#The camera is moved up and down like a sinewave
var wobble_on = true
var wobble_amplitude := 0.03  # Maximum height of the wobble
var wobble_base_speed := 5.0  # Base speed of the wobble
var base_camera_height := 0.0  # To store the camera's initial Y position
var wobble_time := 0.0  # To keep track of time

#Movement: Option Ground Slam
var bump_on = true
var down_force = gravity * 100
@onready var slam_animation = $AnimatedSprite3D 

#Movement: Option Crouch
var crouch_on = true

#Movement: Option Slide
var slide_on = true
var isSliding = false
var slide_speed = MAX_SPEED * 2
var slide_slowdown = 1.01

#Movement: Option Dash
var dash_on = true
var is_dashing = false

#Movement: Option Wallslide
var wallslide_on = true
var is_wall_sliding = false
var WallSlideGravity = gravity

#Movement: Option Walljump
var walljump_on = true
var WallJumpPushBack = CURRENT_SPEED

@onready var velocity_label = $CanvasLayer/Velocity
@onready var speed_label = $CanvasLayer/Speed

func _ready():
	
	#Capture Mouse Movement
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Store the initial camera height
	base_camera_height = camera.position.y  

func _unhandled_input(event):
	#Handle Mouse Movement
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# Locks the Camera Movement between specified angles
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(87))

func _process(_delta):
	# Close game on ui_escape (Here Shift+ESC)
	if Input.is_action_just_pressed("ui_escape"):
		get_tree().quit()
	
	# Handle camera on controller
	var look_right = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_up = Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
	
	rotate_y(-look_right * controller_sensitivity)
	camera.rotate_x(-look_up * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(87))


func _physics_process(delta):
	velocity_label.text = "Velocity: " + var_to_str(velocity)
	speed_label.text = "Current Speed: " + var_to_str(CURRENT_SPEED)
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	walk(delta)
	jump()
	run()
	crouch()
	slide()
	groundslam()
	dash()
	wallslide(delta)
	walljump()
	#CAMERA
	tiltCamera()
	wobbleCamera(delta,CURRENT_SPEED)
	
	move_and_slide()

func walk(delta):
	# Get the input direction and handle the movement/deceleration
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Handle controller input
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
		velocity.x = move_toward(velocity.x, 0, CURRENT_SPEED)
		velocity.z = move_toward(velocity.z, 0, CURRENT_SPEED)
	
	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(direction * CURRENT_SPEED, ACCELERATION * delta)
	velocity.y = y_velocity

func jump():
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

var is_running = false
func run():
	if is_on_floor():
		if Input.is_action_pressed("move_fast") && CURRENT_SPEED < MAX_SPEED && !is_running:
			is_running = true
			CURRENT_SPEED = MAX_SPEED
	if Input.is_action_just_released("move_fast"):
		is_running = false
		CURRENT_SPEED = BASE_SPEED

#You cant run while Crouched so is_running is set to true this disables running
#Crouching Halfves the current speed sliding boosts the player fowards for a short duration
func crouch():
	if crouch_on:
		if Input.is_action_just_pressed("move_crouch"):
			scale.y = 0.5
			CURRENT_SPEED = CURRENT_SPEED / 2
		elif Input.is_action_pressed("move_crouch"):
			is_running = true
		elif Input.is_action_just_released("move_crouch"):
			scale.y = 1
			CURRENT_SPEED = BASE_SPEED
			is_running = false

func slide():
	if slide_on:
		if Input.is_action_pressed("move_fast") && Input.is_action_just_pressed("move_slide"):
			if !isSliding:
				isSliding = true
				CURRENT_SPEED = slide_speed
		elif Input.is_action_pressed("move_fast") && Input.is_action_pressed("move_slide") && isSliding:
			CURRENT_SPEED = CURRENT_SPEED / slide_slowdown
		elif Input.is_action_just_released("move_crouch"):
			isSliding = false
			velocity = velocity.normalized() * BASE_SPEED

var is_groundslaming = false
func groundslam():
	# If the jump youre to high above ground the animation will play mid air only fix when someone notices :) or tomorrow
	if !is_on_floor() && bump_on == true:
		if Input.is_action_just_pressed("move_bump"):
			is_groundslaming = true
			velocity.y = -100
	elif is_on_floor() && is_groundslaming:
		is_groundslaming = false
		slam_animation.play()

func dash():
	if (dash_on == true):
		if Input.is_action_just_pressed("move_dash") && !is_on_floor() && !is_dashing:
			CURRENT_SPEED *= 4
			is_dashing = true
		elif !is_on_floor() && is_dashing:
			CURRENT_SPEED = CURRENT_SPEED / 1.05
		elif is_on_floor() && is_dashing: 
			is_dashing = false
			CURRENT_SPEED = BASE_SPEED

func wallslide(delta):
	if walljump_on:
		if is_on_wall() && !is_on_floor():
			# Sepperated for Camera animation not jet implemented
			if Input.is_action_pressed("move_left"):
				is_wall_sliding = true
				velocity.y = -0.8
			elif Input.is_action_pressed("move_right"):
				is_wall_sliding = true
				velocity.y = -0.8
			else:
				is_wall_sliding = false
		else:
			is_wall_sliding = false

func walljump():
	if walljump_on:
		if is_wall_sliding and Input.is_action_pressed("move_jump"):
			velocity.y += JUMP_VELOCITY

# CAMERA 
func tiltCamera():
	if tilt_on == true:
		if Input.is_action_pressed("move_left"):
			camera.rotation_degrees.z = tilt_angle
		elif Input.is_action_pressed("move_right"):
			camera.rotation_degrees.z = -tilt_angle
		else:
			camera.rotation_degrees.z = 0

func wobbleCamera(delta: float, player_speed: float):
	if is_on_floor() && wobble_on == true:
		if Input.is_action_pressed("move_forward") || Input.is_action_pressed("move_backward") || Input.is_action_pressed("move_left") || Input.is_action_pressed("move_right"):
			wobble_time += delta * wobble_base_speed * player_speed
			# Calculate the wobble effect using a sine wave
			var wobble_effect := wobble_amplitude * sin(wobble_time)
			camera.position.y = base_camera_height + wobble_effect
		else:
			# Reset to the original height
			camera.position.y = base_camera_height
			# Reset wobble time
			wobble_time = 0.0  
