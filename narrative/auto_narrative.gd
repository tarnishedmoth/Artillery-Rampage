class_name AutoNarrative extends Node

enum Outcomes {
	MIRACLE,
	SUCCESS,
	NEUTRAL,
	FAILURE,
	CATASTROPHE,
}

const ElementSyntax = "[]"
const Elements:Array[String] = [
	"FACTION", # Enemy
	"ENVIRONMENT", # General area
	"LOCATION", # Specific location
	"WEATHER",
	"CIRCUMSTANCE",
	"NONSENSE",
	"POSCOMPARE",
	"NEGCOMPARE",
]

@export var outcome: Outcomes

@export_group("Stories", "stories_")
@export_multiline var stories_miracles:Array[String]
@export_multiline var stories_successes:Array[String]
@export_multiline var stories_neutrals:Array[String]
@export_multiline var stories_failures:Array[String]
@export_multiline var stories_catastrophies:Array[String]

@export_group("Keyword Elements", "elements_")
@export var elements_nonsense:Array[String]
@export var elements_faction:Array[String]
@export var elements_environment:Array[String]
@export var elements_weather:Array[String]
@export var elements_circumstance:Array[String]
@export var elements_poscompare:Array[String]
@export var elements_negcompare:Array[String]

var output:String

func _enter_tree() -> void:
	elements_nonsense.shuffle()
	elements_faction.shuffle()
	elements_environment.shuffle()
	elements_weather.shuffle()
	elements_circumstance.shuffle()
	elements_poscompare.shuffle()
	elements_negcompare.shuffle()

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

func replace_story_keywords(source:String) -> String:
	var text = source
	
	for element in Elements:
		var syntax = ElementSyntax.left(1) + element + ElementSyntax.right(1)
		#print(syntax)
		
		var finished = false
		while not finished:
			var occurrance = text.find(syntax)
			if occurrance == -1:
				finished = true
				break
			# Remove the keyword
			text = text.erase(occurrance, syntax.length())
			# Insert the replacement
			text = text.insert(occurrance, choose_random_description(element))
	return text
		
func choose_random_description(element:String) -> String:
	match element:
		"FACTION":
			return elements_faction.pick_random()
		"ENVIRONMENT":
			return elements_environment.pick_random()
		"LOCATION":
			return "TODO GET DYNAMIC DATA"
		"WEATHER":
			return elements_weather.pick_random()
		"CIRCUMSTANCE":
			return elements_circumstance.pick_random()
		"POSCOMPARE":
			return elements_poscompare.pick_random()
		"NEGCOMPARE":
			return elements_negcompare.pick_random()
		_:
			return elements_nonsense.pick_random()
