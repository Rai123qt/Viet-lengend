# PROJECT WORLD VERB — Architecture

Godot 4.7.2 + GDScript, `gl_compatibility` renderer, 1280×720 landscape,
stretch `canvas_items` / `expand`. UI English. Package `com.rai.worldverb`.

## Layout

```
project.godot            # autoload: Game -> autoload/game_state.gd
main.tscn / main.gd      # screen router (Control), owns current screen
autoload/
  game_state.gd          # class_name GameState — campaign state (deck, gold,
                         #   relics, wakefulness, exp/level/perks, node_index,
                         #   equipment, hp). NOT logic; pure data + helpers.
  card_db.gd             # class_name CardDB — static card defs (35), CardDB.make()
  enemy_db.gd            # class_name EnemyDB — static enemy defs + patterns
battle/
  battle_state.gd        # class_name BattleState extends RefCounted — PURE LOGIC,
                         #   no UI. Turn loop, cards, intents, drowsy, silence/
                         #   collapse, equipment, Catch, boss phases. Headless-testable.
  battle_screen.gd       # class_name BattleScreen — UI observing BattleState.
ui/
  ui_helpers.gd          # class_name UIH — styled widgets, choose_card_popup
  card_widget.gd         # class_name CardWidget — card visual (art w/ fallback)
  title_screen.gd, equipment_screen.gd, map_screen.gd,
  reward_screen.gd, event_screen.gd, shop_screen.gd,
  clinic_screen.gd, end_screen.gd
tests/
  run_tests.gd           # 51 headless logic assertions
  bot_test.gd            # 200-battle autoplay + 5 campaign sims
  smart_bot.gd           # balance probe (boss winnability)
  smoke_ui.gd            # instantiates every screen, clicks a card, ends turn
assets/art/...           # bearer/, enemies/, cards/, bg/ (+ raw/ excluded from export)
```

## Key design decisions

- **Logic/UI split**: `BattleState` has zero UI dependencies. `battle_screen.gd`
  calls it and animates from `bs.events` (structured event list per action:
  `card`, `dmg_e/p`, `heal_p/e`, `drowsy_e/p`, `e_intent`, `vessel`, `phase2`, `end`).
- **Determinism**: `BattleState` takes an RNG seed; tests use fixed seeds.
- **Card identity**: every card instance has a unique `uid` (CardDB.make) —
  required because duplicate card dicts compare equal.
- **Autoloads in --script mode**: project autoloads DO instantiate at runtime,
  but the `--script` entry file cannot reference them by name at compile time —
  use `root.get_node("Game")` or construct `GameState.new()` directly.
- **Single enemy per battle** (per design doc) — no target selection; cards
  always affect "the enemy".
- **Armor expiry**: player armor → 0 at end of enemy turn; enemy armor → 0 at
  end of player turn.
- **Silence**: lasts until end of the *next* enemy turn (`silence_left = 1`,
  decremented at end of each enemy turn).
- **Catch**: any numeric intent; highest magnitude; full if silenced/collapsed
  else floor(half); token arrives at next player turn start (may exceed hand 5).
- **Combo**: `last_card_verb` = previously played card *this turn*.
- **DREAM dye**: heal → wakefulness −1 (campaign meter, min 0) → shuffle
  Nightmare into discard (unless Dreamcatcher + first DREAM of battle).
- **Boss phase 2**: at HP ≤ 50%, pattern resets to 2-intent pairs.
- **Vessel Tolerance**: requires HP > 4 (cannot suicide).

## Running tests

```bash
G=~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path ~/workspace/world-verb --import        # refresh class cache
$G --headless --path ~/workspace/world-verb --script res://tests/run_tests.gd
$G --headless --path ~/workspace/world-verb --script res://tests/bot_test.gd
$G --headless --path ~/workspace/world-verb --script res://tests/smoke_ui.gd
```

## Export

- Android: preset "Android", `use_gradle_build=false` (Gradle daemon broken in
  this sandbox; prebuilt-template export works — proven by godot-test).
- Web: preset "Web" → `web/world-verb.html`.
- `assets/art/raw/*` excluded from export.
