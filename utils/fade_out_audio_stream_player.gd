## Optionally fades out an existing audio stream before playing a new one or skip restarting a sound that is already playing.
## Optional set of priorities can be set on sound resources to determine if a new sound should pre-empt an existing sound.
class_name FadeOutAudioStreamPlayer extends AudioStreamPlayer

@export var default_fade_out:float = 0.0

## Controls the priority of new sfx if playing by name to determine if new sound should pre-empt existing playing
@export var priority_dictionary: Dictionary[StringName, int] = {}

var _last_audio_res:StringName
var _orig_volume:float

func _init() -> void:
	_orig_volume = volume_linear

func _ready() -> void:
	finished.connect(_on_finished)

func _on_finished() -> void:
	print_debug("%s: finished" % name)
	volume_linear = _orig_volume
	
func switch_stream_res_if_not_playing(stream_resource: StringName, volume:float = volume_linear) -> void:
	if playing:		
		print_debug("%s: switch_stream_res_if_not_playing - %s - existing audio is playing, return" % [name, stream_resource])
		return
	switch_stream_res_and_play(stream_resource, volume)

func switch_stream_if_not_playing(in_stream: AudioStream, volume:float = volume_linear) -> void:
	if playing:		
		print_debug("%s: switch_stream_res_if_not_playing - existing audio is playing, return" % [name])
		return
	switch_stream_and_play(in_stream, volume)
	
func switch_stream_res_and_play(stream_resource: StringName, volume:float = volume_linear, restart:bool = false, fade_out_duration:float = default_fade_out) -> void:
	var audio: AudioStream = load(stream_resource) as AudioStream
	if not audio:
		push_warning("%s: Could not load %s as an AudioStream" % [name, stream_resource])
		return
	
	if not playing or restart or _last_audio_res != stream_resource:
		if playing and _last_audio_res != stream_resource:
			var previous_priority:int = priority_dictionary.get(_last_audio_res, -1)
			var current_priority:int = priority_dictionary.get(stream_resource, -1)
			
			if current_priority < previous_priority:
				print_debug("%s: Priority of current playing sound %s->%d is greater than new sound %s->%d" %
					[name, _last_audio_res, previous_priority, stream_resource, current_priority])
				return
				
		_last_audio_res = stream_resource
		switch_stream_and_play(audio, volume, true, fade_out_duration)
	
func switch_stream_and_play(in_stream: AudioStream, volume:float = volume_linear, restart:bool = false, fade_out_duration:float = default_fade_out) -> void:
	if playing and not restart and in_stream == stream:
		return
	await fade_out(fade_out_duration)
	
	if not in_stream:
		print_debug("%s: in_stream NULL - not playing new audio" % name)
		return
		
	stream = in_stream
	_orig_volume = volume_linear
	volume_linear = volume

	print_debug("%s: playing %s at volume=%f" % [name, _last_audio_res, volume_linear])
	play()
	
func fade_out(duration: float = default_fade_out) -> void:
	if not playing:
		print_debug("%s: No audio currently playing, returning immediately" % [name])
		return
	if duration <= 0.0:
		print_debug("%s: stop current audio" % name)
		stop()
		return
		
	print_debug("%s: fade_out: begin - duration=%fs" % [name, duration])
	
	var tween:Tween = get_tree().create_tween()
	tween.tween_property(self, "volume_linear", 0.0, duration)
	
	await get_tree().create_timer(duration).timeout	
	stop()
	# Necessary to allow next sound to play
	await get_tree().process_frame

	volume_linear = _orig_volume
	print_debug("%s: fade_out: end" % name)
