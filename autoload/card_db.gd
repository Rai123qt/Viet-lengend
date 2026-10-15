class_name CardDB
extends RefCounted
## Static card database for VIET LEGENDS — Story 1 (Thach Sanh).
## Types: ATTACK (red) / SKILL (green) / POWER (purple, persistent).
## Card instance = {"id": String, "upgraded": bool, "power": int, "uid": int}

const CTYPES := ["ATTACK", "SKILL", "POWER"]

const TYPE_COLORS := {
	"ATTACK": Color("b8323c"),
	"SKILL": Color("4d9a52"),
	"POWER": Color("7b5fb5"),
}

# id -> {name, ctype, cost, rarity, text, hero}
# hero: false = neutral (any hero); true = Thach Sanh signature (legacy bool);
#        "hai_ba_trung" = Hai Ba Trung exclusive. Use cards_for_hero() to filter.
const CARDS := {
	# --- STARTER ---
	"strike": {"name": "STRIKE", "ctype": "ATTACK", "cost": 1, "rarity": "starter",
		"text": "Deal 7 damage.", "up_text": "Deal 12 damage.", "hero": false},
	"defend": {"name": "DEFEND", "ctype": "SKILL", "cost": 1, "rarity": "starter",
		"text": "Gain 5 Block.", "up_text": "Gain 9 Block.", "hero": false},
	"grace_note": {"name": "GRACE NOTE", "ctype": "SKILL", "cost": 0, "rarity": "starter",
		"text": "Draw 1 card.", "up_text": "Draw 2 cards.", "hero": true},
	"take_breath": {"name": "TAKE BREATH", "ctype": "SKILL", "cost": 1, "rarity": "starter",
		"text": "Gain 1 Energy. Draw 1 card.", "up_text": "Gain 1 Energy. Draw 2 cards.", "hero": true},
	# --- THACH SANH SIGNATURE: cheap Attacks (chord notes) ---
	"wood_axe": {"name": "WOOD AXE", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 9 damage.", "up_text": "Deal 16 damage.", "hero": true},
	"quick_note": {"name": "QUICK NOTE", "ctype": "ATTACK", "cost": 0, "rarity": "common",
		"text": "Deal 3 damage.", "up_text": "Deal 5 damage.", "hero": true},
	"axe_swing": {"name": "AXE SWING", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 7 damage.", "up_text": "Deal 12 damage.", "hero": true},
	"forest_chop": {"name": "FOREST CHOP", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 14 damage.", "up_text": "Deal 23 damage.", "hero": true},
	"double_cut": {"name": "DOUBLE CUT", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 4 damage twice.", "up_text": "Deal 7 damage twice.", "hero": true},
	"heavy_fell": {"name": "HEAVY FELL", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 16 damage.", "up_text": "Deal 27 damage.", "hero": true},
	"piercing_melody": {"name": "HIGH NOTE", "ctype": "ATTACK", "cost": 1, "rarity": "uncommon",
		"text": "Deal 5 damage (9 if chord completed).", "up_text": "Deal 9 damage (16 if chord completed).", "hero": true},
	"thunder_crash": {"name": "THUNDER CRASH", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 8 damage to ALL enemies.", "up_text": "Deal 13 damage to ALL enemies.", "hero": true},
	"execution": {"name": "EXECUTION", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 22 damage.", "up_text": "Deal 38 damage.", "hero": true},
	# --- THACH SANH SIGNATURE: cheap Skills (chord notes) ---
	"soft_pluck": {"name": "SOFT PLUCK", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Gain 3 Block.", "up_text": "Gain 5 Block.", "hero": true},
	"tune_up": {"name": "TUNE UP", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Draw 2 cards.", "up_text": "Draw 3 cards.", "hero": true},
	"rice_meal": {"name": "RICE MEAL", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Heal 6 HP.", "up_text": "Heal 10 HP.", "hero": true},
	"guard_stance": {"name": "GUARD STANCE", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 8 Block.", "up_text": "Gain 13 Block.", "hero": true},
	"iron_bark": {"name": "IRON BARK", "ctype": "SKILL", "cost": 2, "rarity": "common",
		"text": "Gain 14 Block.", "up_text": "Gain 23 Block.", "hero": true},
	"deep_breath": {"name": "DEEP BREATH", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Gain 4 Block. Draw 1 card.", "up_text": "Gain 7 Block. Draw 1 card.", "hero": true},
	"sturdy_defense": {"name": "STURDY DEFENSE", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 9 Block.", "up_text": "Gain 16 Block.", "hero": true},
	"battle_shout": {"name": "BATTLE SHOUT", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 2 Strength.", "up_text": "Gain 4 Strength.", "hero": true},
	"lullaby_hum": {"name": "LULLABY HUM", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Apply 2 Weak.", "up_text": "Apply 4 Weak.", "hero": true},
	"magic_rice_pot": {"name": "MAGIC RICE POT", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Heal 12 HP.", "up_text": "Heal 21 HP.", "hero": true},
	"sorrowful_tune": {"name": "SORROWFUL TUNE", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Apply 2 Weak to ALL enemies.", "up_text": "Apply 4 Weak to ALL enemies.", "hero": true},
	"victory_song": {"name": "VICTORY SONG", "ctype": "SKILL", "cost": 0, "rarity": "uncommon",
		"text": "After completing a chord: draw 2 cards.", "up_text": "After completing a chord: draw 3 cards.", "hero": true},
	"encore": {"name": "ENCORE", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Draw 2. +1 more if chord completed.", "up_text": "Draw 3. +1 more if chord completed.", "hero": true},
	# --- THACH SANH SIGNATURE: Powers (grace notes for chords) ---
	"sturdy_strings": {"name": "MERCY NOTE", "ctype": "POWER", "cost": 1, "rarity": "uncommon",
		"text": "Wrong notes forgiven (1/battle).", "up_text": "Wrong notes forgiven (2/battle).", "hero": true},
	"divine_lute": {"name": "DIVINE LUTE", "ctype": "POWER", "cost": 2, "rarity": "rare",
		"text": "3-note chords finish at 2 notes.", "up_text": "3-note chords finish at 2 notes.", "hero": true},
	# --- NEUTRAL ---
	"jab": {"name": "JAB", "ctype": "ATTACK", "cost": 0, "rarity": "common",
		"text": "Deal 3 damage.", "up_text": "Deal 5 damage.", "hero": false},
	"heavy_blow": {"name": "HEAVY BLOW", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 12 damage.", "up_text": "Deal 21 damage.", "hero": false},
	"chain_strike": {"name": "CHAIN STRIKE", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 4 damage. Kill: gain 1 Energy.", "up_text": "Deal 7 damage. Kill: gain 1 Energy.", "hero": false},
	"crippling_blow": {"name": "CRIPPLING BLOW", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 7 damage. Apply 1 Weak.", "up_text": "Deal 12 damage. Apply 1 Weak.", "hero": false},
	"pommel_strike": {"name": "POMMEL STRIKE", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 5 damage. Apply 1 Vulnerable.", "up_text": "Deal 9 damage. Apply 1 Vulnerable.", "hero": false},
	"sweeping_cut": {"name": "SWEEPING CUT", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 6 damage to ALL enemies.", "up_text": "Deal 10 damage to ALL enemies.", "hero": false},
	"brace": {"name": "BRACE", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Gain 3 Block.", "up_text": "Gain 5 Block.", "hero": false},
	"mark": {"name": "MARK", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Apply 1 Vulnerable.", "up_text": "Apply 3 Vulnerable.", "hero": false},
	"quick_step": {"name": "QUICK STEP", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Draw 1 card.", "up_text": "Draw 2 cards.", "hero": false},
	"sharpen": {"name": "SHARPEN", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 2 Strength.", "up_text": "Gain 4 Strength.", "hero": false},
	"war_chant": {"name": "WAR CHANT", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 2 Strength. Draw 1 card.", "up_text": "Gain 4 Strength. Draw 1 card.", "hero": false},
	"blood_draw": {"name": "BLOOD DRAW", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Draw 3 cards. Lose 3 HP.", "up_text": "Draw 4 cards. Lose 3 HP.", "hero": false},
	"second_wind": {"name": "SECOND WIND", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 8 Block. Draw 1 card.", "up_text": "Gain 13 Block. Draw 1 card.", "hero": false},
	"expose": {"name": "EXPOSE", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Apply 2 Vulnerable.", "up_text": "Apply 4 Vulnerable.", "hero": false},
	"last_stand": {"name": "LAST STAND", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain Block = missing HP (max 12).", "up_text": "Gain Block = missing HP (max 16).", "hero": false},
	"focus": {"name": "FOCUS", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Gain 3 Strength.", "up_text": "Gain 5 Strength.", "hero": false},
	"rally": {"name": "RALLY", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Heal 8 HP. Draw 1 card.", "up_text": "Heal 13 HP. Draw 1 card.", "hero": false},
	"fortress": {"name": "FORTRESS", "ctype": "SKILL", "cost": 3, "rarity": "rare",
		"text": "Gain 20 Block.", "up_text": "Gain 34 Block.", "hero": false},
	"maw": {"name": "MAW", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 18 damage. Heal half dealt.", "up_text": "Deal 30 damage. Heal half dealt.", "hero": false},
	# --- LEGENDARY (NEW) ---
	"demon_slayer": {"name": "DEMON SLAYER", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 35 damage.", "up_text": "Deal 45 damage.", "hero": true},
	"storm_wings": {"name": "STORM WINGS", "ctype": "ATTACK", "cost": 2, "rarity": "legendary",
		"text": "Deal 8 damage to ALL enemies 3 times.", "up_text": "Deal 11 damage to ALL enemies 3 times.", "hero": true},
	"heros_legacy": {"name": "HERO'S LEGACY", "ctype": "SKILL", "cost": 1, "rarity": "legendary",
		"text": "Gain 20 Block. Complete your current chord instantly.", "up_text": "Gain 28 Block. Complete your current chord instantly.", "hero": true},
	"thunder_hammer": {"name": "THUNDER HAMMER", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 25 damage. Apply 3 Vulnerable.", "up_text": "Deal 32 damage. Apply 4 Vulnerable.", "hero": true},
	"celestial_army": {"name": "CELESTIAL ARMY", "ctype": "SKILL", "cost": 2, "rarity": "legendary",
		"text": "Gain 15 Block. Deal 15 damage to ALL enemies.", "up_text": "Gain 20 Block. Deal 20 damage to ALL enemies.", "hero": true},
	"dragons_heart": {"name": "DRAGON'S HEART", "ctype": "POWER", "cost": 0, "rarity": "legendary",
		"text": "Grace note. Heal 15 HP. Gain 2 Energy.", "up_text": "Grace note. Heal 20 HP. Gain 3 Energy.", "hero": true},
	"fox_fire": {"name": "FOX FIRE", "ctype": "ATTACK", "cost": 2, "rarity": "legendary",
		"text": "Deal 12 damage twice. Apply 2 Burn.", "up_text": "Deal 15 damage twice. Apply 3 Burn.", "hero": true},
	"mountains_embrace": {"name": "MOUNTAIN'S EMBRACE", "ctype": "SKILL", "cost": 3, "rarity": "legendary",
		"text": "Gain 30 Block and 3 Plated Armor.", "up_text": "Gain 40 Block and 4 Plated Armor.", "hero": true},
	"fates_thread": {"name": "FATE'S THREAD", "ctype": "SKILL", "cost": 1, "rarity": "legendary",
		"text": "Draw 5 cards. All cards cost 1 less this turn.", "up_text": "Draw 6 cards. All cards cost 1 less this turn.", "hero": true},
	"apocalypse": {"name": "APOCALYPSE", "ctype": "ATTACK", "cost": 4, "rarity": "legendary",
		"text": "Deal 50 damage. Completes any chord.", "up_text": "Deal 65 damage. Completes any chord.", "hero": true},
	# --- MYTHIC (NEW) ---
	"thunder_strike": {"name": "THUNDER STRIKE", "ctype": "ATTACK", "cost": 2, "rarity": "mythic",
		"text": "Deal 18 damage. +8 if this completes a chord.", "up_text": "Deal 24 damage. +12 if this completes a chord.", "hero": true},
	"iron_wall": {"name": "IRON WALL", "ctype": "SKILL", "cost": 2, "rarity": "mythic",
		"text": "Gain 16 Block. Draw 2 cards.", "up_text": "Gain 22 Block. Draw 3 cards.", "hero": true},
	"heavens_grace": {"name": "HEAVEN'S GRACE", "ctype": "POWER", "cost": 0, "rarity": "mythic",
		"text": "Grace note. Heal 8 HP. Draw 1 card.", "up_text": "Grace note. Heal 12 HP. Draw 2 cards.", "hero": true},
	"twin_dragons": {"name": "TWIN DRAGONS", "ctype": "ATTACK", "cost": 3, "rarity": "mythic",
		"text": "Deal 12 damage twice.", "up_text": "Deal 16 damage twice.", "hero": true},
	"phoenix_rebirth": {"name": "PHOENIX REBIRTH", "ctype": "SKILL", "cost": 2, "rarity": "mythic",
		"text": "Heal 12 HP. Gain 12 Block.", "up_text": "Heal 16 HP. Gain 16 Block.", "hero": true},
	"lightning_chain": {"name": "LIGHTNING CHAIN", "ctype": "ATTACK", "cost": 2, "rarity": "mythic",
		"text": "Deal 10 damage to ALL enemies. Repeat if this kills.", "up_text": "Deal 14 damage to ALL enemies. Repeat if this kills.", "hero": true},
	"sages_wisdom": {"name": "SAGE'S WISDOM", "ctype": "SKILL", "cost": 1, "rarity": "mythic",
		"text": "Draw 3 cards. Gain 1 Energy.", "up_text": "Draw 4 cards. Gain 1 Energy.", "hero": true},
	"tigers_fury": {"name": "TIGER'S FURY", "ctype": "ATTACK", "cost": 1, "rarity": "mythic",
		"text": "Deal 8 damage 3 times.", "up_text": "Deal 11 damage 3 times.", "hero": true},
	"turtles_shell": {"name": "TURTLE'S SHELL", "ctype": "SKILL", "cost": 2, "rarity": "mythic",
		"text": "Gain 20 Block.", "up_text": "Gain 28 Block.", "hero": true},
	"cranes_dance": {"name": "CRANE'S DANCE", "ctype": "POWER", "cost": 0, "rarity": "mythic",
		"text": "Grace note. Gain 2 Energy. Draw 2 cards.", "up_text": "Grace note. Gain 3 Energy. Draw 2 cards.", "hero": true},
	"volcano": {"name": "VOLCANO", "ctype": "ATTACK", "cost": 3, "rarity": "mythic",
		"text": "Deal 15 damage to ALL enemies. Apply 2 Burn.", "up_text": "Deal 20 damage to ALL enemies. Apply 3 Burn.", "hero": true},
	"monsoon_shield": {"name": "MONSOON SHIELD", "ctype": "SKILL", "cost": 1, "rarity": "mythic",
		"text": "Gain 12 Block. Remove all debuffs.", "up_text": "Gain 16 Block. Remove all debuffs.", "hero": true},
	"ancestors_blessing": {"name": "ANCESTOR'S BLESSING", "ctype": "POWER", "cost": 1, "rarity": "mythic",
		"text": "Grace note. Your Attacks deal +5 damage this turn.", "up_text": "Grace note. Your Attacks deal +8 damage this turn.", "hero": true},
	"serpents_coil": {"name": "SERPENT'S COIL", "ctype": "ATTACK", "cost": 2, "rarity": "mythic",
		"text": "Deal 14 damage. Apply 3 Poison and 2 Weak.", "up_text": "Deal 18 damage. Apply 4 Poison and 3 Weak.", "hero": true},
	"moonlit_sonata": {"name": "MOONLIT SONATA", "ctype": "SKILL", "cost": 2, "rarity": "mythic",
		"text": "Gain 10 Block. Draw 2 cards. Heal 5 HP.", "up_text": "Gain 14 Block. Draw 3 cards. Heal 8 HP.", "hero": true},
	# --- RARE (NEW) ---
	"executioners_axe": {"name": "EXECUTIONER'S AXE", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 16 damage. Double if target is below 50% HP.", "up_text": "Deal 22 damage. Double if target is below 50% HP.", "hero": true},
	"bastion": {"name": "BASTION", "ctype": "SKILL", "cost": 2, "rarity": "rare",
		"text": "Gain 14 Block. +4 for each Skill played this turn.", "up_text": "Gain 18 Block. +6 for each Skill played this turn.", "hero": true},
	"bloodlust": {"name": "BLOODLUST", "ctype": "POWER", "cost": 0, "rarity": "rare",
		"text": "Grace note. Your next 3 Attacks deal +4 damage.", "up_text": "Grace note. Your next 3 Attacks deal +6 damage.", "hero": true},
	"whirlwind": {"name": "WHIRLWIND", "ctype": "ATTACK", "cost": 1, "rarity": "rare",
		"text": "Deal 6 damage to ALL enemies twice.", "up_text": "Deal 8 damage to ALL enemies twice.", "hero": true},
	"meditation": {"name": "MEDITATION", "ctype": "SKILL", "cost": 1, "rarity": "rare",
		"text": "Gain 2 Energy. Draw 1 card. Lose 3 HP.", "up_text": "Gain 2 Energy. Draw 2 cards. Lose 3 HP.", "hero": true},
	"piercing_arrow": {"name": "PIERCING ARROW", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 20 damage. Ignores Block.", "up_text": "Deal 26 damage. Ignores Block.", "hero": true},
	"stone_skin": {"name": "STONE SKIN", "ctype": "SKILL", "cost": 1, "rarity": "rare",
		"text": "Gain 8 Block and 2 Plated Armor.", "up_text": "Gain 11 Block and 3 Plated Armor.", "hero": true},
	"frenzy": {"name": "FRENZY", "ctype": "ATTACK", "cost": 0, "rarity": "rare",
		"text": "Deal 5 damage. You may play this twice.", "up_text": "Deal 8 damage. You may play this twice.", "hero": true},
	"tactical_retreat": {"name": "TACTICAL RETREAT", "ctype": "SKILL", "cost": 1, "rarity": "rare",
		"text": "Gain 10 Block. Draw 2 cards. Discard 1.", "up_text": "Gain 14 Block. Draw 2 cards. Discard 1.", "hero": true},
	"venom_blade": {"name": "VENOM BLADE", "ctype": "ATTACK", "cost": 1, "rarity": "rare",
		"text": "Deal 8 damage. Apply 4 Poison.", "up_text": "Deal 11 damage. Apply 6 Poison.", "hero": true},
	"war_drums": {"name": "WAR DRUMS", "ctype": "POWER", "cost": 1, "rarity": "rare",
		"text": "Gain 1 Energy. Your next chord deals +10 damage.", "up_text": "Gain 1 Energy. Your next chord deals +15 damage.", "hero": true},
	"guardian_spirit": {"name": "GUARDIAN SPIRIT", "ctype": "SKILL", "cost": 2, "rarity": "rare",
		"text": "Gain 12 Block. Heal 6 HP.", "up_text": "Gain 16 Block. Heal 9 HP.", "hero": true},
	"meteor_fall": {"name": "METEOR FALL", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 28 damage.", "up_text": "Deal 36 damage.", "hero": true},
	"shadow_step": {"name": "SHADOW STEP", "ctype": "SKILL", "cost": 0, "rarity": "rare",
		"text": "Gain 6 Block. Draw 1 card.", "up_text": "Gain 9 Block. Draw 2 cards.", "hero": true},
	"rallying_cry": {"name": "RALLYING CRY", "ctype": "POWER", "cost": 0, "rarity": "rare",
		"text": "Grace note. Draw 3 cards. Discard 1.", "up_text": "Grace note. Draw 4 cards. Discard 1.", "hero": true},
	"earthquake": {"name": "EARTHQUAKE", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 12 damage to ALL enemies. Apply 1 Weak.", "up_text": "Deal 16 damage to ALL enemies. Apply 2 Weak.", "hero": true},
	# --- UNCOMMON (NEW) ---
	"heavy_smash": {"name": "HEAVY SMASH", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 14 damage.", "up_text": "Deal 18 damage.", "hero": true},
	"quick_guard": {"name": "QUICK GUARD", "ctype": "SKILL", "cost": 0, "rarity": "uncommon",
		"text": "Gain 4 Block.", "up_text": "Gain 7 Block.", "hero": true},
	"double_strike": {"name": "DOUBLE STRIKE", "ctype": "ATTACK", "cost": 1, "rarity": "uncommon",
		"text": "Deal 5 damage twice.", "up_text": "Deal 7 damage twice.", "hero": true},
	"battle_focus": {"name": "BATTLE FOCUS", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Draw 2 cards.", "up_text": "Draw 3 cards.", "hero": true},
	"cleave": {"name": "CLEAVE", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 10 damage to ALL enemies.", "up_text": "Deal 14 damage to ALL enemies.", "hero": true},
	"reinforce": {"name": "REINFORCE", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 9 Block.", "up_text": "Gain 12 Block.", "hero": true},
	"poison_dart": {"name": "POISON DART", "ctype": "ATTACK", "cost": 1, "rarity": "uncommon",
		"text": "Deal 6 damage. Apply 3 Poison.", "up_text": "Deal 8 damage. Apply 4 Poison.", "hero": true},
	"renewed_vigor": {"name": "RENEWED VIGOR", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Heal 6 HP. Gain 6 Block.", "up_text": "Heal 9 HP. Gain 9 Block.", "hero": true},
	"swift_melody": {"name": "SWIFT MELODY", "ctype": "POWER", "cost": 0, "rarity": "uncommon",
		"text": "Grace note. Draw 1 card. Gain 1 Energy.", "up_text": "Grace note. Draw 2 cards. Gain 1 Energy.", "hero": true},
	"crushing_blow": {"name": "CRUSHING BLOW", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 12 damage. Apply 1 Vulnerable.", "up_text": "Deal 16 damage. Apply 2 Vulnerable.", "hero": true},
	"barrier": {"name": "BARRIER", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Gain 13 Block.", "up_text": "Gain 17 Block.", "hero": true},
	# --- THACH SANH STORY EXCLUSIVES (v5.8) ---
	"lute_echo": {"name": "LUTE ECHO", "ctype": "POWER", "cost": 2, "rarity": "mythic",
		"text": "Whenever you complete a chord, ALL enemies lose 3 HP.", "up_text": "Whenever you complete a chord, ALL enemies lose 5 HP.", "hero": true},
	"rice_pot": {"name": "RICE POT", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Heal 8 HP.", "up_text": "Heal 12 HP.", "hero": true},
	"python_coil": {"name": "PYTHON COIL", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 12 damage. Apply 1 Weak.", "up_text": "Deal 16 damage. Apply 2 Weak.", "hero": true},
	"eagle_dive": {"name": "EAGLE DIVE", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 15 damage. Ignores Block.", "up_text": "Deal 20 damage. Ignores Block.", "hero": true},
	"ly_thong_trick": {"name": "LY THONG TRICK", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Enemy loses 5 HP. Draw 2 cards.", "up_text": "Enemy loses 8 HP. Draw 3 cards.", "hero": true},
	"magic_lute_song": {"name": "MAGIC LUTE SONG", "ctype": "POWER", "cost": 3, "rarity": "legendary",
		"text": "Chords need 1 fewer note to complete.", "up_text": "Chords need 1 fewer note. +1 Energy each turn.", "hero": true},
	"woodcutter_swing": {"name": "WOODCUTTER SWING", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 8 damage.", "up_text": "Deal 11 damage.", "hero": true},
	"princess_blessing": {"name": "PRINCESS BLESSING", "ctype": "SKILL", "cost": 2, "rarity": "rare",
		"text": "Heal 10 HP. Remove all debuffs.", "up_text": "Heal 15 HP. Remove all debuffs.", "hero": true},
	"thach_demon_slayer": {"name": "DEMON SLAYER", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 20 damage. Exhaust.", "up_text": "Deal 28 damage. Exhaust.", "hero": true},
	"stone_dog_guard": {"name": "STONE DOG GUARD", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 12 Block.", "up_text": "Gain 16 Block.", "hero": true},
	# --- HAI BA TRUNG STORY EXCLUSIVES (v5.9) ---
	"elephant_charge": {"name": "ELEPHANT CHARGE", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 14 damage to ALL enemies.", "up_text": "Deal 19 damage to ALL enemies.", "hero": "hai_ba_trung"},
	"trung_sisters": {"name": "TRUNG SISTERS", "ctype": "SKILL", "cost": 1, "rarity": "rare",
		"text": "Gain 2 Energy. Draw 2 cards.", "up_text": "Gain 2 Energy. Draw 3 cards.", "hero": "hai_ba_trung"},
	"war_drum": {"name": "WAR DRUM", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Elephant heals 10 HP. Next trample +4 damage.", "up_text": "Elephant heals 15 HP. Next trample +6 damage.", "hero": "hai_ba_trung"},
	"spear_wall": {"name": "SPEAR WALL", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Gain 15 Block.", "up_text": "Gain 20 Block.", "hero": "hai_ba_trung"},
	"me_linh_oath": {"name": "ME LINH OATH", "ctype": "POWER", "cost": 2, "rarity": "rare",
		"text": "Elephant heals 3 HP at the start of each turn.", "up_text": "Elephant heals 5 HP at the start of each turn.", "hero": "hai_ba_trung"},
	"elephant_armor": {"name": "ELEPHANT ARMOR", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Elephant gains 20 Block.", "up_text": "Elephant gains 28 Block.", "hero": "hai_ba_trung"},
	"sisters_fury": {"name": "SISTER'S FURY", "ctype": "ATTACK", "cost": 2, "rarity": "rare",
		"text": "Deal 10 damage. +5 per Elephant card played this turn.", "up_text": "Deal 14 damage. +7 per Elephant card played this turn.", "hero": "hai_ba_trung"},
	"rice_provision": {"name": "RICE PROVISION", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Heal 12 HP. Elephant heals 12 HP.", "up_text": "Heal 16 HP. Elephant heals 16 HP.", "hero": "hai_ba_trung"},
	"han_slayer": {"name": "HAN SLAYER", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 18 damage.", "up_text": "Deal 24 damage.", "hero": "hai_ba_trung"},
	"to_dinh_bane": {"name": "TO DINH'S BANE", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 25 damage.", "up_text": "Deal 34 damage.", "hero": "hai_ba_trung"},
	"arrow_shot": {"name": "ARROW SHOT", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 7 damage.", "up_text": "Deal 10 damage.", "hero": "hai_ba_trung"},
	"double_shot": {"name": "DOUBLE SHOT", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 4 damage twice.", "up_text": "Deal 6 damage twice.", "hero": "hai_ba_trung"},
	"piercing_arrow_hbt": {"name": "PIERCING ARROW", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 12 damage. Ignores Block.", "up_text": "Deal 16 damage. Ignores Block.", "hero": "hai_ba_trung"},
	"rain_of_arrows": {"name": "RAIN OF ARROWS", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 5 damage to ALL enemies.", "up_text": "Deal 8 damage to ALL enemies.", "hero": "hai_ba_trung"},
	"sniper_shot": {"name": "SNIPER SHOT", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 10 damage if enemy is at full HP.", "up_text": "Deal 14 damage if enemy is at full HP.", "hero": "hai_ba_trung"},
	"rapid_fire": {"name": "RAPID FIRE", "ctype": "ATTACK", "cost": 0, "rarity": "common",
		"text": "Deal 3 damage. Draw 1 card.", "up_text": "Deal 5 damage. Draw 1 card.", "hero": "hai_ba_trung"},
	"fire_arrow": {"name": "FIRE ARROW", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 8 damage. Apply 3 Burn for 2 turns.", "up_text": "Deal 11 damage. Apply 4 Burn for 2 turns.", "hero": "hai_ba_trung"},
	"ice_arrow": {"name": "ICE ARROW", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Deal 6 damage. Apply 1 Weak.", "up_text": "Deal 9 damage. Apply 2 Weak.", "hero": "hai_ba_trung"},
	"explosive_arrow": {"name": "EXPLOSIVE ARROW", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 18 damage to ALL enemies.", "up_text": "Deal 24 damage to ALL enemies.", "hero": "hai_ba_trung"},
	"eagle_eye": {"name": "EAGLE EYE", "ctype": "POWER", "cost": 1, "rarity": "uncommon",
		"text": "Bow attacks deal +3 damage.", "up_text": "Bow attacks deal +5 damage.", "hero": "hai_ba_trung"},
	"arrow_storm": {"name": "ARROW STORM", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 4 damage 4 times to random enemies.", "up_text": "Deal 6 damage 4 times to random enemies.", "hero": "hai_ba_trung"},
	"hunters_mark": {"name": "HUNTER\'S MARK", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Mark enemy. Next attack +8 damage.", "up_text": "Mark enemy. Next attack +12 damage.", "hero": "hai_ba_trung"},
	"long_range": {"name": "LONG RANGE", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 14 damage. Cannot be countered.", "up_text": "Deal 19 damage. Cannot be countered.", "hero": "hai_ba_trung"},
	"triple_volley": {"name": "TRIPLE VOLLEY", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 6 damage 3 times.", "up_text": "Deal 9 damage 3 times.", "hero": "hai_ba_trung"},
	"phoenix_arrow": {"name": "PHOENIX ARROW", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 25 damage. Gain 1 Energy if this kills.", "up_text": "Deal 34 damage. Gain 2 Energy if this kills.", "hero": "hai_ba_trung"},
	"voi_xung_phong": {"name": "VOI XUNG PHONG", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Elephant charges: 14 damage.", "up_text": "Elephant charges: 19 damage.", "hero": "hai_ba_trung"},
	"voi_giam": {"name": "VOI GIAM", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Elephant tramples ALL enemies for 10 damage.", "up_text": "Elephant tramples ALL enemies for 14 damage.", "hero": "hai_ba_trung"},
	"voi_ho_ve": {"name": "VOI HO VE", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "For 2 turns, 50% of hits go to Elephant.", "up_text": "For 3 turns, 50% of hits go to Elephant.", "hero": "hai_ba_trung"},
	"voi_thinh_no": {"name": "VOI THINH NO", "ctype": "POWER", "cost": 2, "rarity": "rare",
		"text": "Elephant +6 damage for 2 turns.", "up_text": "Elephant +9 damage for 2 turns.", "hero": "hai_ba_trung"},
	"voi_quat_voi": {"name": "VOI QUAT VOI", "ctype": "ATTACK", "cost": 1, "rarity": "common",
		"text": "Elephant swings trunk: 8 damage. Enemy -1 Energy.", "up_text": "Elephant swings trunk: 12 damage. Enemy -1 Energy.", "hero": "hai_ba_trung"},
	"voi_dam_chan": {"name": "VOI DAM CHAN", "ctype": "ATTACK", "cost": 0, "rarity": "common",
		"text": "Elephant stomps: 4 damage to ALL.", "up_text": "Elephant stomps: 7 damage to ALL.", "hero": "hai_ba_trung"},
	"lenh_tan_cong": {"name": "LENH TAN CONG", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Elephant attacks immediately (skip 3-turn count).", "up_text": "Elephant attacks immediately. Draw 1 card.", "hero": "hai_ba_trung"},
	"voi_huc_do": {"name": "VOI HUC DO", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Elephant rams: 16 damage. Destroys 10 Block.", "up_text": "Elephant rams: 22 damage. Destroys 14 Block.", "hero": "hai_ba_trung"},
	"dan_voi": {"name": "DAN VOI", "ctype": "SKILL", "cost": 3, "rarity": "rare",
		"text": "Summon 2 baby elephants (10 HP each, trample 4).", "up_text": "Summon 2 baby elephants (14 HP each, trample 6).", "hero": "hai_ba_trung"},
	"voi_chien_binh": {"name": "VOI CHIEN BINH", "ctype": "POWER", "cost": 2, "rarity": "rare",
		"text": "Elephant +2 damage permanently each turn.", "up_text": "Elephant +3 damage permanently each turn.", "hero": "hai_ba_trung"},
	"tieng_gam": {"name": "TIENG GAM", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "ALL enemies -1 Strength.", "up_text": "ALL enemies -2 Strength.", "hero": "hai_ba_trung"},
	"voi_lao_toi": {"name": "VOI LAO TOI", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Elephant advances: next hit +8 damage.", "up_text": "Elephant advances: next hit +12 damage.", "hero": "hai_ba_trung"},
	"suc_manh_rung": {"name": "SUC MANH RUNG", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Elephant +15 max HP and heals 15.", "up_text": "Elephant +22 max HP and heals 22.", "hero": "hai_ba_trung"},
	"voi_than": {"name": "VOI THAN", "ctype": "SKILL", "cost": 3, "rarity": "legendary",
		"text": "Elephant invincible 1 turn + tramples 20 ALL.", "up_text": "Elephant invincible 2 turns + tramples 28 ALL.", "hero": "hai_ba_trung"},
	"hop_suc": {"name": "HOP SUC", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "You deal 8 + Elephant deals 8.", "up_text": "You deal 12 + Elephant deals 12.", "hero": "hai_ba_trung"},
	"cham_voi": {"name": "CHAM VOI", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Elephant heals 12 HP.", "up_text": "Elephant heals 17 HP.", "hero": "hai_ba_trung"},
	"giap_voi": {"name": "GIAP VOI", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Elephant gains 20 Block.", "up_text": "Elephant gains 28 Block.", "hero": "hai_ba_trung"},
	"duong_suc": {"name": "DUONG SUC", "ctype": "POWER", "cost": 2, "rarity": "uncommon",
		"text": "Elephant +4 damage permanently.", "up_text": "Elephant +6 damage permanently.", "hero": "hai_ba_trung"},
	"thuoc_voi": {"name": "THUOC VOI", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Elephant heals 6 HP. Draw 1 card.", "up_text": "Elephant heals 9 HP. Draw 1 card.", "hero": "hai_ba_trung"},
	"yeu_thuong": {"name": "YEU THUONG", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "You and Elephant heal 8 HP.", "up_text": "You and Elephant heal 12 HP.", "hero": "hai_ba_trung"},
	"boc_thep": {"name": "BOC THEP", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Elephant +30 max HP.", "up_text": "Elephant +42 max HP.", "hero": "hai_ba_trung"},
	"tinh_than_thep": {"name": "TINH THAN THEP", "ctype": "POWER", "cost": 1, "rarity": "rare",
		"text": "Elephant immune to Weak/Vulnerable.", "up_text": "Elephant immune to all debuffs.", "hero": "hai_ba_trung"},
	"hoi_phuc": {"name": "HOI PHUC", "ctype": "SKILL", "cost": 2, "rarity": "rare",
		"text": "Elephant heals to full (once per combat).", "up_text": "Elephant heals to full. Draw 2 cards.", "hero": "hai_ba_trung"},
	"suc_ben": {"name": "SUC BEN", "ctype": "POWER", "cost": 1, "rarity": "uncommon",
		"text": "Elephant +2 Block when hit.", "up_text": "Elephant +3 Block when hit.", "hero": "hai_ba_trung"},
	"mat_ngot": {"name": "MAT NGOT", "ctype": "POWER", "cost": 1, "rarity": "common",
		"text": "Elephant gives you +1 Energy each turn.", "up_text": "Elephant gives you +1 Energy each turn. Draw 1 card on play.", "hero": "hai_ba_trung"},
	"ten_lenh": {"name": "TEN LENH", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Draw 2 cards.", "up_text": "Draw 3 cards.", "hero": "hai_ba_trung"},
	"trinh_sat": {"name": "TRINH SAT", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Look at top 3 cards. Take 1.", "up_text": "Look at top 5 cards. Take 2.", "hero": "hai_ba_trung"},
	"doi_hinh": {"name": "DOI HINH", "ctype": "SKILL", "cost": 2, "rarity": "common",
		"text": "Gain 12 Block. Elephant gains 8 Block.", "up_text": "Gain 17 Block. Elephant gains 12 Block.", "hero": "hai_ba_trung"},
	"phan_cong": {"name": "PHAN CONG", "ctype": "POWER", "cost": 1, "rarity": "uncommon",
		"text": "For 3 turns: when hit, shoot 5 damage back.", "up_text": "For 3 turns: when hit, shoot 8 damage back.", "hero": "hai_ba_trung"},
	"tap_hop": {"name": "TAP HOP", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 2 Energy. Lose 5 HP.", "up_text": "Gain 3 Energy. Lose 5 HP.", "hero": "hai_ba_trung"},
	"chien_thuat_du_kich": {"name": "CHIEN THUAT DU KICH", "ctype": "ATTACK", "cost": 2, "rarity": "common",
		"text": "Deal 8 damage. Draw 2 cards.", "up_text": "Deal 12 damage. Draw 2 cards.", "hero": "hai_ba_trung"},
	"an_nap": {"name": "AN NAP", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 8 Block. Untargetable 1 turn.", "up_text": "Gain 12 Block. Untargetable 1 turn.", "hero": "hai_ba_trung"},
	"tiep_te": {"name": "TIEP TE", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Heal 10 HP.", "up_text": "Heal 15 HP.", "hero": "hai_ba_trung"},
	"khieu_khich": {"name": "KHIEU KHICH", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Enemies attack Elephant for 2 turns.", "up_text": "Enemies attack Elephant for 3 turns.", "hero": "hai_ba_trung"},
	"rut_lui": {"name": "RUT LUI", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "Gain 4 Block. Draw 1 card.", "up_text": "Gain 7 Block. Draw 1 card.", "hero": "hai_ba_trung"},
	"tan_cong_phoi_hop": {"name": "TAN CONG PHOI HOP", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "If Elephant alive: 16 damage. Else 8.", "up_text": "If Elephant alive: 22 damage. Else 11.", "hero": "hai_ba_trung"},
	"loi_dung_dia_hinh": {"name": "LOI DUNG DIA HINH", "ctype": "POWER", "cost": 1, "rarity": "common",
		"text": "+2 Block at start of each turn.", "up_text": "+3 Block at start of each turn.", "hero": "hai_ba_trung"},
	"tinh_than_dan_toc": {"name": "TINH THAN DAN TOC", "ctype": "POWER", "cost": 2, "rarity": "rare",
		"text": "Each Elephant card +1 damage.", "up_text": "Each Elephant card +2 damage.", "hero": "hai_ba_trung"},
	"ke_hoach": {"name": "KE HOACH", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "See enemy intent. Gain 1 Energy.", "up_text": "See all intents. Gain 1 Energy.", "hero": "hai_ba_trung"},
	"bay": {"name": "BAY", "ctype": "SKILL", "cost": 2, "rarity": "uncommon",
		"text": "Set trap: attacker takes 10 damage.", "up_text": "Set trap: attacker takes 16 damage.", "hero": "hai_ba_trung"},
	"tieng_trong": {"name": "TIENG TRONG", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "All allies +2 Strength.", "up_text": "All allies +3 Strength.", "hero": "hai_ba_trung"},
	"nghi_ngoi": {"name": "NGHI NGOI", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Heal 15 HP. Discard 1 card.", "up_text": "Heal 22 HP.", "hero": "hai_ba_trung"},
	"quyet_tam": {"name": "QUYET TAM", "ctype": "SKILL", "cost": 0, "rarity": "common",
		"text": "+1 Strength. Draw 1 card.", "up_text": "+2 Strength. Draw 1 card.", "hero": "hai_ba_trung"},
	"phong_thu_vung": {"name": "PHONG THU VUNG", "ctype": "SKILL", "cost": 2, "rarity": "common",
		"text": "Gain 18 Block.", "up_text": "Gain 25 Block.", "hero": "hai_ba_trung"},
	"tan_cong_tong_luc": {"name": "TAN CONG TONG LUC", "ctype": "ATTACK", "cost": 3, "rarity": "rare",
		"text": "Deal 12 to ALL + Elephant tramples 8 ALL.", "up_text": "Deal 17 to ALL + Elephant tramples 12 ALL.", "hero": "hai_ba_trung"},
	"hai_ba_trung_legend": {"name": "HAI BA TRUNG", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "You deal 20 + Elephant deals 15.", "up_text": "You deal 28 + Elephant deals 22.", "hero": "hai_ba_trung"},
	"me_linh": {"name": "ME LINH", "ctype": "POWER", "cost": 2, "rarity": "legendary",
		"text": "Each turn: Elephant heals 5, you gain 5 Block.", "up_text": "Each turn: Elephant heals 8, you gain 8 Block.", "hero": "hai_ba_trung"},
	"co_khoi_nghia": {"name": "CO KHOI NGHIA", "ctype": "POWER", "cost": 1, "rarity": "legendary",
		"text": "Elephant cards cost 1 less (min 0).", "up_text": "Elephant cards cost 1 less. Draw 1 on play.", "hero": "hai_ba_trung"},
	"voi_trang": {"name": "VOI TRANG", "ctype": "SKILL", "cost": 3, "rarity": "legendary",
		"text": "Summon White Elephant (40 HP, tramples 15).", "up_text": "Summon White Elephant (55 HP, tramples 20).", "hero": "hai_ba_trung"},
	"ten_than": {"name": "TEN THAN", "ctype": "ATTACK", "cost": 2, "rarity": "legendary",
		"text": "Deal 30 damage. Ignores Block.", "up_text": "Deal 42 damage. Ignores Block.", "hero": "hai_ba_trung"},
	"nu_tuong": {"name": "NU TUONG", "ctype": "POWER", "cost": 2, "rarity": "legendary",
		"text": "You +1 Energy/turn. Elephant +5 damage.", "up_text": "You +1 Energy/turn. Elephant +8 damage.", "hero": "hai_ba_trung"},
	"quoc_han": {"name": "QUOC HAN", "ctype": "ATTACK", "cost": 3, "rarity": "legendary",
		"text": "Deal 10 damage x number of enemies.", "up_text": "Deal 14 damage x number of enemies.", "hero": "hai_ba_trung"},
	"doc_lap": {"name": "DOC LAP", "ctype": "SKILL", "cost": 3, "rarity": "legendary",
		"text": "Heal to full. Remove debuffs.", "up_text": "Heal to full. Remove debuffs. Gain 2 Energy.", "hero": "hai_ba_trung"},
	"trong_dong": {"name": "TRONG DONG", "ctype": "ATTACK", "cost": 2, "rarity": "legendary",
		"text": "ALL enemies lose 15 HP. You gain 10 Block.", "up_text": "ALL enemies lose 22 HP. You gain 15 Block.", "hero": "hai_ba_trung"},
	"loi_the": {"name": "LOI THE", "ctype": "POWER", "cost": 0, "rarity": "legendary",
		"text": "If Elephant dies: you +10 Strength permanently.", "up_text": "If Elephant dies: you +15 Strength permanently.", "hero": "hai_ba_trung"},
	"stampede": {"name": "STAMPEDE", "ctype": "ATTACK", "cost": 2, "rarity": "uncommon",
		"text": "Deal 8 damage to ALL enemies. Apply 1 Weak.", "up_text": "Deal 11 damage to ALL enemies. Apply 2 Weak.", "hero": "hai_ba_trung"},
	"bamboo_spike": {"name": "BAMBOO SPIKE", "ctype": "SKILL", "cost": 1, "rarity": "common",
		"text": "Gain 8 Block.", "up_text": "Gain 11 Block.", "hero": "hai_ba_trung"},
	"rebel_cry": {"name": "REBEL CRY", "ctype": "SKILL", "cost": 1, "rarity": "uncommon",
		"text": "Gain 2 Strength.", "up_text": "Gain 3 Strength.", "hero": "hai_ba_trung"},
	"trung_last_stand": {"name": "LAST STAND", "ctype": "SKILL", "cost": 2, "rarity": "rare",
		"text": "If HP below 50%, gain 20 Block and 3 Energy.", "up_text": "If HP below 50%, gain 28 Block and 4 Energy.", "hero": "hai_ba_trung"},
	"victory_horn": {"name": "VICTORY HORN", "ctype": "SKILL", "cost": 0, "rarity": "mythic",
		"text": "Elephant tramples immediately.", "up_text": "Elephant tramples immediately. Draw 1 card.", "hero": "hai_ba_trung"},
}

const STARTER_DECK := [
	"strike", "strike", "strike", "strike",
	"defend", "defend", "defend", "defend",
	"grace_note", "take_breath",
]
# v6.7: Hai Ba Trung starter (HBT-exclusive only, no shared cards)
const STARTER_DECK_HBT := [
	"arrow_shot", "arrow_shot", "arrow_shot", "arrow_shot",
	"doi_hinh", "doi_hinh", "doi_hinh", "doi_hinh",
	"spear_wall", "rice_provision",
]

static func starter_deck_for_hero(hero_id: String) -> Array:
	if hero_id == "hai_ba_trung":
		return STARTER_DECK_HBT.duplicate()
	return STARTER_DECK.duplicate()

const RARITY_WEIGHTS := {"common": 55, "uncommon": 28, "rare": 12, "mythic": 5}
const PRICE_BY_RARITY := {"common": 50, "uncommon": 85, "rare": 150, "mythic": 300}


static func get_def(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})


static var _uid_counter := 0


static func make(card_id: String, upgraded: bool = false, power: int = 0) -> Dictionary:
	_uid_counter += 1
	return {"id": card_id, "upgraded": upgraded, "power": power, "uid": _uid_counter}


static func card_name(card: Dictionary) -> String:
	var d := get_def(card["id"])
	var n: String = d.get("name", "???")
	if card.get("upgraded", false):
		n += "+"
	return n


static func card_text(card: Dictionary) -> String:
	# v5.2: upgraded cards show their improved numbers
	if card.get("upgraded", false):
		var d := get_def(card["id"])
		if d.has("up_text"):
			return str(d["up_text"])
	return str(get_def(card["id"]).get("text", ""))


static func is_playable(card: Dictionary) -> bool:
	return get_def(card["id"]).get("ctype", "") != ""


static func reward_pool() -> Array:
	# All non-starter, non-legendary cards (legendary is boss-only).
	var out := []
	for id in CARDS.keys():
		var d: Dictionary = CARDS[id]
		var r := str(d["rarity"])
		if r == "starter" or r == "legendary":
			continue
		out.append(id)
	return out


static func roll_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(1, 100)
	var acc := 0
	for r in ["common", "uncommon", "rare", "mythic"]:
		acc += RARITY_WEIGHTS.get(r, 0)
		if roll <= acc:
			return r
	return "common"


static func cards_of_rarity(rarity: String) -> Array:
	var pool := []
	for id in CARDS.keys():
		if CARDS[id]["rarity"] == rarity:
			pool.append(id)
	return pool


## v5.9: card ids usable by a hero: neutral cards + that hero's exclusives.
## Legacy "hero": true means Thach Sanh signature.
static func cards_for_hero(hero_id: String) -> Array:
	# v6.7: fully separate pools, no shared/neutral cards
	var pool := []
	for id in CARDS.keys():
		var h = CARDS[id].get("hero", false)
		if h is String:
			if str(h) == hero_id:
				pool.append(id)
		elif bool(h):
			if hero_id == "thach_sanh":
				pool.append(id)
		# neutral cards (h == false) are EXCLUDED - each hero has own pool
	return pool


## v5.9: legendary (or any rarity) pool filtered for a hero; falls back to
## the full pool when the hero has no card of that rarity (boss rewards).
static func cards_of_rarity_for_hero(rarity: String, hero_id: String) -> Array:
	var allowed := {}
	for id in cards_for_hero(hero_id):
		allowed[id] = true
	var out := []
	for id in cards_of_rarity(rarity):
		if allowed.has(id):
			out.append(id)
	if out.is_empty():
		out = cards_of_rarity(rarity)
	return out


## v5.9: reward pool (non-starter, non-legendary) filtered for a hero.
static func reward_pool_for_hero(hero_id: String) -> Array:
	var allowed := {}
	for id in cards_for_hero(hero_id):
		allowed[id] = true
	var out := []
	for id in reward_pool():
		if allowed.has(id):
			out.append(id)
	return out


static func random_card_id(rng: RandomNumberGenerator, rarity: String = "", hero_id: String = "") -> String:
	if rarity == "":
		rarity = roll_rarity(rng)
	var pool := []
	# v5.9: optional hero filter so each hero only sees their own + neutral cards.
	var base: Array = reward_pool_for_hero(hero_id) if hero_id != "" else reward_pool()
	for id in base:
		if CARDS[id]["rarity"] == rarity:
			pool.append(id)
	if pool.is_empty():
		return "wood_axe"
	return pool[rng.randi_range(0, pool.size() - 1)]
