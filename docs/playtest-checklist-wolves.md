# Playtest checklist: the animated wolves

Wolves now have real animated art. Other enemies are still red diamonds.

**The pack:** three wolves wait in Greenfields' far north-west corner. From the
town edge, walk north along the west side of the map.

**Debug console (test builds):** `` ` `` opens it.
- `spawn wolf 1 3` puts three wolves next to you.
- `heal` refills you between tries.

## Solo

- [ ] **Facing, all 4 directions.** Walk around a wolf in a circle (it turns to
      follow you), or spawn a few and let them chase you.
      **Expect:** it faces you correctly from each side:
      - head toward the bottom-left
      - head toward the bottom-right
      - back turned, looking up-left
      - back turned, looking up-right
- [ ] **Feet on the tile.** Look at an idle wolf on flat grass.
      **Expect:** its paws and shadow sit in the middle of its tile, neither floating
      above the grass nor sunk into it. Same on a hill or the path.
- [ ] **Idle.** Watch an idle wolf for a few seconds.
      **Expect:** a slow breathing loop, not frozen. Wolves standing side by side
      don't move in perfect sync.
- [ ] **Run, no sliding.** Let a wolf chase you across open grass.
      **Expect:** it moves smoothly tile to tile, and its legs keep pace with the
      ground. No ice-skating, and no darting forward then pausing.
- [ ] **Bite lands on the snap.** Stand still next to a wolf and watch closely.
      **Expect:**
      - it crouches and snarls, then leaps
      - the damage number appears exactly when the jaws snap (the white bite streak),
        not when it starts crouching
      - it doesn't move during the bite
- [ ] **Dodging the bite.** Step away while it crouches.
      **Expect:** the bite misses ("Whiff"), the same as before, with a little more
      time to react than earlier (0.4 s instead of 0.3 s).
- [ ] **Howl.** Walk toward the pack until one wolf notices you.
      **Expect:** that wolf stops and howls (head up, about a second, with a "Howl"
      bar). When the howl ends, the other two come running, even if they hadn't
      seen you.
- [ ] **Howl when hit first.** Hit an unaware wolf from range, e.g. Fire Dart.
      **Expect:** it howls too before attacking.
- [ ] **Pack range.** A lone wolf far away (more than 6 tiles) doesn't come when the
      pack howls. The pulled-in wolves don't howl again.
- [ ] **Hit flash.** Hit a wolf.
      **Expect:** its body flashes white for an instant; its shadow stays dark.
- [ ] **Death and fade-out.** Kill a wolf.
      **Expect:**
      - it plays a collapse animation once and lies still for about 4 seconds
      - it then fades away over about a second
      - no name or health bar shows over the corpse
      - it comes back at its spot later, as before

## With a friend (two players)

- [ ] Both players stand where they can see the pack, and one walks in to pull it.
      **Expect:** both see the same wolf howl at the same moment, and the others
      start running at the same time.
- [ ] Both watch the same wolf bite one of you.
      **Expect:** both see the snap at the same moment the damage number appears.
- [ ] Kill a wolf together.
      **Expect:** both see it collapse and fade at the same time.
- [ ] The player who joined (not the host) checks facing, running and the hit flash.
      **Expect:** everything looks the same as on the host's screen.
