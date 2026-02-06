extends Spatial

# ROCKET SCENES
export(PackedScene) var Rocket1Scene  # Rocket3
export(PackedScene) var Rocket2Scene  # Rocket4

# SPAWN POSITIONS
export var Rocket3Spawn : Vector3
export var Rocket4Spawn : Vector3

# NODES IN MAIN SCENE
onready var ArmPadNode = $ArmPad
onready var LandingPadNode = $LandingPad
onready var CameraHigh = $HighCamViewport/Camera_High
onready var CameraLow = $Camera_Low
onready var UI = $UI
onready var UI2 =$UI2
onready var FuelBar = $UI2/Control/MarginContainer/VBoxContainer/Control2/FuelBar
onready var LevelController = $LevelController
onready var WindMeter = $UI2/Control/MarginContainer/VBoxContainer/Control3/WindMeter
onready var HeatMeter = $UI2/Control/MarginContainer/VBoxContainer/Control4/HeatMeter
onready var LeftPanel  = $UI2/UI_Root/MarginContainer/VBoxContainer/HBoxContainer/LeftPanel
onready var RightPanel = $UI2/UI_Root/MarginContainer/VBoxContainer/HBoxContainer/RightPanel

# STATE
var active_rocket := 0 # 1 = Rocket3, 2 = Rocket4
var rocket_instance : RigidBody = null

onready var PauseMenu = $UI2/PauseMenu
var controls_swapped := false

onready var UI_Root := $UI2/UI_Root

var pause_requested := false

onready var EngineStatusLabel: Label = $UI2/Control/MarginContainer/VBoxContainer/Control/EngineStatusLabel

onready var tutorial_overlay = $UI2/TutorialOverlay

func _ready():
	print("✅ MainScene READY")

	print("UI2 =", UI2)
	print("FuelBar =", FuelBar)
	print("PauseMenu =", PauseMenu)

	print("🎯 Selected level (MainScene):", GameState.level_index)
	print("🎯 Selected rocket (MainScene):", GameState.rocket_type)

	active_rocket = GameState.rocket_type
	LevelController.current_index = GameState.level_index

	var tutorial_ui = UI2.get_node("TutorialOverlay")

	# Pause the game
	get_tree().paused = true

	# --- SHOW TUTORIAL ONLY ONCE ---
	if not SaveData.has_seen_tutorial(0, 0):
		get_tree().paused = true
		tutorial_ui.show()
		tutorial_ui.connect("tutorial_finished", self, "_on_tutorial_finished", [], CONNECT_ONESHOT)
		tutorial_ui.connect("tutorial_skipped", self, "_on_tutorial_finished", [], CONNECT_ONESHOT)
	else:
		get_tree().paused = false

	#var label = UI2.get_node("EngineStatusLabel")
	var label = $UI2/Control/MarginContainer/VBoxContainer/Control/EngineStatusLabel
	label.visible = false
	label.text = ""

	print("✅ MainScene READY")
	print("Paused?", get_tree().paused)

	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	load_controls_layout()

	print("🚀 Spawning rocket now")

	spawn_active_rocket()

	spawn_active_rocket()

	PauseMenu.connect(
		"swap_controls_requested",
		self,
		#"_on_swap_controls_requested"
		"_on_swap_requested"
	)

	PauseMenu.connect(
		"next_or_switch_pressed",
		self,
		"_on_pause_next_or_switch_pressed"
	)

	if active_rocket == 0 and rocket_instance.has_method("set_arm_pad"):
		rocket_instance.set_arm_pad(ArmPadNode)

	update_pause_button_text()

