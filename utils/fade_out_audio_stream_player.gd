## Plays an audio stream resource by async loading it and switching out the stream
## Adds an optional fade out for previously playing sound
class_name FadeOutAudioStreamPlayer extends AudioStreamPlayer

@export var default_fade_out:float = 0.0

## Controls the priority of new sfx if playing by name to determine if new sound should pre-empt existing playing
@export var priority_dictionary: Dictionary[StringName, int] = {}

var _last_audio_res:StringName

signal audio_started(audio_resource:StringName)

func switch_stream_res_if_not_playing(stream_resource: StringName) -> void:
	if playing:		
		print_debug("%s: switch_stream_res_if_not_playing - %s - existing audio is playing, return" % [name, stream_resource])
		return
	switch_stream_res_and_play(stream_resource)

func switch_stream_if_not_playing(in_stream: AudioStream) -> void:
	if playing:		
		print_debug("%s: switch_stream_res_if_not_playing - existing audio is playing, return" % [name])
		return
	switch_stream_and_play(in_stream)
	
func switch_stream_res_and_play(stream_resource: StringName, restart:bool = false, fade_out_duration:float = default_fade_out) -> void:
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
				
		switch_stream_and_play(audio, true, fade_out_duration)
		_last_audio_res = stream_resource
	
func switch_stream_and_play(in_stream: AudioStream, restart:bool = false, fade_out_duration:float = default_fade_out) -> void:
	if playing and not restart and in_stream == stream:
		return
	await fade_out(fade_out_duration)
	
	if not in_stream:
		print_debug("%s: in_stream NULL - not playing new audio" % name)
		return
	stream = in_stream
	play()
	
func fade_out(duration: float) -> void:
	if not playing:
		print_debug("%s: No audio currently playing, returning immediately" % [name])
		return
	if duration <= 0.0:
		print_debug("%s: stop current audio" % name)
		stop()
		return
		
	print_debug("%s: fade_out: begin - duration=%fs" % [name, duration])
	var tween:Tween = get_tree().create_tween()
	tween.tween_property(self, "volume_linear", 0, duration)
	
	await get_tree().create_timer(duration).timeout
	print_debug("%s: fade_out: end" % name)
