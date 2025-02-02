# Abstract base class for AI and player controllers
class_name TankController extends Node2D

func begin_turn():
	push_error("abstract function")

var tank: Tank:
	get: return _get_tank()

func _get_tank():
	push_error("abstract function")
