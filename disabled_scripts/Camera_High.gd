extends Camera

export var offset := Vector3(0, 8, 18)
var target : Spatial = null

func set_target(node):
	target = node

func _process(_delta):
	if not target:
		return

	global_transform.origin = target.global_transform.origin + offset
	look_at(target.global_transform.origin, Vector3.UP)