# SPAWN ROCKET DYNAMICALLY
func spawn_active_rocket():
	print("🚀 spawn_active_rocket CALLED")

	print("active_rocket =", active_rocket)
	print("rocket3Scene =", Rocket1Scene)
	print("rocket4Scene =", Rocket2Scene)

	# Remove existing rocket
	if rocket_instance:
		rocket_instance.queue_free()
		rocket_instance = null

	var rocket_scene : PackedScene = null
	var spawn_position : Vector3
	var target_pad_node : Node
	var collision_layer : int
	var collision_mask : int

	#if active_rocket == 1:  # Rocket3
	#	rocket_scene = Rocket1Scene
	#	spawn_position = ArmPadNode.global_transform.origin + Vector3(0, 200, 0)
	#	target_pad_node = ArmPadNode
	#	collision_layer = 1
	#	collision_mask = 1  # Collides only with ArmPad
	#else:  # Rocket4
	#	rocket_scene = Rocket2Scene
	#	spawn_position = LandingPadNode.global_transform.origin + Vector3(0, 200, 0)
	#	target_pad_node = LandingPadNode
	#	collision_layer = 2
	#	collision_mask = 2  # Collides only with LandingPad

	#if not rocket_scene:
	#	push_error("No rocket scene assigned for active_rocket=" + str(active_rocket))
		#return

	# GameState mapping:
	# 0 = Rocket1
	# 1 = Rocket2
	match active_rocket:
		0:
			rocket_scene = Rocket1Scene
			spawn_position = ArmPadNode.global_transform.origin + Vector3(0, 200, 0)
			target_pad_node = ArmPadNode
			collision_layer = 1
			collision_mask = 1
		1:
			rocket_scene = Rocket2Scene
			spawn_position = LandingPadNode.global_transform.origin + Vector3(0, 200, 0)
			target_pad_node = LandingPadNode
			collision_layer = 2
			collision_mask = 2
		_:
			push_error("❌ Invalid rocket type: " + str(active_rocket))
			return

	# Instance rocket
	rocket_instance = rocket_scene.instance()
	add_child(rocket_instance)
	rocket_instance.global_transform.origin = spawn_position

	# Reset physics
	rocket_instance.sleeping = false
	rocket_instance.linear_velocity = Vector3.ZERO
	rocket_instance.angular_velocity = Vector3.ZERO
	rocket_instance.set_physics_process(true)

	# Assign WindMeter
	#var wind_meter = UI2.get_node("WindMeter")
	#if wind_meter:
		#rocket_instance.wind_meter = wind_meter

	if rocket_instance.has_signal("wind_strength_changed"):
		rocket_instance.connect(
			"wind_strength_changed",
			#UI2.get_node("WindMeter"),
			UI2.get_node("Control/MarginContainer/VBoxContainer/Control3/WindMeter"),
			"set_wind_strength"
		)

		rocket_instance.connect(
			"wind_direction_changed",
			#wind_meter,
			#UI2.get_node("WindMeter"),
			UI2.get_node("Control/MarginContainer/VBoxContainer/Control3/WindMeter"),
			"set_wind_direction"
		)

	# Engine failure text
	if rocket_instance.has_signal("engine_failure_text"):
		rocket_instance.connect(
			"engine_failure_text",
			self,
			"_on_engine_failure_text"
		)

	# 🔥 HEAT METER CONNECTION
	if HeatMeter:
		HeatMeter.value = 0
		HeatMeter.visible = false

		if rocket_instance.has_signal("heat_changed"):
			rocket_instance.connect(
				"heat_changed",
				HeatMeter,
				#"set_value"
				"set_heat"
			)

		if rocket_instance.has_signal("overheat_exploded"):
			rocket_instance.connect(
				"overheat_exploded",
				self,
				"_on_overheat_exploded"
			)

	#if rocket_instance.has_signal("fatal_event"):
	#	rocket_instance.connect(
	#		"fatal_event",
	#		self,
	#		"_on_rocket_fatal_event"
	#	)

	if rocket_instance.has_signal("armpad_ignited"):
		rocket_instance.connect(
			"armpad_ignited",
			self,
			"_on_armpad_ignited"
		)

	# Connect the fuel_changed signal to the FuelBar
	if rocket_instance.has_signal("fuel_changed"):
		rocket_instance.connect("fuel_changed", FuelBar, "set_fuel")
		FuelBar.set_fuel(rocket_instance.fuel, rocket_instance.max_fuel)

	# --- NEW: connect fatal_event and landing signals to mute fuel alert ---
	if rocket_instance.has_signal("fatal_event"):
		rocket_instance.connect("fatal_event", FuelBar, "_on_rocket_event")  

	if rocket_instance.has_signal("armpad_ignited"):
		rocket_instance.connect("armpad_ignited", FuelBar, "_on_rocket_event")  

	if rocket_instance.has_signal("fatal_event"):
		rocket_instance.connect("fatal_event", HeatMeter, "mute_alert")

	if rocket_instance.has_signal("armpad_ignited"):
		rocket_instance.connect("armpad_ignited", HeatMeter, "mute_alert")

	if rocket_instance.has_signal("landingpad_ignited"):
		rocket_instance.connect("landingpad_ignited", HeatMeter, "mute_alert")

	if rocket_instance.has_signal("overheat_exploded"):
		rocket_instance.connect("overheat_exploded", HeatMeter, "mute_alert")

	# Set collision layers/masks
	if rocket_instance.has_method("set_collision_layer"):
		rocket_instance.collision_layer = collision_layer
		rocket_instance.collision_mask = collision_mask

	# Assign target pad
	if rocket_instance.has_method("set_target_pad"):
		rocket_instance.set_target_pad(target_pad_node)

	# If Rocket3, assign armpad as well
	if active_rocket == 1 and rocket_instance.has_method("set_arm_pad"):
		rocket_instance.set_arm_pad(ArmPadNode)

	# Enable camera & UI
	#CameraHigh.current = true
	#CameraLow.current = false

	CameraLow.current = true

	UI.visible = true

	# Enable camera to follow rocket
	if rocket_instance:
		if CameraHigh.has_method("set_target"):
			CameraHigh.set_target(rocket_instance)
		if CameraLow.has_method("set_target"):
			CameraLow.set_target(rocket_instance)

	# APPLY LEVEL DIFFICULTY 
	if LevelController:
		LevelController.apply_level(rocket_instance)

	# SHOW HEAT METER ONLY IF LEVEL USES IT
	if LevelController:
		var level = LevelController.get_current_level()
		if level and level.overheat_enabled:
			HeatMeter.visible = true
			HeatMeter.max_value = level.max_heat
		else:
			HeatMeter.visible = false

