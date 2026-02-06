extends TextureButton

export(float) var max_radius := 80.0
export(float) var deadzone := 0.15

onready var knob := $JoystickKnob

var edit_mode := false
var dragging := false
var drag_offset := Vector2.ZERO

var touch_id := -1
var output := Vector2.ZERO

const SIZE_STEP := Vector2(20, 20)
const MIN_SIZE := Vector2(80, 80)
const MAX_SIZE := Vector2(800, 800)

var last_tap_time := 0.0
const DOUBLE_TAP_TIME := 0.3

var radius := 0.0

func _ready():
	radius = rect_size.x * 0.5
	pause_mode = Node.PAUSE_MODE_PROCESS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center_knob()
	_update_knob_size()

func _process(delta):
	print(get_direction())
	apply_actions()

func _center_knob():
	output = Vector2.ZERO
	knob.rect_position = rect_size * 0.5 - knob.rect_size * 0.5

# 🔁 same API you already use
func set_edit_mode(enabled: bool):
	edit_mode = enabled
	dragging = false
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if edit_mode
		else Control.MOUSE_FILTER_PASS
	)

#func _gui_input(event):
	#if event is InputEventMouseButton:
	#	if event.button_index == BUTTON_LEFT:
	#		dragging = event.pressed
	#		if not dragging:
	#			_center_knob()

	#if event is InputEventMouseMotion and dragging:
	#	_move_knob(event.position)

func _gui_input(event):
	# ================= EDIT MODE =================
	if edit_mode:
		_handle_edit(event)
		return

	# =============== JOYSTICK MODE ===============
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			dragging = event.pressed
			if not dragging:
				_center_knob()

	elif event is InputEventMouseMotion and dragging:
		_move_knob(event.position)

#func _move_knob(pos: Vector2):
#	var center := rect_size * 0.5
#	var delta := pos - center

#	if delta.length() > radius:
#		delta = delta.normalized() * radius

#	knob.rect_position = center + delta - knob.rect_size * 0.5

func _move_knob(pos: Vector2):
	var center := rect_size * 0.5
	var delta := pos - center

	var max_radius := radius
	var dist := delta.length()

	if dist > max_radius:
		delta = delta.normalized() * max_radius
		dist = max_radius

	# NORMALIZED OUTPUT (-1 to 1)
	if max_radius > 0:
		output = delta / max_radius
	else:
		output = Vector2.ZERO

	knob.rect_position = center + delta - knob.rect_size * 0.5

func get_direction() -> Vector2:
	if output.length() < deadzone:
		return Vector2.ZERO
	return output

func _handle_edit(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			var now := OS.get_ticks_msec() / 1000.0
			var dt := now - last_tap_time

			if dt <= DOUBLE_TAP_TIME:
				# DOUBLE TAP → INCREASE SIZE
				rect_size += SIZE_STEP
			else:
				# SINGLE TAP → DECREASE SIZE
				rect_size -= SIZE_STEP

			rect_size.x = clamp(rect_size.x, MIN_SIZE.x, MAX_SIZE.x)
			rect_size.y = clamp(rect_size.y, MIN_SIZE.y, MAX_SIZE.y)

			last_tap_time = now

			_update_knob_size()
			_center_knob()

			# start dragging BASE
			dragging = true
			drag_offset = event.position

		else:
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		rect_position += event.relative

func _update_knob(global_pos: Vector2):
	# ✅ convert to LOCAL space (CRITICAL)
	var local_pos = global_pos - rect_global_position

	var center = rect_size * 0.5
	var offset = local_pos - center
	offset = offset.clamped(center.x)

	output = offset / center.x
	knob.rect_position = center + offset - knob.rect_size * 0.5

func _reset():
	touch_id = -1
	output = Vector2.ZERO
	_center_knob()

#func _update_knob_size():
	# UPDATE BASE RADIUS (CRITICAL)
#	radius = rect_size.x * 0.5

	# KNOB SIZE RELATIVE TO BASE
#	var knob_radius = radius * 0.45   # adjust feel here

	#knob.rect_size = Vector2.ONE * knob_radius
	#knob.rect_position = rect_size * 0.5 - knob.rect_size * 0.5

func _update_knob_size():
	# update base radius
	radius = rect_size.x * 0.5

	# knob scales relative to base
	var knob_size := rect_size * 0.45

	# FORCE TextureRect to obey size
	knob.rect_min_size = knob_size
	knob.rect_size = knob_size

	# keep centered
	knob.rect_position = rect_size * 0.5 - knob_size * 0.5

func apply_actions():
	# RELEASE EVERYTHING FIRST (very important)
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_left")
	Input.action_release("ui_right")

	var dir := get_direction()

	if dir == Vector2.ZERO:
		return

	# Y AXIS (Godot: up is negative)
	if dir.y < -0.4:
		Input.action_press("ui_up")
	elif dir.y > 0.4:
		Input.action_press("ui_down")

	# X AXIS
	if dir.x < -0.4:
		Input.action_press("ui_left")
	elif dir.x > 0.4:
		Input.action_press("ui_right")
