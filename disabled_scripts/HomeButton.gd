extends TextureButton   

func _ready():
    connect("pressed", self, "_go_home")

func _go_home():
    get_tree().change_scene("res://HomePage.tscn")