#func _on_engine_failure_text(msg):
#	var label = UI2.get_node("EngineStatusLabel")

	# Clear message
#	if msg == "":
#		label.text = ""
#		label.visible = false
#		return

	# Show message
#	label.text = msg
#	label.visible = true

	# Auto-hide after 2.5 seconds
#	yield(get_tree().create_timer(2.5), "timeout")

	# Only hide if nothing new replaced it
#	if label.text == msg:
#		label.visible = false

func _on_engine_failure_text(msg):
	#var label = UI2.get_node("EngineStatusLabel")
	var label = UI2.get_node("Control/MarginContainer/VBoxContainer/Control/EngineStatusLabel")
	
	# Clear message
	if msg == "":
		label.text = ""
		label.visible = false
		return

	label.text = msg
	label.visible = true

	# 🚫 Do NOT auto-hide game over messages
	if (
		msg.find("GAME OVER") != -1
		or msg.find("OUT OF BOUNDS!") != -1
		or msg.find("ROCKET LANDED") != -1   # ✅ ADD THIS
	):
		return

func _on_overheat_exploded():
	print("💥 OVERHEAT EXPLOSION received in MainScene")

	# Optional UI cleanup
	if has_node("UI2/HeatMeter"):
		$UI2/HeatMeter.visible = false

func _on_RightBoundary_body_entered(body):
	if body.is_in_group("rocket"):
		print("🚨 Rocket went out of bounds - RIGHT!")
		game_over("OUT OF BOUNDS! — GAME OVER")
		#open_game_over_menu()
		#request_pause_menu()
		request_pause_menu_with_message("OUT OF BOUNDS! — GAME OVER", false)

func _on_LeftBoundary_body_entered(body):
	if body.is_in_group("rocket"):
		print("🚨 Rocket went out of bounds — LEFT!")
		game_over("OUT OF BOUNDS! — GAME OVER")
		#open_game_over_menu()
		#request_pause_menu()
		request_pause_menu_with_message("OUT OF BOUNDS! — GAME OVER", false)

func _on_BackBoundary_body_entered(body):
	if body.is_in_group("rocket"):
		print("🚨 Rocket went out of bounds — BACK!")
		game_over("OUT OF BOUNDS! — GAME OVER")
		#open_game_over_menu()
		#request_pause_menu()
		request_pause_menu_with_message("OUT OF BOUNDS! — GAME OVER", false)

