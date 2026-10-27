class_name Regions
extends RefCounted
## The regions of Veyra. Every zone belongs to one (ZoneDef.region); music tracks
## can be tied to regions (MusicTrackDef.regions), so a zone's explore music is its
## region's.

enum Id { HEARTLAND, BEDRUN, VAEL, TIDEREACH, ASHKARA }

const NAMES := {
	Id.HEARTLAND: "Heartland",
	Id.BEDRUN: "Bedrun",
	Id.VAEL: "Vael",
	Id.TIDEREACH: "Tidereach",
	Id.ASHKARA: "Ashkara",
}


static func display_name(id: int) -> String:
	return NAMES.get(id, "?")
