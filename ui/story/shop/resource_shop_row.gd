class_name ShopResourceRowControl extends HBoxContainer

@onready var scrap_value:Label = %ScrapValue
@onready var personnel_value:Label = %PersonnelValue


func update_values(scrap:int, personnel:int) -> void:
	scrap_value.text = "%d" % scrap
	personnel_value.text = "%d" % personnel
