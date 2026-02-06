extends Spatial

export var burn_time := -1.0  # -1 = forever

func ignite():
	$FireParticles.emitting = true
	
	if burn_time > 0:
		yield(get_tree().create_timer(burn_time), "timeout")
		queue_free()
