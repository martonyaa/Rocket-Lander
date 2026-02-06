extends Area

func _on_GroundKillZone_body_entered(body):
	if body.is_in_group("rocket") and not body.exploded and not body.landed:
		print("💥 GroundKillZone crash")
		body.trigger_explosion(body.global_transform.origin, self)


			 