extends Control

signal swap_controls_requested(enabled)

signal next_or_switch_pressed

onready var NextOrSwitchButton := $MarginContainer/Panel/NextOrSwitchButton
onready var NextOrSwitchLabel := $MarginContainer/Panel/NextOrSwitchButton/Label

onready var ResumeButton := $MarginContainer/Panel/ResumeButton

var is_open := false

onready var ui_root := get_parent().get_node("UI_Root")

#onready var ui_root := get_tree().get_root().get_node("MainScene/UI2/UI_Root")

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS

	NextOrSwitchButton.connect("pressed", self, "_on_nextorswitch_pressed")

	var customize_btn = $MarginContainer/Panel/CustomizeControls
	if customize_btn:
		customize_btn.connect("pressed", self, "_on_CustomizeControls_pressed")
	else:
		print("CustomizeControlsButton not found!")

	# get UI_Root safely
	ui_root = get_parent().get_node("UI_Root")
	if not ui_root:
		print("UI_Root not found! Check hierarchy.")
	
func open():
	#visible = true
	#get_tree().paused = true
	#set_resume_enabled(true)
	
	if is_open:
		return

	is_open = true
	visible = true
	set_process_input(true)
	set_resume_enabled(true)
	get_tree().paused = true  

func close():
	#visible = false
	#get_tree().paused = false

	is_open = false
	visible = false
	set_process_input(false)

func _on_ResumeButton_pressed():
	get_tree().paused = false
	close()

func _on_RestartButton_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_HomeButton_pressed():
	get_tree().paused = false
	get_tree().change_scene("res://HomePage.tscn")

func _on_SoundButton_pressed():
	print("🔊 Open sound settings")

func set_resume_enabled(enabled: bool):
	if ResumeButton:
		ResumeButton.disabled = not enabled

func _on_nextorswitch_pressed():
	emit_signal("next_or_switch_pressed")

func set_next_or_switch_text(text: String):
	NextOrSwitchLabel.text = text

#func _on_CustomizeControls_pressed():
#	hide()
#	set_process_input(false)
#	pause_mode = Node.PAUSE_MODE_PROCESS  # correct way

#	if ui_root:
#		ui_root.set_controls_edit_mode(true)  

func _on_CustomizeControls_pressed():
	#visible = false   # hide menu
	close()
	
	if ui_root:
		#ui_root.set_controls_edit_mode(true)
		#ui_root.set_controls_edit_mode(true, UI_Root.EditSource.PAUSE_MENU)
		ui_root.set_controls_edit_mode(true, 2) 

func _on_SaveControls_pressed():
	if ui_root:
		ui_root.set_controls_edit_mode(false)
		ui_root.save_controls_layout()
		show() 
