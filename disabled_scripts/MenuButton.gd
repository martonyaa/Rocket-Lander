extends TextureButton

#onready var pause_menu = get_parent().get_node("PauseMenu")
onready var pause_menu = get_node("/root/MainScene/UI2/PauseMenu")

func _pressed():
	if pause_menu.visible:
		pause_menu.close()
	else:
		pause_menu.open()
