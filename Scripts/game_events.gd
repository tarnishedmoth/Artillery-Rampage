extends Node

signal turn_started(player: TankController)
signal turn_ended(player: TankController)

signal round_started()
signal round_ended()

signal aim_updated(player: TankController)
signal power_updated(player: TankController)

func emit_turn_started(player: TankController):
	emit_signal("turn_started", player)

func emit_turn_ended(player: TankController):
	emit_signal("turn_ended", player)

func emit_aim_updated(player: TankController):
	emit_signal("aim_updated", player)

func emit_power_updated(player: TankController):
	emit_signal("power_updated", player)

func emit_round_started():
	emit_signal("round_started")

func emit_round_ended():
	emit_signal("round_ended")
