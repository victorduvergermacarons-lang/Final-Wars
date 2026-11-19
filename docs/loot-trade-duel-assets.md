# Loot, rolls, trading, duels, the Wilds: art and audio still needed

Everything below works today with placeholder drawing (shapes, the paper UI theme);
these are the assets that would replace the placeholders. Keys and paths follow the
existing conventions (see `AUDIO_SPEC.md` for sound formats).

## Art
| Asset | Used by | Placeholder now |
|-------|---------|-----------------|
| Loot beam (one sprite or shader, tinted per rarity: white, green, blue, purple, gold) | `WorldView._draw_drops` | three stacked lines and a ground ring |
| Drop glyph / bag icon on the ground | `WorldView._draw_drops` | a small dot |
| Legendary rarity border, 28x29 (`assets/ui/rarity/legendary.png`) | bag and equipment slots | the Epic border |
| Item icons (any item) | roll window, trade window, contract, boss summary | item names in rarity colour |
| Roll window frame and Need / Greed / Pass buttons (die, coins, cross) | `RollWindow` | paper panel and leather buttons |
| Trade window frame ("You give" / "You get" panels, gold coin) | `TradeWindow` | paper panel |
| Trade contract sheet (a sealed contract look, two signature lines) | `TradeWindow` contract view | the same paper panel |
| Request window (trade and duel variants) | `RequestWindow` | paper panel |
| Boss loot summary frame | `BossLootSummary` | paper panel |
| Duel flag (pole and banner, a small idle flutter) | `WorldView._draw_duels` | a drawn pole and red/white triangles |
| Duel boundary marking (ground ring) and countdown numerals | `WorldView._draw_duels` | a red outline and a gold number |
| Player context menu (Trade / Duel) skin | `Hud.player_menu` | Godot's default popup |
| Trees for the Wilds (the tileset has none) | `content/zones/wilds.tres` | leafy bushes, logs and stumps |

## Audio (keys are listed in `AUDIO_SPEC.md`; files go in `audio/sfx/world/<key>.wav`)
| Key | When |
|-----|------|
| `world_loot_common` | you pick up a Common item |
| `world_loot_uncommon` | an Uncommon item |
| `world_loot_rare` | a Rare item |
| `world_loot_epic` | an Epic item |
| `world_loot_legendary` | a Legendary item |
| `world_way_out` | a cleared dungeon's way out opens |
| `ambience_wilds` | the Wilds' ambience (`audio/ambience/`) |

Not yet keyed (no sound plays; suggested keys if wanted): `ui_roll_open`, `ui_roll_need`,
`ui_roll_greed`, `ui_roll_pass`, `world_roll_won`, `ui_trade_request`, `ui_trade_open`,
`ui_trade_offer`, `ui_trade_done`, `ui_trade_cancel`, `ui_duel_request`, `world_duel_countdown`,
`world_duel_start`, `world_duel_end`.
