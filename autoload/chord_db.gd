class_name ChordDB
extends RefCounted
## Thach Sanh's signature mechanic: CHORDS.
## A chord = an ordered sequence of notes: "A" (Attack card) or "S" (Skill card).
## Power cards are grace notes: free, never advance nor break the sequence.
## v3.8 AUTO-DETECT (no Compose step): play Attack/Skill cards and the game
## tracks your note string. Complete a known chord's sequence -> its effect
## triggers (max 1 chord per turn). A note that matches no known chord's
## prefix SNAPS the string (reset). All patterns are prefix-free: no chord
## is a prefix of another, so auto-detect never gets stuck.

# id -> {name, seq: Array of "A"/"S", text, tier}
const CHORDS := {
	# --- STARTER (3-note, known from the start) ---
	"war_drum": {"name": "WAR DRUM", "seq": ["A", "A", "A"],
		"text": "Deal 10 damage to ALL enemies.", "tier": 3},
	"lullaby": {"name": "LULLABY", "seq": ["S", "S", "S"],
		"text": "Gain 10 Block.", "tier": 3},
	"charge": {"name": "CHARGE", "seq": ["A", "A", "S"],
		"text": "Your next Attack this turn deals +10 damage.", "tier": 3},
	"steadfast": {"name": "STEADFAST", "seq": ["S", "S", "A"],
		"text": "Draw 2 cards.", "tier": 3},
	# --- LEARNABLE (4-note) ---
	"thunder": {"name": "THUNDER", "seq": ["A", "S", "A", "A"],
		"text": "Deal 20 damage to the target, 8 to all others.", "tier": 4},
	"ensemble": {"name": "ENSEMBLE", "seq": ["A", "S", "A", "S"],
		"text": "Draw 3 cards. Gain 5 Block.", "tier": 4},
	"break_formation": {"name": "BREAK FORMATION", "seq": ["A", "S", "S", "A"],
		"text": "All enemies lose 3 Strength for 2 turns.", "tier": 4},
	"linked_pearls": {"name": "LINKED PEARLS", "seq": ["S", "A", "S", "A"],
		"text": "Deal 7 damage 4 times to random enemies.", "tier": 4},
	"stillness": {"name": "STILLNESS", "seq": ["S", "A", "A", "S"],
		"text": "Heal 15 HP. Gain 15 Block.", "tier": 4},
	# --- MASTERPIECES (5-note, rare, Act 3) ---
	"divine_melody": {"name": "DIVINE MELODY", "seq": ["S", "A", "S", "S", "A"],
		"text": "All enemies lose their next turn. Heal 20 HP.", "tier": 5},
	"heavens_thunder": {"name": "HEAVEN'S THUNDER", "seq": ["S", "A", "A", "A", "S"],
		"text": "Deal 50 damage to the target.", "tier": 5},
}

const STARTER_CHORDS := ["war_drum", "lullaby", "charge", "steadfast"]
const LEARNABLE_4 := ["linked_pearls", "thunder", "ensemble", "break_formation", "stillness"]
const LEARNABLE_5 := ["divine_melody", "heavens_thunder"]


static func get_def(chord_id: String) -> Dictionary:
	return CHORDS.get(chord_id, {})


static func chord_name(chord_id: String) -> String:
	return str(get_def(chord_id).get("name", "???"))


static func seq(chord_id: String) -> Array:
	return get_def(chord_id).get("seq", [])


## "A A S" display string.
static func seq_text(chord_id: String) -> String:
	return " ".join(seq(chord_id))


## Progress display: e.g. seq [A,A,S], progress 2 -> "A A ·"
static func progress_text(chord_id: String, progress: int) -> String:
	var s := seq(chord_id)
	var parts := []
	for i in range(s.size()):
		parts.append(str(s[i]) if i < progress else "·")
	return " ".join(parts)


## Chords the player could still learn (not yet known), optionally filtered by tier.
static func learnable_pool(known: Array, tier: int = 0) -> Array:
	var out := []
	for id in CHORDS.keys():
		if id in known:
			continue
		if tier > 0 and int(CHORDS[id]["tier"]) != tier:
			continue
		out.append(id)
	return out