#func game_over():
	#print("💥 GAME OVER")

	#if game_over_label:
	#	game_over_label.visible = true
	#else:
	#	push_error("❌ GameOverLabel not found!")

	#for rocket in get_tree().get_nodes_in_group("rocket"):
		#rocket.sleeping = true
		#rocket.set_physics_process(false)

func game_over(msg := "GAME OVER"):
	print("💥 GAME OVER")
	print("❌ GAME OVER TRIGGERED IMMEDIATELY:", msg)

	# Reuse engine status label
	_on_engine_failure_text(msg)

	# Freeze all rockets
	for rocket in get_tree().get_nodes_in_group("rocket"):
		rocket.sleeping = true
		rocket.set_physics_process(false)

func _on_swap_requested(_unused):
	var new_state = not UI_Root.swapped
	UI_Root.apply_swap(new_state)
	#PauseMenu.open()

#func _on_rocket_fatal_event(reason):
#	print("☠️ Rocket fatal event:", reason)
	#open_game_over_menu()
#	request_pause_menu()

#func open_game_over_menu():
#	get_tree().paused = true

#	PauseMenu.open()
#	PauseMenu.set_resume_enabled(false)

func request_pause_menu():
	if pause_requested:
		return

	pause_requested = true
	call_deferred("_open_pause_menu_safely")

#func request_pause_menu_with_message(message: String, can_resume: bool):
#	if pause_requested:
#		return

#	pause_requested = true
#	call_deferred("_open_pause_menu_with_message", message, can_resume)

#func _open_pause_menu_with_message(message: String, can_resume: bool) -> void:
	# ⏱ wait 3 seconds BEFORE pausing (Godot 3 way)
#	yield(get_tree().create_timer(3.0), "timeout")

	# safety: scene might be gone
#	if not is_instance_valid(self):
#		return

#	pause_requested = false

#	if not is_instance_valid(PauseMenu):
#		push_error("PauseMenu missing")
#		return

#	if PauseMenu.is_open:
#		return

	# reuse EngineStatusLabel
#	EngineStatusLabel.text = message
#	EngineStatusLabel.visible = true

#	get_tree().paused = true
#	PauseMenu.open()
#	PauseMenu.set_resume_enabled(can_resume)


func request_pause_menu_with_message(message: String, can_resume: bool):
	if pause_requested:
		return
	pause_requested = true

	# Show message immediately (tree still running)
	EngineStatusLabel.text = message
	EngineStatusLabel.visible = true

	# ⏱ Delay pause by 3 seconds
	var timer := get_tree().create_timer(3.0)
	timer.connect(
		"timeout",
		self,
		"_open_pause_menu_after_delay",
		[can_resume],
		CONNECT_ONESHOT
	)

func _open_pause_menu_after_delay(can_resume: bool):
	pause_requested = false

	if not is_instance_valid(PauseMenu):
		push_error("PauseMenu missing")
		return

	if PauseMenu.is_open:
		return

	get_tree().paused = true
	PauseMenu.open()
	PauseMenu.set_resume_enabled(can_resume)
	update_pause_button_text()

#func _open_pause_menu_safely():
	#pause_requested = false

	#if not is_instance_valid(PauseMenu):
	#	push_error("PauseMenu missing")
	#	return

	#if PauseMenu.is_open:
	#	return

	#get_tree().paused = true
	#PauseMenu.open()

func _on_armpad_ignited():
	print("🔥 Armpad ignited — delaying pause menu safely")

	var timer := get_tree().create_timer(3.0)
	timer.connect("timeout", self, "_open_pause_menu_after_delay", [false], CONNECT_ONESHOT)

#func _on_pause_next_or_switch_pressed():
	#get_tree().paused = false
	#PauseMenu.close()

	#if both_rockets_landed():
	#	go_to_next_level()
	#else:
	#	switch_active_rocket()

