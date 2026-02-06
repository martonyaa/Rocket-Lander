extends TextureButton

export(String) var action_name = ""  # ui_up, ui_down, ui_left, ui_right

func _ready():
    connect("pressed", self, "_on_pressed")
    connect("button_up", self, "_on_released")

func _on_pressed():
    match action_name:
        "ui_up": InputManager.thrust_pressed = true
        "ui_down": InputManager.descend_pressed = true
        "ui_left": InputManager.left_pressed = true
        "ui_right": InputManager.right_pressed = true

func _on_released():
    match action_name:
        "ui_up": InputManager.thrust_pressed = false
        "ui_down": InputManager.descend_pressed = false
        "ui_left": InputManager.left_pressed = false
        "ui_right": InputManager.right_pressed = false
