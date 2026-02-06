extends Control

onready var LeftPanel := $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel
onready var RightPanel := $MarginContainer/VBoxContainer/HBoxContainer/RightPanel

var swapped := false
var left_pos := Vector2()
var right_pos := Vector2()

var initialized := false 

# 🔧 YOU control this value
export var left_panel_x_offset := -100

var controls_edit_mode := false

onready var DoneButton := $DoneButton

enum EditSource {
	NONE,
	TUTORIAL,
	PAUSE_MENU
}

var edit_source = EditSource.NONE

func _ready():
	load_controls_layout()

	DoneButton.visible = false
	DoneButton.pause_mode = Node.PAUSE_MODE_PROCESS
	DoneButton.connect("pressed", self, "_on_done_pressed")
	
#func set_controls_edit_mode(enabled: bool) -> void:
func set_controls_edit_mode(enabled: bool, source := EditSource.NONE):
	controls_edit_mode = enabled
	print("✏️ Controls edit mode =", enabled)
	edit_source = source

	#DoneButton.visible = enabled

	# forward to all buttons
	for btn in get_tree().get_nodes_in_group("control_buttons"):
		if btn.has_method("set_edit_mode"):
			btn.set_edit_mode(enabled)

	# 🔥 Done button logic
	if has_node("DoneButton"):
		var done_btn = $DoneButton
		done_btn.visible = enabled and source == EditSource.PAUSE_MENU

func save_controls_layout() -> void:
	var data := {}

	for child in get_children():
		if child is TextureButton:
			data[child.name] = {
				"pos": child.rect_position,
				"size": child.rect_size
			}

	SaveData.set_controls_layout(data)

func load_controls_layout() -> void:
	var data = SaveData.get_controls_layout()
	if data == null:
		return

	for child in get_children():
		if child is TextureButton and data.has(child.name):
			child.rect_position = data[child.name]["pos"]
			child.rect_size = data[child.name]["size"]

			# 📍 POINT 3 — FIX KNOB AFTER SIZE RESTORE
			if child.has_method("_update_knob_size"):
				child._update_knob_size()

func get_controls_buttons() -> Array:
	# return an array of all Control buttons user can edit
	return [
		$ui_left,
		$ui_right,
		$ui_up,
		$ui_down
	]

func _on_done_pressed():
	set_controls_edit_mode(false)
	save_controls_layout()

	# show pause menu again
	var pause_menu = get_parent().get_node("PauseMenu")
	if pause_menu:
		pause_menu.open()
