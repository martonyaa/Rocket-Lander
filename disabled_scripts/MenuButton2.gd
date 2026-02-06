extends TextureButton

func _ready():
	connect("pressed", self, "_on_pressed")

#func _on_pressed():
	#var home_menu = $HomeMenu
	#home_menu.visible = !home_menu.visible

func _on_pressed():
	print("MenuButton pressed")
	var home_menu = get_node("HomeMenu")
	home_menu.visible = true
	print("HomeMenu visible:", home_menu.visible)
	print("HomeMenu rect:", home_menu.rect_position, home_menu.rect_size)
