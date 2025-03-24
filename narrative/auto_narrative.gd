class_name AutoNarrative extends Node

@export_group("Stories", "stories_")
@export_multiline var stories_miracles:Array[String]
@export_multiline var stories_successes:Array[String]
@export_multiline var stories_neutrals:Array[String]
@export_multiline var stories_failures:Array[String]
@export_multiline var stories_catastrophies:Array[String]

enum Outcomes {
	MIRACLE,
	SUCCESS,
	NEUTRAL,
	FAILURE,
	CATASTROPHE,
}

func generate_narrative(outcome: Outcomes) -> String:
	var outcome_stories = _get_narratives_from_outcome(outcome)
	var selected_story = outcome_stories[(randi_range(1,outcome_stories.size())-1)]
	# TODO: Format the story with reactive beats at run time
	return selected_story

func _get_narratives_from_outcome(outcome: Outcomes) -> Array[String]:
	match outcome:
		Outcomes.MIRACLE: return stories_miracles
		Outcomes.SUCCESS: return stories_successes
		Outcomes.NEUTRAL: return stories_neutrals
		Outcomes.FAILURE: return stories_failures
		Outcomes.CATASTROPHE: return stories_catastrophies
		_: return stories_neutrals
