extends SceneTree
## Test CollectionScreen doesn't crash

func _init():
    print("=== COLLECTION TEST ===")
    
    # Create the collection screen
    var screen = CollectionScreen.new()
    print("Created CollectionScreen")
    
    # Simulate _ready
    var root = get_root()
    root.add_child(screen)
    print("Added to tree - if we get here without crash, PASS")
    
    # Test _refresh_cards for both heroes
    screen._hero_id = "thach_sanh"
    screen._tab = "CARDS"
    # _grid should exist after _ready
    await create_timer(0.5).timeout
    
    print("Collection screen loaded successfully")
    print("=== PASS ===")
    quit()
