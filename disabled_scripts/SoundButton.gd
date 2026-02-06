extends TextureButton

#func _ready():
	# Default: sound ON
#	pressed = false

#	pressed = not SaveData.sound_on
#	_apply_sound()

func _ready():
	# Sync button state from SaveData ONLY
	pressed = not SaveData.sound_on
	_apply_sound()

	# Make sure toggled signal is connected
	if not is_connected("toggled", self, "_on_toggled"):
		connect("toggled", self, "_on_toggled")

#func _toggled(button_pressed: bool):
#	if button_pressed:
		# 🔇 Sound OFF
#		AudioServer.set_bus_mute(
#			AudioServer.get_bus_index("Master"),
#			true
#		)
#		print("🔇 Sound OFF")
#	else:
		# 🔊 Sound ON
#		AudioServer.set_bus_mute(
#			AudioServer.get_bus_index("Master"),
#			false
#		)
#		print("🔊 Sound ON")

#	SaveData.set_sound(not button_pressed)
#	_apply_sound()

func _on_toggled(button_pressed: bool):
	# button_pressed == true means "muted"
	SaveData.set_sound(not button_pressed)
	_apply_sound()

#func _apply_sound():
#	var mute = pressed
#	AudioServer.set_bus_mute(
#		AudioServer.get_bus_index("Master"),
#		mute
#	)

func _apply_sound():
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Master"),
		not SaveData.sound_on
	)