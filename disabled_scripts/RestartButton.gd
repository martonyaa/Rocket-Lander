extends TextureButton

func _on_RestartButton_pressed():
	print("🔁 Restart pressed")

	# Unpause FIRST
	get_tree().paused = false

	# Change scene DEFERRED (after pause state clears)
	get_tree().call_deferred(
		"change_scene",
		"res://MainScene.tscn"
	)
