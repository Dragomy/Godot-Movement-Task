extends CharacterBody3D

#- @onready ----------
@onready var camera = $Camera3D
@onready var slam_animation = $AnimatedSprite3D 
@onready var velocity_label = $CanvasLayer/Velocity
@onready var speed_label = $CanvasLayer/Speed
@onready var time_label: Label = $CanvasLayer/Time 
@onready var ray_left = $RayCastLeft
@onready var ray_right = $RayCastRight
@onready var syringe = $Camera3D/ObjSyringe

#- const ----------
const gravity = 9.81 * 2
const BASE_SPEED = 8.0
#const MAX_SPEED = 16.0
const ACCELERATION = 10.0
const JUMP_VELOCITY = 10.0
const max_jumps = 3

#- var: boolean ----------
var timer_active: bool = false

var tilt_on: bool = true
var wobble_on: bool = true

var is_sliding: bool = false
var is_dashing: bool = false
var is_wall_sliding: bool = false
var is_running: bool = false
var is_groundslaming: bool = false
var is_on_drugs: bool = false 

#- var: float -------
var current_speed = BASE_SPEED

var mouse_sensitivity = 0.006
var controller_sensitivity = 0.03

var wobble_amplitude := 0.03  # Maximum height of the wobble
var wobble_base_speed := 5.0  # Base speed of the wobble
var base_camera_height := 0.0  # To store the camera's initial Y position
var wobble_time := 0.0  # To keep track of time

var jump_count
var tilt_angle = 1.9
var slide_slowdown = 1.01
var elapsed_time = 0.0



func _ready():
	timer_active = true
	syringe.hide()
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
	# Handle camera on controller
	var look_right = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_up = Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
	
	rotate_y(-look_right * controller_sensitivity)
	camera.rotate_x(-look_up * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(87))
	

func _physics_process(delta):
	# Close game on ui_escape (Here Shift+ESC)
	if Input.is_action_just_pressed("ui_escape"):
		get_tree().quit()
		
	velocity_label.text = "Velocity: " + var_to_str(velocity)
	speed_label.text =var_to_str(current_speed) + "m/s"
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	#- Time ---------
	update_elapsed_time(delta)
	
	#- Respawn ----------
	respawn()
	
	#- Movement ----------
	walk(delta)
	run()
	jump()
	crouch()
	slide()
	groundslam()
	dash()
	wallrun(delta)
	drugs()
	
	#- Camera ----------
	tiltCamera()
	wobbleCamera(delta,current_speed)
	
	
	move_and_slide()



#- Time ----------
func stop_timer() -> void:
	timer_active = false 

func update_elapsed_time(delta: float) -> void:
	if timer_active:
		elapsed_time += delta
		time_label.text = "Time: %.2f seconds" % elapsed_time



#- Respwan ----------
func respawn():
	if Input.is_action_just_pressed("respawn"):
		global_transform.origin = Vector3(0, 0, 0)
		velocity = Vector3.ZERO 
		elapsed_time = 0
		timer_active = true #Reset timer on respawn



#- Movement ----------
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
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	var y_velocity = velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(direction * current_speed, ACCELERATION * delta)
	velocity.y = y_velocity
	
var can_run = true
func run():
	if can_run && !is_crouching:
		if Input.is_action_pressed("move_fast"):
			is_running = true
			current_speed = BASE_SPEED * 2
		elif Input.is_action_just_released("move_fast"):
			is_running = false
			current_speed = BASE_SPEED

func jump():
	if Input.is_action_just_pressed("move_jump") && jump_count < max_jumps:
		jump_count += 1
		velocity.y = JUMP_VELOCITY
	elif is_on_floor():
		jump_count = 0

#You cant run while Crouched so is_running is set to true this disables running
#Crouching Halfves the current speed sliding boosts the player fowards for a short duration
var save_crouch_input_speed
var is_crouching = false
func crouch():
	if Input.is_action_just_pressed("move_crouch") && !is_running && !is_crouching:
		is_crouching = true
		scale.y = 0.5
		save_crouch_input_speed = current_speed
		current_speed = current_speed / 2
	elif Input.is_action_just_pressed("move_crouch") && Input.is_action_just_pressed("move_fast"):
		scale.y = 1
		current_speed = save_crouch_input_speed
		is_crouching = false
	elif Input.is_action_just_released("move_crouch") && is_crouching:
		scale.y = 1
		current_speed = save_crouch_input_speed
		is_crouching = false
		
var save_slide_input_speed
func slide():
	if Input.is_action_just_pressed("move_slide") && Input.is_action_pressed("move_fast") && !is_sliding && is_running:
		save_slide_input_speed = current_speed
		is_sliding = true
		can_run = false
		scale.y = 0.5
		current_speed = current_speed * 1.5
	elif Input.is_action_pressed("move_slide") && Input.is_action_pressed("move_fast") && is_sliding && current_speed > save_slide_input_speed:
		#await get_tree().create_timer(0.5).timeout
		current_speed -= 0.5
		
	elif (Input.is_action_just_released("move_slide") || Input.is_action_just_released("move_fast")) && is_sliding:
		
		scale.y = 1
		current_speed = save_slide_input_speed
		is_sliding = false
		can_run = true
		
func groundslam():
	# If the jump youre to high above ground the animation will play mid air only fix when someone notices :) or tomorrow
	if !is_on_floor():
		if Input.is_action_just_pressed("move_bump"):
			is_groundslaming = true
			velocity.y = -100
	elif is_on_floor() && is_groundslaming:
		is_groundslaming = false
		slam_animation.play()

func dash():
	if Input.is_action_just_pressed("move_dash") && !is_on_floor() && !is_dashing:
		velocity = Vector3(velocity.x * (current_speed / 2),0,velocity.z * (current_speed / 2))
		is_dashing = true
	elif is_dashing && is_on_floor():
		is_dashing = false

func wallrun(delta):
		if ( ray_left.is_colliding() || ray_right.is_colliding() ) && !is_on_floor():
			velocity.y = -0.8
			is_wall_sliding = true
			if Input.is_action_pressed("move_right") && ray_left.is_colliding():
				velocity *= 3
				velocity.y += JUMP_VELOCITY #* 2
				is_wall_sliding = false
			elif Input.is_action_pressed("move_left") && ray_right.is_colliding():
				velocity *= 3
				velocity.y += JUMP_VELOCITY #* 2
				is_wall_sliding = false
			elif Input.is_action_pressed("move_jump"):
				velocity.y += JUMP_VELOCITY
				is_wall_sliding = false
		else: 
			is_wall_sliding = false
			
func drugs():
	if Input.is_action_just_pressed("action_syringe") && !is_on_drugs:
		is_on_drugs = true
		can_run = false
		syringe.show()
		var save = current_speed
		current_speed = current_speed * 2
		await get_tree().create_timer(5.0).timeout
		syringe.hide()
		current_speed = save
		is_on_drugs = false
		can_run = true
		

#- Camera ----------
func tiltCamera():
	if tilt_on == true:
		if Input.is_action_pressed("move_left"):
			camera.rotation_degrees.z = tilt_angle
		elif Input.is_action_pressed("move_right"):
			camera.rotation_degrees.z = -tilt_angle
		elif ray_left.is_colliding() && is_wall_sliding:
			camera.rotation_degrees.z = -tilt_angle * 4
		elif ray_right.is_colliding() && is_wall_sliding:
			camera.rotation_degrees.z = tilt_angle * 4
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
