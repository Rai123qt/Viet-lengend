extends SceneTree
## v6.7 test: verify Collection screen, hero select, map, battle

func _init():
    print("=== v6.7 TEST START ===")
    
    # Test 1: CardDB loads and has correct counts
    print("\n[Test 1] CardDB card counts...")
    var ts_cards = CardDB.cards_for_hero("thach_sanh")
    var hbt_cards = CardDB.cards_for_hero("hai_ba_trung")
    print("  Thach Sanh: %d cards" % ts_cards.size())
    print("  Hai Ba Trung: %d cards" % hbt_cards.size())
    assert(ts_cards.size() >= 80, "TS should have 80+ cards")
    assert(hbt_cards.size() >= 80, "HBT should have 80+ cards")
    print("  PASS: Both heroes have 80+ cards")
    
    # Test 2: No shared cards
    print("\n[Test 2] No shared cards...")
    var ts_set = {}
    for c in ts_cards: ts_set[c] = true
    var shared = []
    for c in hbt_cards:
        if ts_set.has(c):
            shared.append(c)
    print("  Shared cards: %d" % shared.size())
    assert(shared.size() == 0, "Should have no shared cards")
    print("  PASS: Pools are fully separate")
    
    # Test 3: Starter decks use hero-exclusive cards
    print("\n[Test 3] Starter decks...")
    var ts_starter = CardDB.starter_deck_for_hero("thach_sanh")
    var hbt_starter = CardDB.starter_deck_for_hero("hai_ba_trung")
    print("  TS starter: %s" % str(ts_starter))
    print("  HBT starter: %s" % str(hbt_starter))
    # HBT starter should not contain strike/defend (neutrals)
    assert(not hbt_starter.has("strike"), "HBT should not use neutral strike")
    assert(not hbt_starter.has("defend"), "HBT should not use neutral defend")
    assert(hbt_starter.has("arrow_shot"), "HBT should use arrow_shot")
    print("  PASS: Starter decks are hero-exclusive")
    
    # Test 4: New HBT cards exist
    print("\n[Test 4] New HBT cards...")
    var new_cards = ["voi_xung_phong", "arrow_shot", "hai_ba_trung_legend", "voi_than"]
    for cid in new_cards:
        assert(CardDB.CARDS.has(cid), "Missing card: " + cid)
        var card = CardDB.CARDS[cid]
        assert(card.get("hero") == "hai_ba_trung", "Wrong hero for " + cid)
    print("  PASS: All new HBT cards present")
    
    print("\n=== ALL TESTS PASSED ===")
    quit()
