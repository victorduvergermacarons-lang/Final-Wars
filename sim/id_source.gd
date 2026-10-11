class_name IdSource
extends RefCounted
## Hands out actor ids. One instance is shared by every zone of a World so ids
## stay unique when heroes move between zones.

var _next := 1


func next() -> int:
	var id := _next
	_next += 1
	return id
