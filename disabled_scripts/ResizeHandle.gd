extends Control

var resizing := false
var start_touch_pos := Vector2.ZERO
var start_size := Vector2.ZERO

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			resizing = true
			start_touch_pos = event.position
			start_size = get_parent().rect_size
		else:
			resizing = false

	elif event is InputEventScreenDrag and resizing:
		var delta = event.position - start_touch_pos
		var new_size = start_size + delta

		new_size.x = max(new_size.x, 64)
		new_size.y = max(new_size.y, 64)

		get_parent().rect_size = new_size
