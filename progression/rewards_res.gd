class_name StoryRewardsConfig extends Resource

@export_group("Personnel Change", "personnel_change_")
@export var personnel_change_A_PLUS: int = 3
@export var personnel_change_A: int = 2
@export var personnel_change_A_MINUS: int = 2
@export var personnel_change_B_PLUS: int = 1
@export var personnel_change_B: int = 1
@export var personnel_change_B_MINUS: int = 1
@export var personnel_change_C_PLUS: int = 0
@export var personnel_change_C: int = 0
@export var personnel_change_C_MINUS: int = 0
@export var personnel_change_D_PLUS: int = -1
@export var personnel_change_D: int = -2
@export var personnel_change_D_MINUS: int = -2
@export var personnel_change_F: int = -3


@export_group("Scrap Earnings", "scrap_")
@export var scrap_baseline_stipend: float = 0.0
@export var scrap_per_full_kill: float = 3.0
@export var scrap_per_partial_kill: float = 2.0
@export var scrap_per_enemy_damaged: float = 1.0

@export_subgroup("Letter Grade Bonus", "scrap_multiplier_")
@export var scrap_multiplier_A_PLUS: float = 2.0
@export var scrap_multiplier_A: float = 1.8
@export var scrap_multiplier_A_MINUS: float = 1.6
@export var scrap_multiplier_B_PLUS: float = 1.55
@export var scrap_multiplier_B: float = 1.45
@export var scrap_multiplier_B_MINUS: float = 1.35
@export var scrap_multiplier_C_PLUS: float = 1.25
@export var scrap_multiplier_C: float = 1.15
@export var scrap_multiplier_C_MINUS: float = 1.1

@export_subgroup("Run Bonus")
## Index == number of completed runs.
@export var run_multipliers: Array[float] = [
	1.0, # No bonus for first run
	1.25, # 25% bonus for second run
	1.375, #37.5% bonus for third run
	1.50, # 50% bonus for fourth run
	1.75, # 75% bonus for fifth run
	2.0, # 100% bonus for sixth run
	2.5, # 150% bonus for seventh run
	3.0, # 200% bonus for eighth run
]
@export var addtl_runs_multiplier: float = 0.25 ## Bonus for each run after last configured in [member run_multipliers].

func calculate_run_bonus_multiplier(run_count: int) -> float:
	if run_count <= 0:
		push_error("StoryRewardsConfig: Invalid run count %d" % [run_count])
		run_count = 1
		
	if run_multipliers.size() > run_count:
		return run_multipliers[run_count - 1]
	else:
		return ((run_count - run_multipliers.size()) * addtl_runs_multiplier) + run_multipliers.back() # 25% bonus for each run after eighth run

func calculate_scrap_bonus_multiplier(letter_grade: String) -> float:
	match letter_grade:
		"A+": return scrap_multiplier_A_PLUS
		"A": return scrap_multiplier_A
		"A-": return scrap_multiplier_A_MINUS
		"B+": return scrap_multiplier_B_PLUS
		"B": return scrap_multiplier_B
		"B-": return scrap_multiplier_B_MINUS
		"C+": return scrap_multiplier_C_PLUS
		"C" : return scrap_multiplier_C
		"C-" : return scrap_multiplier_C_MINUS
		_: return 1.0

func calculate_personnel_change(letter_grade: String) -> int:
	match letter_grade:
		"A+": return personnel_change_A_PLUS
		"A": return personnel_change_A
		"A-": return personnel_change_A_MINUS
		"B+": return personnel_change_B_PLUS
		"B": return personnel_change_B
		"B-": return personnel_change_B_MINUS
		"C+": return personnel_change_C_PLUS
		"C": return personnel_change_C
		"C-": return personnel_change_C_MINUS
		"D+": return personnel_change_D_PLUS
		"D": return personnel_change_D
		"D-": return personnel_change_D_MINUS
		"F" : return personnel_change_F
		_: 
			push_error("StoryRewardsConfig: Unexpected letter grade %s - returning 0" % [letter_grade])
			return 0
