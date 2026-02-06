extends MarginContainer

func _enter_tree():
	add_to_group("level_boxes")

onready var rocket_buttons = $HBoxContainer
onready var level_button = $Button
onready var completion_icon = $Control/CompletionIcon
onready var LockIcon := $Control/LockIcon

export(int) var level_index = 0
var opened := false

signal level_selected(level_index, rocket_type)

var locked := true

const TAP_THRESHOLD := 0 # pixels

var touch_start_pos := Vector2.ZERO
var is_dragging := false

var rocket_btns := []

func _ready():
	print("🧩 READY LevelBox:", self.name, "level_index =", level_index)
	rocket_buttons.visible = false
	level_button.connect("pressed", self, "_on_level_pressed")

	# Rocket 0 = first button, Rocket 1 = second button
	for i in range(rocket_buttons.get_child_count()):
		var btn = rocket_buttons.get_child(i)
		btn.connect("pressed", self, "_on_rocket_pressed", [i])

	call_deferred("_init_after_index")

func _init_after_index():
	print("🟢 INIT LevelBox:", self.name, "level_index =", level_index)
	update_completion()
	update_lock_state()

#func _on_level_pressed():
#	print("LEVEL BOX PRESSED")
#	opened = !opened
#	rocket_buttons.visible = opened
#	if locked:
#		print("🔒 Level", level_index, "is locked")
#		return
#	open_level()

func _on_level_pressed():
	if locked:
		print("🔒 Level", level_index, "is locked")
		return

	print("LEVEL BOX PRESSED")
	opened = !opened
	rocket_buttons.visible = opened

func _on_rocket_pressed(rocket_type):
	print("🚀 Rocket selected:", rocket_type)
	#_highlight_rocket(rocket_type)
	emit_signal("level_selected", level_index, rocket_type)

func update_completion():
	completion_icon.visible = SaveData.is_level_fully_completed(level_index)

func update_lock_state():
	locked = not SaveData.is_level_unlocked(level_index)
	LockIcon.visible = locked

	# Optional visual feedback
	if locked:
		level_button.modulate = Color(1, 1, 1, 0.45)
	else:
		level_button.modulate = Color(1, 1, 1, 1)

func open_level():
	GameState.level_index = level_index
	get_tree().change_scene("res://MainScene.tscn")

func _gui_input(event):
	# Let rocket buttons handle their own input
	if rocket_buttons.visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_pos = event.position
			is_dragging = false
		else:
			if not is_dragging:
				_on_level_pressed()

	elif event is InputEventScreenDrag:
		if event.position.distance_to(touch_start_pos) > TAP_THRESHOLD:
			is_dragging = true


