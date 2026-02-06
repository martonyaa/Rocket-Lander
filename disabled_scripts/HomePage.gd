extends Control

const LEVEL_COUNT = 10
onready var vbox = $ScrollContainer/HBoxContainer

# Preload rocket selection icons
var rocket1_icon = preload("res://assets/ui/Rocket1.png")
var rocket2_icon = preload("res://assets/ui/Rocket2.png")

var selected_level := 0
var selected_rocket := 1

func _ready():
	#for box in get_tree().get_nodes_in_group("level_boxes"):
	#	box.connect("level_selected", self, "_on_level_selected")
	call_deferred("_connect_level_boxes")

	for node in get_tree().get_nodes_in_group("level_boxes"):
		node.update_lock_state()
		
func _on_Rocket1_pressed(level_index):
	print("Level", level_index, "Rocket 1")

func _on_Rocket2_pressed(level_index):
	print("Level", level_index, "Rocket 2")

func _on_HomeButton_pressed():
	print("HOME PRESSED")
	# Example:
	# get_tree().change_scene("res://HomePage.tscn")

#func _input(event):
#	if event is InputEventMouseButton and event.pressed:
#		print("CLICK AT:", event.position)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("CLICK AT:", event.position)

#func _connect_level_boxes():
#	for mc in vbox.get_children(): # MarginContainers
#		if mc.get_child_count() == 0:
#			continue

#		var level_box = mc.get_child(0)

#		if level_box.has_signal("level_selected"):
#			level_box.connect("level_selected", self, "_on_level_selected")
#			print("✅ Connected LevelBox:", level_box.level_index)

func _connect_level_boxes():
	var boxes = get_tree().get_nodes_in_group("level_boxes")
	print("📡 Homepage sees", boxes.size(), "LevelBoxes")

	for level_box in get_tree().get_nodes_in_group("level_boxes"):
		print("🔗 Connecting to:", level_box, " script:", level_box.get_script())
		level_box.connect("level_selected", self, "_on_level_selected")
		print("✅ Connected LevelBox:", level_box.level_index)

func _on_level_selected(level_index, rocket_type):
	print("🔥 HOME RECEIVED:", level_index, rocket_type)

	selected_level = level_index
	selected_rocket = rocket_type

	GameState.level_index = level_index
	GameState.rocket_type = rocket_type

	get_tree().paused = false          # ← REQUIRED
	get_tree().call_deferred("change_scene", "res://MainScene.tscn")
	#get_tree().change_scene("res://MainScene.tscn")

