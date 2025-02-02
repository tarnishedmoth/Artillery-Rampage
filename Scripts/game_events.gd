extends Node

signal turn_started(player: TankController)

signal aim_updated(player: TankController)
signal power_updated(player: TankController)

func emit_turn_started(player: TankController):
 emit_signal("turn_started", player)

func emit_aim_updated(player: TankController):
 emit_signal("aim_updated", player)

func emit_power_updated(player: TankController):
 emit_signal("power_updated", player)
