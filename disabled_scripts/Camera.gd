extends Camera

#onready var rocket = get_node("rocket3") 
export (NodePath) var rocket_path
onready var rocket = get_node(rocket_path)


# Offset: in front of rocket (positive Z)
var offset = Vector3(0, 0, 10)  # adjust distance in front of rocket
var follow_speed = 0.2          # smoothing factor

func _physics_process(delta):
    if rocket:
        # Position camera in front of rocket
        var target_pos = rocket.global_transform.origin + offset
        
        # Smoothly move camera to target
        global_transform.origin = global_transform.origin.linear_interpolate(target_pos, follow_speed)
        
        # Make camera look directly at rocket
        look_at(rocket.global_transform.origin, Vector3.UP)
