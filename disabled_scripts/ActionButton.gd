extends TextureButton

export(String) var action_name = ""

var edit_mode := false
var dragging := false
var drag_offset := Vector2.ZERO

var last_tap_time := 0.0
const DOUBLE_TAP_TIME := 0.3  # max seconds between taps
const SIZE_STEP := Vector2(30, 30)  # change per tap
const MIN_SIZE := Vector2(100, 100)
const MAX_SIZE := Vector2(1000, 1000)

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS   # 🔥 REQUIRED
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 🔥 IMPORTANT

	assert(action_name != "", "ActionButton: action_name not set")

	connect("button_down", self, "_on_button_down")
	connect("button_up", self, "_on_button_up")

func _on_button_down():
	print("👇 button_down", action_name, "edit_mode =", edit_mode)
	if edit_mode:
		return
	Input.action_press(action_name)

func _on_button_up():
	if edit_mode:
		return
	Input.action_release(action_name)

# 🔁 CALLED BY UI_Root
func set_edit_mode(enabled: bool) -> void:
	print("✏️ EDIT MODE:", action_name, enabled)
	edit_mode = enabled
	dragging = false

	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if edit_mode
		else Control.MOUSE_FILTER_PASS
	)

	# 🔥 IMPORTANT: reset stuck press state
	if not enabled:
		set_pressed(false)

# drag + resize in edit mode
#func _gui_input(event):
#	if not edit_mode:
#		return

#	if event is InputEventMouseButton:
#		if event.button_index == BUTTON_LEFT:
#			if event.pressed:
#				dragging = true
#				drag_offset = rect_global_position - event.global_position
#			else:
#				dragging = false
#		elif event.button_index == BUTTON_WHEEL_UP:
#			resize_button(1.05)
#		elif event.button_index == BUTTON_WHEEL_DOWN:
#			resize_button(0.95)

#	elif event is InputEventMouseMotion and dragging:
#		rect_global_position = event.global_position + drag_offset

func _gui_input(event):
	if not edit_mode:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var current_time = OS.get_ticks_msec() / 1000.0
			var delta = current_time - last_tap_time

			if delta <= DOUBLE_TAP_TIME:
				# DOUBLE TAP → increase size
				rect_size += SIZE_STEP
			else:
				# SINGLE TAP → decrease size
				rect_size -= SIZE_STEP

			# clamp size
			rect_size.x = clamp(rect_size.x, MIN_SIZE.x, MAX_SIZE.x)
			rect_size.y = clamp(rect_size.y, MIN_SIZE.y, MAX_SIZE.y)

			last_tap_time = current_time

			# prepare for drag
			dragging = true

			# ⚡ convert touch pos to local parent coords
			drag_offset = get_parent().get_local_mouse_position() - rect_position

		else:
			dragging = false

	elif event is InputEventScreenDrag and dragging:
		# ⚡ convert drag pos to local parent coords
		rect_position = get_parent().get_local_mouse_position() - drag_offset

# helper to resize button
func resize_button(factor: float) -> void:
	rect_size *= factor
	rect_scale = Vector2.ONE  # reset scale to keep hitbox correct