#func _on_pause_next_or_switch_pressed():
	#get_tree().paused = false
	#PauseMenu.close()

	#if both_rockets_landed():
	#	go_to_next_level()
	#else:
		# Only switch if the other rocket is NOT completed
	#	if not SaveData.is_completed(GameState.level_index, 1 - active_rocket):
	#		switch_active_rocket()

func _on_pause_next_or_switch_pressed():
	get_tree().paused = false
	PauseMenu.close()

	# ❌ Not both landed → just switch rockets
	if not both_rockets_landed():
		switch_active_rocket()
		return

	# ✅ Both landed
	# 🔒 If next level already completed → stay in this level
	if next_level_is_completed():
		switch_active_rocket()
		return

	# 🚀 Otherwise → go to next level
	go_to_next_level()

func update_pause_button_label():
	if not PauseMenu:
		return

	var both_landed := both_rockets_landed()
	PauseMenu.set_next_or_switch_label(both_landed)

func go_to_next_level():
	GameState.level_index += 1
	GameState.rocket_type = 0
	active_rocket = 0

	# ✅ CRITICAL FIX
	LevelController.current_index = GameState.level_index

	# Clear UI state
	EngineStatusLabel.text = ""
	EngineStatusLabel.visible = false

	if rocket_instance:
		rocket_instance.queue_free()
		rocket_instance = null

	get_tree().paused = false
	PauseMenu.close()

	spawn_active_rocket()

func both_rockets_landed() -> bool:
	return (
		SaveData.is_completed(GameState.level_index, 0)
		and
		SaveData.is_completed(GameState.level_index, 1)
	)

func switch_active_rocket():
	active_rocket = 1 - active_rocket
	GameState.rocket_type = active_rocket 

	# Clear old rocket status labels
	EngineStatusLabel.text = ""
	EngineStatusLabel.visible = false

	if rocket_instance:
		rocket_instance.queue_free()

	spawn_active_rocket()

	update_pause_button_text()

func next_level_is_completed() -> bool:
	var next_level := GameState.level_index + 1
	return SaveData.is_completed(next_level, 0) and SaveData.is_completed(next_level, 1)

func update_pause_button_text():
	if not both_rockets_landed():
		PauseMenu.set_next_or_switch_text("Switch Rocket")
		return

	if next_level_is_completed():
		PauseMenu.set_next_or_switch_text("Switch Rocket")
		return

	PauseMenu.set_next_or_switch_text("Next Level")

#func show_tutorial():
#	var tutorial_ui = UI2.get_node("TutorialOverlay")
	#tutorial_ui.show()

func _on_tutorial_finished():
	print("✅ Tutorial finished! Spawning rocket now.")
	get_tree().paused = false  # resume the game
	spawn_active_rocket()
	SaveData.set_seen_tutorial(0, 0)

	# 🔥 FORCE physics + input back on
	if rocket_instance:
		rocket_instance.sleeping = false
		rocket_instance.set_physics_process(true)
		rocket_instance.set_process(true)

	Input.flush_buffered_events()  # 🔥 clears stuck input

func set_controls_edit_mode(enabled: bool) -> void:
	if not UI2.has_node("UI_Root"):
		return

	var controls_root = UI2.get_node("UI_Root")

	for child in controls_root.get_children():
		if child.has_method("set"):
			if child.has_variable("editable"):
				child.editable = enabled

func save_controls_layout() -> void:
	if not UI2.has_node("UI_Root"):
		return

	var controls_root = UI2.get_node("UI_Root")
	var data := {}

	for btn in controls_root.get_children():
		data[btn.name] = {
			"pos": btn.rect_position,
			"size": btn.rect_scale
		}

	var f := File.new()
	f.open("user://controls.cfg", File.WRITE)
	f.store_var(data)
	f.close()

	print("💾 Control layout saved")

func load_controls_layout() -> void:
	var f := File.new()
	if not f.file_exists("user://controls.cfg"):
		return

	f.open("user://controls.cfg", File.READ)
	var data = f.get_var()
	f.close()

	var controls_root = UI2.get_node("UI_Root")

	for btn in controls_root.get_children():
		if data.has(btn.name):
			btn.rect_position = data[btn.name].pos
			#btn.rect_scale = data[btn.name].scale
			btn.rect_size = data[btn.name].size
			btn.rect_scale = Vector2.ONE
