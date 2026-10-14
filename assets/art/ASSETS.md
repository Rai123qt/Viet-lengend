# PROJECT WORLD VERB — Art manifest

Style: stylized 2D in the manner of Limbus Company (ProjectMoon) — gritty painterly
shading, sharp rough linework, dark blue-black palette, teal/amber accents.
AI-generated art was user-approved for card art and sprites; frame/text/cost are
drawn in code by `ui/card_widget.gd`.

Raw generator outputs live in `raw/` (excluded from export via `export_presets.cfg`).
`magenta_to_alpha2.py` chroma-keys `#FF00FF` -> alpha for sprites.

## bearer/ (PNG, transparent) — Bearer, man in his early 30s, long dark coat, bureau hat, brass Verb Cage on forearm
- idle, run, run2, slash, slash2, cast, guard, hurt, defeated
- avatar.png — player dossier headshot portrait

## enemies/ (PNG, transparent, facing LEFT)
- restless_citizen_{idle,attack,hurt}
- dream_eater_{idle,attack,hurt}
- insomnia_warden_{idle,attack,hurt}
- sandman_{idle,attack,hurt}
- warden_captain_{idle,attack,hurt}
- keeper_of_sleep_{idle,attack,hurt} + keeper_of_sleep_phase2 (boss phase 2)

## cards/ (WEBP, illustration only — no text) — loaded as `<card_id>.webp` by `ui/card_widget.gd`
31 AI-painted: barricade, bottled_scream, cage_rattle, containment, counting_sheep,
deep_breath, deep_slumber, drowsy_draft, false_awakening, hold_fast, hollow_echo,
iron_vessel, jolt_awake, last_light, lucid_strike, lullaby, nightmare_cut,
recurring_dream, rest_brace, second_wind, shared_dream, sleep_talk,
sleepwalkers_edge, smother, soothing_hum, sturdy_dreams, wide_awake_slash,
unleashed_nightmare, unleashed_rest, unleashed_lull, unleashed_dream.

4 use the code-drawn fallback in `CardWidget._fallback_art` (AI generation declined
by the image pipeline for those prompts): night_terror, dream_mend,
nightmare_curse, vessels_due.

## bg/ (WEBP, 16:9)
- battle_street.webp — battle + title screen
- event.webp, shop.webp, clinic.webp

## battle_screen sprite mapping
- Bearer: bearer/bearer_idle.png (static pose during battle; attack animations use
  movement tween + slash VFX drawn in code)
- Enemies: enemies/<enemy_id>_idle.png (attack/hurt variants exist for future
  animation passes; current damage feedback is red flash + shake)
