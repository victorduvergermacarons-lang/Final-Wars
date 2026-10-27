# Quests and dialogue: how to edit them

## Rewriting what people say

Every line of dialogue is in **one file**: `content/dialogue/act1.json`. Change the
text and restart the game; nothing else needs touching. Keep the ids (the part
before the colon) as they are: the game finds lines by id.

A line is either plain text:

```json
"npc.sabra_venn.greeting": "Sabra Venn, of the Ember Hand. Warm day, isn't it?"
```

or a block with more to it:

```json
"npc.warden_dorne.greeting": {
	"text": "Iska Dorne, Warden of the Floor Guild hall here at the Crossing.",
	"choices": [
		{"text": "What is the Floor Guild?", "next": "npc.warden_dorne.about_guild"},
		{"text": "Who are the Ember Hand?", "next": "npc.warden_dorne.about_ember"}
	]
},
"npc.warden_dorne.about_guild": {"text": "We keep the roads...", "next": "npc.warden_dorne.about_guild_2"}
```

- `text`: what is said. `[b]bold[/b]` and `[i]italics[/i]` work.
- `speaker`: who says it: an NPC's id, or `hero` (the player). Leave it out and
  it's whoever you are talking to.
- `next`: the line that follows (the player gets a **Continue** button).
- `choices`: the player's answers, each leading to a line.

A chain ends on a line with neither `next` nor `choices`; the player then gets
**Back** (to the NPC's main page). If a line id is missing, the game shows a short
default text, so nothing breaks while you write. The tests list any `next` that
points at a line that doesn't exist.

### Which ids the game looks for

| Id | When it's said |
|----|----------------|
| `npc.<npc>.greeting` | Talking to an NPC, reading a board, using an object |
| `npc.<npc>.greeting.<world flag>` | The same, once that world flag is set (e.g. `act1_complete`) |
| `quest.<quest>.offer` | The quest offer (objectives and rewards are shown under it) |
| `quest.<quest>.restart` | The offer again after the quest failed (else `offer`) |
| `quest.<quest>.accept` / `.decline` | The player's two answers to the offer (default "Accept" / "Not now") |
| `quest.<quest>.accepted` / `.declined` | What the NPC says to each answer |
| `quest.<quest>.progress` | Talking to the hand-in NPC before it's done |
| `quest.<quest>.complete` | Handing it in |
| `quest.<quest>.failed` | Shown when the quest fails (escort lost) |
| `quest.<quest>.world_flag` | Announced to everyone when the quest sets its world flag |
| `quest.<quest>.interact.<i>` | Using the object of objective `i` |
| `quest.<quest>.talk.<i>` | What the person of a Talk objective `i` says when you come to them for it |
| `quest.<quest>.deliver.<i>` | Handing over the items of objective `i` |
| `quest.<quest>.escort.<i>` | The escorted NPC or caravan setting off |
| `quest.<quest>.spot.<i>.<n>` | What you find at investigate spot `n` of objective `i` |

Objectives count from 0, spots too.

## Quests

Each quest is a file in `content/quests/` (open it in Godot's inspector, or as
text). What it holds:

- `id`, `title` (its name), `category` (Main or Side), `area` (shown in the log)
- `giver` (an NPC or quest board id) and `turn_in` (empty = the giver)
- `prerequisites` (quests to finish first) and `min_level`
- `objectives`, `given_items` (handed over on accept, e.g. a letter to deliver)
- rewards: `reward_xp`, `reward_gold`, `reward_items`, `reward_choices`
- `sets_world_flag` (optional, once per world)
- `ends_act` and `return_zone` (optional): handing it in ends that act of the story; the
  End of Act screen shows the party's records, then sends them to `return_zone`
  (1-07: act 1, the Crossing)

Objective kinds:

| Kind | Fields | Done when |
|------|--------|-----------|
| Kill | `enemy`, `count` | that many killed |
| Collect | `item`, `count` | that many in the bag (taken at hand-in) |
| Talk | `npc` | you talk to them |
| Reach | `zone`, `tile`, `radius` | you stand that close (the area glows) |
| Escort | `npc`, `zone`, `path` (waypoints) | the NPC or caravan reaches the last point alive; talk to it to set off |
| Deliver | `npc`, `item`, `count` | you talk to them with the items in your bag |
| Interact | `npc` (an object) | you use it (E) |
| Investigate | `zone`, `spots` | you've examined every spot (they glow; E beside one) |

## People, boards and objects

Each is a file in `content/npcs/`: `id`, `display_name`, `kind` (Person, Board,
Object, Caravan), `faction` (Townsfolk, Floor Guild, Ember Hand, Bedrun, Vael,
None). A caravan or anyone escorted needs `max_hp` (and may have defenses).
Place them in a zone's `npcs` list (zone file, with a tile and facing).
`gone_after_flag` (optional): they leave the world once that world flag is set
(Steward Brann, after 1-06). Someone who appears when a boss falls is the
encounter's `victory_npc` (`content/encounters/`), like Caedan in the Silent Shaft.

Until they have art, they're drawn as a shape for their kind in their faction's
colour, with their name above, and their portrait is a frame in that colour with
their initials. To give one real art, set `portrait` (a picture for the dialogue
box) and `art` (a creature sheet, like the wolf's): nothing else changes.
