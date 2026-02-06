extends Control

# Buttons inside Panel
onready var HomeButton := $Panel/MarginContainer/HBoxContainer/HomeButton
onready var SoundButton := $Panel/MarginContainer/HBoxContainer/SoundButton

# Internal sound state
var sound_on := true

func _ready():
	# Connect buttons internally (no signals to other nodes)
	if HomeButton:
		HomeButton.connect("pressed", self, "_on_HomeButton_pressed")
	if SoundButton:
		SoundButton.toggle_mode = true
		SoundButton.connect("pressed", self, "_on_SoundButton_pressed")

	# Load saved sound state
	_load_sound_state()
	_update_sound_visual()

func _on_HomeButton_pressed():
	# Go to home scene
	get_tree().change_scene("res://HomePage.tscn")

func _on_SoundButton_pressed():
	# Toggle internal state
	sound_on = !sound_on

	# Update button visuals
	_update_sound_visual()

	# Apply immediately to game audio
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)

	# Save state
	_save_sound_state()

func _update_sound_visual():
	if SoundButton:
		# Pressed = muted, unpressed = sound on
		SoundButton.pressed = not sound_on

func _save_sound_state():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.save("user://settings.cfg")

func _load_sound_state():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		sound_on = cfg.get_value("audio", "sound_on", true)
