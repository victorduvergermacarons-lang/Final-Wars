class_name PartyPlayDef
extends Resource
## Every tuning number of loot, boss rolls, binding, trading and duels, in one
## place (content/rules/party_play.tres; CombatRules.party_play points at it).
## The host decides every roll, award, trade and duel with these.

@export_group("Personal loot")
## Seconds a drop lies on the ground before it is gone.
@export var drop_seconds: float = 300.0
## How close (tiles, centre to centre) a hero must be to pick up a drop.
@export var pickup_range: float = 1.6
## Drops land scattered this far (tiles) around where the enemy fell.
@export var drop_scatter: float = 0.8
## Heroes within this many tiles of a kill (and on its threat table) share its
## gold and materials, each getting the full amount.
@export var share_radius: int = 15
## Light beam height (screen pixels) and width, per drop.
@export var beam_height: float = 90.0
@export var beam_width: float = 6.0
## The end-of-fight summary after a boss stays this long (seconds).
@export var boss_summary_seconds: float = 12.0

@export_group("Boss rolls (Need / Greed / Pass)")
## Seconds each player has to choose; no choice (or a disconnect) is a Pass that
## earns no bonus.
@export var roll_seconds: float = 30.0
## The roll: a random whole number from roll_min to roll_max, plus the bonus.
@export var roll_min: int = 1
@export var roll_max: int = 100
## Bad-luck bonus: added for each Need roll lost and for each chosen Pass; back to
## 0 when the player wins a shared item.
@export var bonus_need_lost: int = 10
@export var bonus_pass: int = 15
## Ties are rolled again between the tied players, at most this many times (then
## the lowest hero id wins, so a roll always ends).
@export var max_rerolls: int = 10
## Seconds won items wait in the claim slot (mailbox) of a winner who was offline
## when awarded; 0 = forever.
@export var claim_seconds: float = 0.0

@export_group("Binding")
## A Bind on Pickup item can still be traded to someone who was in the fight it
## dropped in, for this long after it was looted (seconds).
@export var bop_trade_seconds: float = 1200.0

@export_group("Trading")
## Both players within this many tiles to request, and to keep, a trade.
@export var trade_range: float = 6.0
## A trade or duel request declines itself after this long (seconds).
@export var request_seconds: float = 30.0
## Item slots on each side of the trade window.
@export var trade_slots: int = 6

@export_group("Duels")
## The flag stands at the midpoint; the duel is fought within this radius (tiles).
@export var duel_radius: float = 10.0
## Countdown (seconds) between accepting and fighting.
@export var duel_countdown: float = 3.0
## Seconds outside the boundary before it counts as a forfeit.
@export var duel_out_of_bounds_seconds: float = 10.0
## The duel ends when a duelist would drop to this much health or less (they stay
## at it, alive).
@export var duel_yield_hp: float = 1.0
## Heroes within this many tiles of the flag hear who won.
@export var duel_announce_radius: float = 30.0
## Seconds the flag stays after the duel ends.
@export var duel_flag_linger: float = 3.0
## Duelists can't start a request farther apart than this (tiles).
@export var duel_request_range: float = 15.0
