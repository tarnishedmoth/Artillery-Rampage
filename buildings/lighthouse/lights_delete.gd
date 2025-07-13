extends Node2D

func delete() -> void:
	await Juice.fade_out(self).finished
	queue_free()
