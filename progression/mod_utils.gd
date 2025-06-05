class_name ModUtils

#region Savable

static func serialize_mod_array(array) -> Array[Dictionary]:
	var mod_array:Array[Dictionary] = []
	mod_array.resize(array.size())
	for i in array.size():
		mod_array[i] = array[i].serialize()
	
	return mod_array

static func deserialize_mod_array(in_array:Array[Dictionary], out_array, deserializer:Callable):
	for data in in_array:
		var result = deserializer.call(data)
		if result:
			out_array.push_back(result)
	return out_array

#endregion
