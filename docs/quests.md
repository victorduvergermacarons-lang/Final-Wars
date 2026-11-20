# Quests

Every quest in the game, written by `tools/write_quest_list.gd` from `content/quests/`
(regenerate with `godot --headless --path . -s res://tools/write_quest_list.gd`; don't edit
this file by hand). What people say is in `content/dialogue/act1.json`.

15 quests: 7 main, 8 side.

| Quest | Kind | Level | Where | Giver → hand in | XP | Gold |
|-------|------|-------|-------|-----------------|----|------|
| [1-01 The Guild Comes to Millbrook](#1-01-the-guild-comes-to-millbrook) | Main | 1 | Millbrook | Maren Voss (Millbrook) | 120 | 15 |
| [1-02 Applicants Wanted](#1-02-applicants-wanted) | Main | 2 | The Crossing | Maren Voss (The Crossing) | 150 | 20 |
| [1-03 Wells for the Windsteppe](#1-03-wells-for-the-windsteppe) | Main | 3 | Windsteppe | Maren Voss (The Crossing) → Saran (Windsteppe) | 400 | 40 |
| [1-04 Grain for Deepcut](#1-04-grain-for-deepcut) | Main | 3 | Road to Deepcut | Guild Board (The Crossing) → Steward Brann (Deepcut) | 450 | 40 |
| [1-05 Fever in Millbrook](#1-05-fever-in-millbrook) | Main | 3 | Millbrook | Guild Board (The Crossing) → Healer Wenna Ashby (Millbrook) | 450 | 40 |
| [1-06 Recognition](#1-06-recognition) | Main | 6 | The Crossing | Maren Voss (The Crossing) → Prince Caedan Ashvale (The Crossing) | 450 | 60 |
| [1-07 The Silent Shaft](#1-07-the-silent-shaft) | Main | 8 | The Silent Shaft | Prince Caedan Ashvale (The Crossing) → Prince Caedan Ashvale | 1200 | 120 |
| [Wolves at the Gate](#wolves-at-the-gate) | Side | 1 | Greenfields | Captain Rowan (Millbrook) | 120 | 20 |
| [Word to Hilda](#word-to-hilda) | Side | 1 | Millbrook | Old Ottilie (Millbrook) → Hilda the Trader (Millbrook) | 40 | 5 |
| [Goblin Fetishes](#goblin-fetishes) | Side | 2 | Greenfields | Old Ottilie (Millbrook) | 180 | 25 |
| [The Bandit Camp](#the-bandit-camp) | Side | 2 | Greenfields | Captain Rowan (Millbrook) | 220 | 30 |
| [The Beast of Greenfields](#the-beast-of-greenfields) | Side | 3 | Greenfields | Captain Rowan (Millbrook) | 500 | 60 |
| [The White Death](#the-white-death) | Side | 4 | Windsteppe | Saran (Windsteppe) | 300 | 30 |
| [Shift Bell](#shift-bell) | Side | 6 | Deepcut | Mine Board (Deepcut) → Miner Ostrik (Deepcut) | 350 | 45 |
| [Pins on the Map](#pins-on-the-map) | Side | 7 | The Crossing | Guild Board (The Crossing) → Maren Voss (The Crossing) | 500 | 40 |

## 1-01 The Guild Comes to Millbrook

- **Id:** `act1_01_guild_comes_to_millbrook` (`content/quests/act1_01_guild_comes_to_millbrook.tres`)
- **Main quest**, level 1, Millbrook
- **Giver:** Maren Voss (Millbrook); **hand in:** Maren Voss (Millbrook)
- **Objectives:**
  - Kill: 3 × Wolf ("Wolves driven off the fields")
  - Kill: 2 × Boar ("Boars driven off the fields")
- **Rewards:** 120 XP, 15 gold, 2 × Minor Health Potion
  - Earth heroes: given Quarryman's Gloves
  - Water heroes: given Riverweave Gloves
  - Fire heroes: given Emberstitch Gloves
  - Air heroes: given Breezecloth Wraps

> Wolves came down off the hills last night, and the boars followed them into the south fields. The Guild sent me to see how Millbrook copes. Show me. Drive them off the fields beyond the south bridge, three wolves and two boars, and I'll be watching.

## 1-02 Applicants Wanted

- **Id:** `act1_02_applicants_wanted` (`content/quests/act1_02_applicants_wanted.tres`)
- **Main quest**, level 2, The Crossing
- **Giver:** Maren Voss (The Crossing); **hand in:** Maren Voss (The Crossing)
- **Needs first:** 1-01 The Guild Comes to Millbrook
- **Objectives:**
  - Talk: Warden Iska Dorne (The Crossing) ("Register with Warden Dorne at the Guild Hall")
  - Talk: Quartermaster Ilse Harrow (The Crossing) ("Draw a Guild kit from the quartermaster")
- **Rewards:** 150 XP, 20 gold
  - Choice of one: Minor Mana Potion, Minor Health Potion
  - Earth heroes: given Quarryman's Hood
  - Water heroes: given Riverweave Hood
  - Fire heroes: given Emberstitch Cap
  - Air heroes: given Breezecloth Hood

> The Guild takes anyone willing, but there's a ledger for everything. Register with Warden Dorne at the hall door and draw a kit from Quartermaster Harrow. Then I'll have real work for you.

## 1-03 Wells for the Windsteppe

- **Id:** `act1_03_wells_for_the_windsteppe` (`content/quests/act1_03_wells_for_the_windsteppe.tres`)
- **Main quest**, level 3, Windsteppe
- **Giver:** Maren Voss (The Crossing); **hand in:** Saran (Windsteppe)
- **Needs first:** 1-02 Applicants Wanted
- **Objectives:**
  - Escort: Well-Digging Crew in Windsteppe, 4 waypoints ("Escort the well-diggers to Tsaga's Camp")
  - Kill: 4 × Iron Wolf ("Iron wolves driven off")
- **Rewards:** 400 XP, 40 gold, 2 × Minor Health Potion
  - Earth heroes: given Quarryman's Boots
  - Water heroes: given Riverweave Sandals
  - Fire heroes: given Emberstitch Boots
  - Air heroes: given Breezecloth Shoes

> The clans on the Windsteppe have lost their wells to the drought, and their herds are thinning. The Guild has hired a digging crew. Walk them out to Tsaga's Camp, where the iron wolves have grown bold, and see the wells sunk. Saran will meet you there.

## 1-04 Grain for Deepcut

- **Id:** `act1_04_grain_for_deepcut` (`content/quests/act1_04_grain_for_deepcut.tres`)
- **Main quest**, level 3, Road to Deepcut
- **Giver:** Guild Board (The Crossing); **hand in:** Steward Brann (Deepcut)
- **Needs first:** 1-02 Applicants Wanted
- **Objectives:**
  - Escort: Guild Grain Wagon in Road to Deepcut, 5 waypoints ("Escort the grain wagon to Deepcut's end of the road")
- **Rewards:** 450 XP, 40 gold, 2 × Minor Health Potion
  - Earth heroes: in the choice of one: Granite Ring, Pillar Scroll
  - Water heroes: in the choice of one: Tidestone Ring, Mist Scroll
  - Fire heroes: in the choice of one: Cinder Ring, Spark Scroll
  - Air heroes: in the choice of one: Gale Ring, Featherstep Scroll

> RELIEF: A grain wagon is bound for Deepcut, where the miners' families have had a lean season. Escort required: bandits reported on the road. Report to Steward Brann on arrival. (Floor Guild)

## 1-05 Fever in Millbrook

- **Id:** `act1_05_fever_in_millbrook` (`content/quests/act1_05_fever_in_millbrook.tres`)
- **Main quest**, level 3, Millbrook
- **Giver:** Guild Board (The Crossing); **hand in:** Healer Wenna Ashby (Millbrook)
- **Needs first:** 1-02 Applicants Wanted
- **Handed over on accepting:** 3 × Fever Draught
- **Objectives:**
  - Talk: Odo the Apothecary (The Crossing) ("Ask Odo the Apothecary for healers")
  - Deliver: 3 × Fever Draught to Healer Wenna Ashby (Millbrook) ("Fever draughts brought to Healer Wenna")
  - Investigate: 1 spots in Millbrook ("The grey river examined in Millbrook")
  - Investigate: 1 spots in Road to Deepcut ("The grey stream examined on the Road to Deepcut")
  - Investigate: 1 spots in Deepcut ("The stream's source found in Deepcut")
- **Rewards:** 450 XP, 40 gold, 2 × Minor Health Potion, 2 × Minor Mana Potion
  - Choice of one: Rusty Shortsword, Hunter's Shortbow, Iron Mallet
  - Earth heroes: in the choice of one: Bedrock Charm
  - Water heroes: in the choice of one: Pearl Pendant
  - Fire heroes: in the choice of one: Ashglass Pendant
  - Air heroes: in the choice of one: Feather Charm

> URGENT: Fever in Millbrook. Healers needed. Odo the Apothecary, at the Crossing market, has supplies. Bring them to Healer Wenna, and find what is making the village sick. (Floor Guild)

## 1-06 Recognition

- **Id:** `act1_06_recognition` (`content/quests/act1_06_recognition.tres`)
- **Main quest**, level 6, The Crossing
- **Giver:** Maren Voss (The Crossing); **hand in:** Prince Caedan Ashvale (The Crossing)
- **Needs first:** 1-03 Wells for the Windsteppe, 1-04 Grain for Deepcut, 1-05 Fever in Millbrook
- **Objectives:**
  - Talk: Prince Caedan Ashvale (The Crossing) ("Hear out Prince Caedan Ashvale")
- **Rewards:** 450 XP, 60 gold
  - Earth heroes: given Stomp Scroll
  - Water heroes: given Tidal Scroll
  - Fire heroes: given Sun Warrior's Breath Scroll
  - Air heroes: given Gale Scroll
- **Sets world flag:** `brann_descended`

> Three missions, three successes. The ledgers are delighted with you. Come to the hall: the Prince himself has asked to meet our newest members.

## 1-07 The Silent Shaft

- **Id:** `act1_07_the_silent_shaft` (`content/quests/act1_07_the_silent_shaft.tres`)
- **Main quest**, level 8, The Silent Shaft
- **Giver:** Prince Caedan Ashvale (The Crossing); **hand in:** Prince Caedan Ashvale
- **Needs first:** 1-06 Recognition
- **Objectives:**
  - Reach: within 3 tiles of (26, 20) in The Silent Shaft ("Ride the lift down to the deep seams")
  - Reach: within 2 tiles of (49, 14) in The Silent Shaft ("Find where the silence comes from")
  - Kill: 1 × The Grey Heart ("Break the Grey Heart")
  - Talk: Prince Caedan Ashvale ("Speak with Prince Caedan")
- **Rewards:** 1200 XP, 120 gold, 3 × Minor Health Potion, 3 × Minor Mana Potion
  - Choice of one: Scroll of the Fireball, Glacier Scroll, Bulwark Scroll
- **Sets world flag:** `act1_complete`
- **Ends Act 1**

> The deep seams went silent three days ago. Then Steward Brann went down after his miners, alone, and the silence took him too. I can't order anyone into that dark. I'm asking. The mine entrance is in Deepcut's yard. Take friends: three of you at the least.

## Wolves at the Gate

- **Id:** `wolves_at_the_gate` (`content/quests/wolves_at_the_gate.tres`)
- **Side quest**, level 1, Greenfields
- **Giver:** Captain Rowan (Millbrook); **hand in:** Captain Rowan (Millbrook)
- **Objectives:**
  - Kill: 4 × Wolf ("Wolves slain")
- **Rewards:** 120 XP, 20 gold

> Wolves have been taking sheep right outside the east gate. Thin the pack: four should teach them.

## Word to Hilda

- **Id:** `word_to_hilda` (`content/quests/word_to_hilda.tres`)
- **Side quest**, level 1, Millbrook
- **Giver:** Old Ottilie (Millbrook); **hand in:** Hilda the Trader (Millbrook)
- **Objectives:**
  - Talk: Hilda the Trader (Millbrook) ("Tell Hilda about the herbs")
- **Rewards:** 40 XP, 5 gold, 2 × Minor Health Potion

> Hilda at the stall has been asking after my herbs. Tell her the frost got them this year, would you? My knees won't carry me there.

## Goblin Fetishes

- **Id:** `goblin_fetishes` (`content/quests/goblin_fetishes.tres`)
- **Side quest**, level 2, Greenfields
- **Giver:** Old Ottilie (Millbrook); **hand in:** Old Ottilie (Millbrook)
- **Objectives:**
  - Collect: 5 × Goblin Fetish ("Goblin Fetishes")
- **Rewards:** 180 XP, 25 gold
  - Choice of one: Iron Helm, Swift Boots, Hunter's Shortbow

> The goblin shamans on the western hill carve fetishes that sour the wells. Bring me five and I'll see them burned.

## The Bandit Camp

- **Id:** `bandit_camp` (`content/quests/bandit_camp.tres`)
- **Side quest**, level 2, Greenfields
- **Giver:** Captain Rowan (Millbrook); **hand in:** Captain Rowan (Millbrook)
- **Needs first:** Wolves at the Gate
- **Objectives:**
  - Reach: within 2 tiles of (22, 20) in Greenfields ("Find the bandit camp")
  - Kill: 2 × Bandit Brute ("Bandit Brutes broken")
- **Rewards:** 220 XP, 30 gold

> Those wolves were fleeing something. Scouts saw bandits camped at the southern end of Greenfields, across the river. Find their camp (look for the red banner) and break their two brutes.

## The Beast of Greenfields

- **Id:** `beast_of_greenfields` (`content/quests/beast_of_greenfields.tres`)
- **Side quest**, level 3, Greenfields
- **Giver:** Captain Rowan (Millbrook); **hand in:** Captain Rowan (Millbrook)
- **Needs first:** The Bandit Camp
- **Objectives:**
  - Kill: 1 × Old Grizzlehide ("Old Grizzlehide slain")
- **Rewards:** 500 XP, 60 gold
  - Choice of one: Scroll of the Fireball, Glacier Scroll, Bulwark Scroll
- **Sets world flag:** `grizzlehide_slain`

> Old Grizzlehide. He roams the fields between the river crossings and nothing alone survives him. Gather friends — at least four — and end him.

## The White Death

- **Id:** `act1_side_the_white_death` (`content/quests/act1_side_the_white_death.tres`)
- **Side quest**, level 4, Windsteppe
- **Giver:** Saran (Windsteppe); **hand in:** Saran (Windsteppe)
- **Needs first:** 1-03 Wells for the Windsteppe
- **Handed over on accepting:** Winter Stores
- **Objectives:**
  - Collect: 4 × Iron Wolf Pelt ("Iron wolf pelts")
  - Deliver: 1 × Winter Stores to Elder Tsaga (Windsteppe) ("Winter stores brought to Elder Tsaga")
- **Rewards:** 300 XP, 30 gold, 3 × Minor Health Potion

> The cold is killing what's left of the herds, and the clan with them. Bring me iron wolf pelts to line the gers, four will do, and take these stores to Elder Tsaga. The Guild sent them; she'll want them from Guild hands.

## Shift Bell

- **Id:** `act1_side_shift_bell` (`content/quests/act1_side_shift_bell.tres`)
- **Side quest**, level 6, Deepcut
- **Giver:** Mine Board (Deepcut); **hand in:** Miner Ostrik (Deepcut)
- **Needs first:** 1-04 Grain for Deepcut
- **Objectives:**
  - Use: Collapsed Shaft (Deepcut) ("Rubble cleared from the collapsed shaft")
  - Kill: 3 × Human Husk ("Husks put down")
  - Talk: Miner Ostrik (Deepcut) ("Bring Miner Ostrik out")
- **Rewards:** 350 XP, 45 gold, 2 × Minor Health Potion

> SHIFT BELL: Shaft Seven has rung its bell. Men trapped below. Volunteers wanted to clear the rubble. Things have been seen walking near the old workings: go armed. (Steward Brann)

## Pins on the Map

- **Id:** `act1_side_pins_on_the_map` (`content/quests/act1_side_pins_on_the_map.tres`)
- **Side quest**, level 7, The Crossing
- **Giver:** Guild Board (The Crossing); **hand in:** Maren Voss (The Crossing)
- **Needs first:** 1-06 Recognition
- **Objectives:**
  - Reach: within 2 tiles of (22, 20) in Millbrook ("Millbrook's grey river visited")
  - Reach: within 2 tiles of (15, 21) in Windsteppe ("Tsaga's Camp visited")
  - Reach: within 2 tiles of (31, 9) in Road to Deepcut ("The ambush on the Road to Deepcut visited")
  - Reach: within 2 tiles of (32, 21) in Deepcut ("Deepcut's tailings pond visited")
  - Use: Guild Map (The Crossing) ("Every site marked on the Guild Map")
- **Rewards:** 500 XP, 40 gold, 2 × Minor Mana Potion

> SURVEY: Confirm every site the Guild has relieved this season, Millbrook's river, Tsaga's Camp, the Deepcut road and the Deepcut works, and mark them on the great map in the hall. (Floor Guild)
