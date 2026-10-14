class_name CharacterDB
extends RefCounted
## Playable hero definitions for VIET LEGENDS.
## Each hero has a unique trait and playstyle. All in-game text is English.
## portrait: res:// path of the Dong Ho style portrait (may be "").

const CHARACTERS := {
	"thach_sanh": {
		"name": "THACH SANH",
		"title": "The Woodcutter",
		"desc": "A kind orphan woodcutter. His lute turns every battle into music.",
		"trait": "Lute artist — chord combos",
		"playstyle": "Strike fast by completing chord sequences.",
		"passive_id": "chord_mastery",
		"passive_name": "CHORD MASTERY",
		"passive_desc": "Compose 1 chord per turn before playing cards. Play Attack/Skill cards in the chord's note order to complete it. A wrong note snaps the string. Power cards are grace notes: free, never break the sequence.",
		"hp": 80,
		"portrait": "res://assets/art/vl2/hero_thachsanh.png",
	},
	"hai_ba_trung": {
		"name": "HAI BA TRUNG",
		"title": "The Warrior Queen",
		"desc": "Legendary Trung sister. She rides her war elephant into the Han ranks.",
		"trait": "War elephant general — resilient tank",
		"playstyle": "Let the elephant soak damage, buff it and counterattack.",
		"passive_id": "war_elephant",
		"passive_name": "WAR ELEPHANT",
		"passive_desc": "A war elephant (30 HP) fights beside you. Every 3 turns it tramples ALL enemies for 12 damage. 25% of enemy hits strike the elephant instead of you.",
		"hp": 90,
		"portrait": "res://assets/art/vl3/hero_haibatrung.png",
	},
}

## Ordered hero ids for the character select screen.
const ORDER := ["thach_sanh", "hai_ba_trung"]


static func get_hero(hero_id: String) -> Dictionary:
	if CHARACTERS.has(hero_id):
		return CHARACTERS[hero_id]
	return CHARACTERS["thach_sanh"]


static func hero_name(hero_id: String) -> String:
	return str(get_hero(hero_id).get("name", "HERO"))
