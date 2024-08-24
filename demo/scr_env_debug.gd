extends Node3D

@onready var finish = $FINISH

func _ready():
	finish.body_entered.connect(_on_StopArea_body_entered)
	
func _on_StopArea_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:  # Check if the body is a CharacterBody3D and in the "player" group
		body.stop_timer()  # Stop the timer
		
