# When the save resource isn't the top level object weird things happen in the resource file and it cannot parse correctly
class_name StoryMapSaveState extends Resource
# Must use @export for things to persist
@export
var nodes:PackedVector2Array = []
