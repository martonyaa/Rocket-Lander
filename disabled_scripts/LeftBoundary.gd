extends Area

func _on_Boundary_body_entered(body):
	if body.is_in_group("rocket"):
		body.trigger_out_of_bounds()
