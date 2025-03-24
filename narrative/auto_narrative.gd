class_name AutoNarrative extends Node

enum Outcomes {
	MIRACLE,
	SUCCESS,
	NEUTRAL,
	FAILURE,
	CATASTROPHE,
}

@export var outcome: Outcomes

@export_group("Stories", "stories_")
@export_multiline var stories_miracles:Array[String]
@export_multiline var stories_successes:Array[String]
@export_multiline var stories_neutrals:Array[String]
@export_multiline var stories_failures:Array[String]
@export_multiline var stories_catastrophies:Array[String]

var output:String

func generate_narrative(_outcome: Outcomes) -> String:
	var _outcome_stories = _get_narratives_from_outcome(_outcome)
	var selected_story = _outcome_stories[(randi_range(1,_outcome_stories.size())-1)]
	# TODO: Format the story with reactive beats at run time
	return selected_story

func _get_narratives_from_outcome(_outcome: Outcomes) -> Array[String]:
	match _outcome:
		Outcomes.MIRACLE: return stories_miracles
		Outcomes.SUCCESS: return stories_successes
		Outcomes.NEUTRAL: return stories_neutrals
		Outcomes.FAILURE: return stories_failures
		Outcomes.CATASTROPHE: return stories_catastrophies
		_: return stories_neutrals

func _replace_keyword_in(source:String, key:String, value:String) -> String:
	return source.replace(key, value)
