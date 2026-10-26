# Writes the timing design into design/Ability_Tree.xlsx through Excel (keeps its
# formatting): four columns on the Abilities tab and the "Timing Rules" tab (rebuilt
# each run). Run from the project folder:
#   powershell -File tools/once/add_timing_to_ability_sheet.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path [-Only B01,B02]
# First run (2026-10-26): adds the columns and every design below. Once the columns
# exist, only the rows named in -Only are rewritten (so edits made in the sheet stay).
# ASCII only: dashes in zone ranges are turned into en dashes here.
param([string]$Path, [string[]]$Only = @())

$dash = [string][char]0x2013
$M = "Manual"
$G = "Generated (AI, not yet confirmed)"

# id = status, bar seconds (0 = no bar), zones, notes
$design = [ordered]@{
  "S01" = @($M, 1.0, "Tap 0.35-0.65; Crit 0.45-0.55", "Designer's bar: one beat in the middle.")
  "F01" = @($M, 1.0, "Tap 0.70-1.00; Crit 0.90-1.00", "Designer's bar: both zones at the very end.")
  "W02" = @($M, 3.0, "Hold 0.75-2.75", "Designer's bar: hold 2 s, ending 0.25 s before the bar.")
  "F02" = @($G, 1.2, "Tap 0.85-1.15; Crit 1.05-1.15", "Fire: a late snap like Fire Punch, a little longer (bigger hit plus a burn).")
  "F03" = @($G, 0.8, "Tap 0.50-0.75; Crit 0.65-0.75", "Fire: quick projectile, short bar, late snap. The dart flies when you press.")
  "F04" = @($G, 0, "", "No bar: an instant self-buff off the GCD.")
  "F05" = @($G, 0, "", "No bar: a dash (instants never have one).")
  "F06" = @($G, 1.5, "Tap 1.05-1.40; Crit 1.25-1.35", "Fire: a longer wind-up for a piercing line, late snap.")
  "F07" = @($G, 2.0, "Tap 1.45-1.85; Crit 1.70-1.80", "Fire: big spell, long bar, one late beat. The 0.4 s area warning still follows the press.")
  "F08" = @($G, 1.5, "Tap 1.00-1.40; Crit 1.25-1.35", "Fire: late snap; power scales the burn per second.")
  "F09" = @($G, 1.5, "Tap 1.00-1.40; Crit 1.25-1.35", "Fire: late snap. Planned: three taps, one per hit, once bars take several inputs.")
  "W01" = @($G, 2.0, "Hold 0.50-1.75", "Water: a hold. Timing power scales the heal.")
  "W03" = @($G, 0, "", "No bar: a buff (timing has nothing to scale yet).")
  "W04" = @($G, 1.5, "Hold 0.40-1.25", "Water: a short hold; the shard flies when you let go.")
  "W05" = @($G, 2.5, "Hold 0.50-2.25", "Water: a long hold for a long heal; power scales the total healing.")
  "W06" = @($G, 2.0, "Hold 0.50-1.75", "Water: a hold building the wave.")
  "W07" = @($G, 2.5, "Hold 0.75-2.25", "Water: a hold; the drain heals you half the (scaled) damage.")
  "W08" = @($G, 0, "", "No bar: a buff (timing has nothing to scale yet).")
  "W09" = @($G, 2.5, "Hold 0.75-2.25", "Water: a hold. The 0.4 s area warning still follows the release.")
  "A01" = @($G, 0.8, "Tap 0.20-0.45; Crit 0.30-0.40", "Air: quick, early beat.")
  "A02" = @($G, 0, "", "No bar: an interrupt must be instant to catch a wind-up.")
  "A03" = @($G, 0, "", "No bar: movement buff off the GCD.")
  "A05" = @($G, 1.2, "Tap 0.30-0.60; Crit 0.40-0.50", "Air: early beat in a slightly longer bar.")
  "E01" = @($G, 1.6, "Tap 1.10-1.50; Crit 1.25-1.35", "Earth: one heavy beat, a wide window late in a long bar.")
  "E03" = @($G, 0, "", "No bar: terrain (timing has nothing to scale yet).")
  "E04" = @($G, 0, "", "No bar: a taunt.")
  "E05" = @($G, 0, "", "No bar: terrain wall.")
  "S04" = @($G, 0, "", "No bar: a dash then a strike (dashes have no bar).")
  "B01" = @($M, 2.0, "Hold 0.25-1.75", "Designer's bar: hold 1.5 s at the end, ending 0.25 s before the bar. The arrow flies where the cursor points when you let go.")
  "B02" = @($M, 4.0, "Tap 0.20-0.60; Crit 0.35-0.45; Hold 1.00-3.75", "Designer's bar: a tap at the start (nock), then hold to the end (draw), ending 0.25 s before the bar. Replaces its 1 s draw. Fires where the cursor points when you let go.")
  "H01" = @($G, 1.2, "Tap 0.80-1.10; Crit 0.95-1.05", "Hammer: a late heavy beat; replaces its 0.3 s wind-up.")
  "H02" = @($G, 1.5, "Tap 1.00-1.40; Crit 1.25-1.35", "Hammer: a late heavy beat.")
}

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
  $wb = $xl.Workbooks.Open($Path)
  $ws = $wb.Worksheets.Item("Abilities")
  $rows = $ws.UsedRange.Rows.Count
  $skipColumns = [string]$ws.Cells.Item(1, 21).Text -ne ""
  if ($skipColumns) {
    $done = 0
    for ($r = 2; $r -le $rows; $r++) {
      $id = [string]$ws.Cells.Item($r, 1).Text
      if ($Only -contains $id -and $design.Contains($id)) {
        $d = $design[$id]
        $ws.Cells.Item($r, 21).Value2 = $d[0]
        if ($d[1] -gt 0) { $ws.Cells.Item($r, 22).Value2 = [double]$d[1] } else { $ws.Cells.Item($r, 22).Value2 = "none" }
        $ws.Cells.Item($r, 23).Value2 = ([string]$d[2]).Replace("-", $dash)
        $ws.Cells.Item($r, 24).Value2 = $d[3]
        $done++
      }
    }
    "Columns already there; rows rewritten: $done"
  } else {

  # Formats of the Notes column (T) for the four new columns.
  [void]$ws.Range("T1:T$rows").Copy()
  [void]$ws.Range("U1:X$rows").PasteSpecial(-4122)
  $headers = @("Timing Status", "Timing Bar (s)", "Timing Zones", "Timing Notes")
  for ($i = 0; $i -lt 4; $i++) { $ws.Cells.Item(1, 21 + $i).Value2 = $headers[$i] }

  $done = 0
  for ($r = 2; $r -le $rows; $r++) {
    $id = [string]$ws.Cells.Item($r, 1).Text
    if ($id -eq "") { continue }
    if ($design.Contains($id)) {
      $d = $design[$id]
      $ws.Cells.Item($r, 21).Value2 = $d[0]
      if ($d[1] -gt 0) { $ws.Cells.Item($r, 22).Value2 = [double]$d[1] } else { $ws.Cells.Item($r, 22).Value2 = "none" }
      $ws.Cells.Item($r, 23).Value2 = ([string]$d[2]).Replace("-", $dash)
      $ws.Cells.Item($r, 24).Value2 = $d[3]
      $done++
    } else {
      $ws.Cells.Item($r, 21).Value2 = "Not implemented"
    }
  }
  $ws.Columns.Item(21).ColumnWidth = 30
  $ws.Columns.Item(22).ColumnWidth = 14
  $ws.Columns.Item(23).ColumnWidth = 30
  $ws.Columns.Item(24).ColumnWidth = 60
  $ws.Range("U2:X$rows").WrapText = $true
  "Designs written: $done"
  }

  # ---- Timing Rules tab (rebuilt each run) ----------------------------------
  foreach ($old in @($wb.Worksheets)) { if ($old.Name -eq "Timing Rules") { $old.Delete() } }
  $after = $wb.Worksheets.Item("Rules & Legend")
  $tr = $wb.Worksheets.Add([Type]::Missing, $after)
  $tr.Name = "Timing Rules"
  $section = $after.Range("A1")       # style of a section title
  $head = $ws.Range("A1")             # style of a table header
  $body = $after.Range("B2")          # style of body text
  $row = 1
  $lineRows = @{}                     # row -> characters of its merged text (sized at the end)

  function Style($src) {
    [void]$src.Copy(); [void]$script:tr.Range("A$($script:row):E$($script:row)").PasteSpecial(-4122)
    $script:tr.Range("A$($script:row):E$($script:row)").NumberFormat = "@"   # text stays text
  }
  function Section([string]$title) {
    Style $script:section
    $script:tr.Cells.Item($script:row, 1).Value2 = $title
    [void]$script:tr.Range("A$($script:row):E$($script:row)").Merge()
    $script:row++
  }
  function Line([string]$label, [string]$text) {
    Style $script:body
    $script:tr.Cells.Item($script:row, 1).Value2 = $label
    $script:tr.Cells.Item($script:row, 2).Value2 = $text.Replace("~", $script:dash)
    [void]$script:tr.Range("B$($script:row):E$($script:row)").Merge()
    $script:lineRows[$script:row] = $text.Length
    $script:row++
  }
  function Table([string[]]$cells, [bool]$isHeader) {
    if ($isHeader) { Style $script:head } else { Style $script:body }
    for ($i = 0; $i -lt $cells.Count; $i++) { $script:tr.Cells.Item($script:row, $i + 1).Value2 = $cells[$i].Replace("~", $script:dash) }
    $script:row++
  }
  function Gap() { $script:row++ }

  Section "Timing bars: how they work"
  Line "What it is" "When a hero uses an ability with a timing bar, it doesn't go off at once: the bar runs for Timing Bar (s) and the player right-clicks on its zones. Good timing gives full power or a critical; bad timing still casts, weaker. Nothing is worse than a reduced hit."
  Line "Which abilities" "Important abilities get long bars, quick ones short bars. Instants never have a bar: dashes, interrupts, potions, and for now buffs, taunts and terrain (timing has nothing to scale on them yet)."
  Line "Starting a bar" "The global cooldown starts with the bar. Mana and the ability's cooldown are paid when it goes off. The bar replaces any cast time or wind-up the ability had (Aimed Shot's draw, Smash's wind-up)."
  Line "Cancelling" "Moving, a stun, an interrupt, or a Targeted target leaving range or line of sight cancels the bar; the cooldown is not spent."
  Line "Inputs in order" "A bar may ask for several inputs (taps and holds), played in order, one press each (Aimed Shot: a tap, then a hold). A press goes to the next input whose window isn't over; an input skipped or never played counts as a miss. The ability goes off when the last input is played (a tap at once, a hold when let go), or when the bar ends."
  Line "Aimed abilities" "Skillshots and ground abilities with a bar start their bar as soon as the key is pressed; the affected tiles follow the cursor during the bar, and the ability fires where the cursor points at the last input (a ground target beyond range is pulled back to the edge of the range). Aimed abilities without a bar (Flame Dash, Raise Pillar, Earth Wall) still aim first: hold the key, release to cast."
  Line "Who plays them" "Heroes only. Enemies cast the same abilities straight away, without a bar."
  Gap

  Section "Zones"
  Table @("Zone", "Colour", "Input", "Result", "Notes") $true
  Table @("Tap", "Green", "Right-click inside it", "Success: full power", "")
  Table @("Crit", "Yellow", "Right-click inside it", "Critical success: full power, every hit is a critical", "Sits inside a Tap zone.")
  Table @("Hold", "Blue", "Press right-click as it starts, let go as it ends", "Judged by accuracy (Holds, below)", "Ends 0.2~0.3 s before the bar.")
  Table @("Outside", "Dark", "A tap outside every zone, or no press at all", "Miss: 70% power", "")
  Gap

  Section "Outcomes: miss, success, critical success"
  Table @("Outcome", "Tap", "Hold", "Power", "Critical hit") $true
  Table @("Miss", "Outside the zones, or no press", "Accuracy 50% or less", "70%", "Normal chance (Crit Rate)")
  Table @("Success", "Inside a green zone", "Accuracy between 50% and 95%", "Tap: 100%. Hold: rises steadily from 70% (at 50%) to 100% (at 95%)", "Normal chance (Crit Rate)")
  Table @("Critical success", "Inside a yellow zone", "Accuracy 95% or more", "100%", "Guaranteed on every hit")
  Line "Several inputs" "The bar's power is the average of its inputs' powers (a tap 70% or 100%, a hold 70% to 100% by accuracy). Critical success only if every input is perfect (a yellow tap, a 95%+ hold); a miss only if every input is a miss; otherwise a success. The accuracy shown is the inputs' average (a tap counts 100% when hit, 0% when missed)."
  Line "What power scales" "Damage (direct hits, damage over time, burning ground), healing, heals over time and shields. Buff sizes and durations are not scaled."
  Line "Critical hit" "A critical multiplies the amount by 1 + (50 + Crit Damage) / 100, i.e. x1.5 with no Crit Damage."
  Line "Shown on screen" "Above the bar for 0.8 s: Miss, Good or Perfect!; a bar with a hold or several inputs adds its accuracy, e.g. Good 88%."
  Gap

  Section "Holds"
  Line "Accuracy" "Accuracy = 1 - (how early or late you pressed + how early or late you let go) / the zone's length. Letting go after the zone ends counts as late."
  Line "Power" "Power = 70% + 30% x (accuracy - 50%) / 45%, kept between 70% and 100%."
  Line "Starting early" "A press up to 0.2 s before the blue zone starts the hold (that early part counts against accuracy). Earlier, it is a tap outside the zones: a miss."
  Line "The end rule" "A hold zone always ends 0.2~0.3 s before its bar ends, so letting go on time is part of the skill. The import refuses a hold that breaks this."
  Line "Never let go" "If the button is still held when the bar ends, the hold is judged as let go at the bar's end."
  Line "On screen" "Hold! is shown while holding and the held part turns light blue. Past the zone the label turns red (Let go!) and the extra time is drawn red; so is a press before the zone."
  Gap

  Section "Margins of error and network"
  Line "Zone edges" "A press exactly on a zone's edge counts as inside it."
  Line "Your screen decides" "The game measures your press against the bar as you saw it and sends that time; the host judges it. It accepts a time at most 0.3 s ahead of its own clock."
  Line "No press" "With no press the host waits 0.25 s after the bar ends (a press may still be on its way), then casts at miss power."
  Line "Game speed" "Bars follow the game speed slider (Escape menu > Gameplay test): at x0.5 a 1 s bar takes 2 real seconds."
  Gap

  Section "Display options (Escape menu > Gameplay test)"
  Line "Where" "Under your hero (220 x 15 px) or above the action bar (440 x 30 px). The ability's name is written above the bar, so a wrong key shows at once."
  Line "Mode 1" "Bar length follows the ability: the full length stands for 3 s, a cursor sweeps across at a steady speed, and a 1 s bar is a third of the full length, centred."
  Line "Mode 2" "Zones slide to a fixed hit line: the bar keeps its full length (a 3 s window), a white hit line sits 0.4 s from the left, and the zones slide toward it at the same steady speed. Thin marks show where the ability's bar starts and ends."
  Gap

  Section "Writing the timing columns (Abilities tab)"
  Line "Timing Status" "Manual (the designer's own), Generated (AI, not yet confirmed) (an AI draft to review), or Not implemented. Manual and Generated designs are both in the game."
  Line "Timing Bar (s)" "The bar's length in seconds, or 'none' for an ability that has no bar (an instant)."
  Line "Timing Zones" "Zones separated by ';', each 'Tap a~b', 'Crit a~b' or 'Hold a~b', in seconds from the bar's start (for example 'Tap 0.35~0.65; Crit 0.45~0.55' or 'Hold 0.75~2.75', or a tap then a hold: 'Tap 0.20~0.60; Crit 0.35~0.45; Hold 1.00~3.75'). Dots or commas for decimals; '-' or '~' between the numbers."
  Line "Timing Notes" "Free text: the idea behind the design."
  Line "After editing" "Re-import the sheet (docs/ability-import.md). The import checks that every zone is inside its bar, that holds end 0.2~0.3 s before the bar, that crits sit inside a tap, that inputs don't overlap, and that the numbers read; it refuses the file otherwise."
  Gap

  Section "Tunable values (ask to change them)"
  Table @("Value", "Now", "Where in the game", "", "What it does") $true
  Table @("Miss power", "0.7", "CombatRules: timing_miss_power", "", "Power of a miss (tap outside, poor hold, no press).")
  Table @("Hold: critical from", "95%", "TimingBarDef: HOLD_PERFECT", "", "Hold accuracy for a critical success.")
  Table @("Hold: miss at or under", "50%", "TimingBarDef: HOLD_MISS", "", "Hold accuracy for a miss.")
  Table @("Hold: early start", "0.2 s", "TimingBarDef: HOLD_START_TOLERANCE", "", "How early a press may start a hold.")
  Table @("Hold: end gap", "0.2~0.3 s", "TimingBarDef: HOLD_END_GAP, HOLD_END_GAP_MAX", "", "How long before the bar's end a hold zone ends (checked on import).")
  Table @("No-press wait", "0.25 s", "CombatRules: timing_press_grace_seconds", "", "Wait after the bar for a press on its way.")
  Table @("Clock slack", "0.3 s", "WorldSim: TIMING_CLOCK_SLACK", "", "How far ahead of the host a client's press may be.")
  Table @("Zone edge", "0.0001 s", "TimingBarDef: EPSILON", "", "Rounding margin on zone edges.")
  Table @("Critical bonus", "+50%", "CombatRules: base_crit_damage_percent", "", "Base critical multiplier (plus Crit Damage).")
  Table @("Full bar length", "3 s", "TimingBarView: FULL_SECONDS", "", "Seconds the full bar stands for (on-screen speed).")
  Table @("Bar size", "440 x 30 px", "TimingBarView: BAR", "", "Above the action bar; half that under the hero.")
  Table @("Hit line", "0.4 s", "TimingBarView: HIT_LEAD_SECONDS", "", "Mode 2: where the hit line sits.")
  Table @("Result shown", "0.8 s", "TimingBarView: RESULT_SECONDS", "", "How long 'Perfect!' / 'Good' / 'Miss' stays.")

  $tr.Columns.Item(1).ColumnWidth = 22
  $tr.Columns.Item(2).ColumnWidth = 30
  $tr.Columns.Item(3).ColumnWidth = 34
  $tr.Columns.Item(4).ColumnWidth = 30
  $tr.Columns.Item(5).ColumnWidth = 50
  $tr.Range("A1:E$row").WrapText = $true
  $tr.Range("A1:E$row").VerticalAlignment = -4160   # top
  [void]$tr.Range("A1:E$row").Rows.AutoFit()
  # Merged cells don't auto-fit: size each long line from its length (about 130
  # characters per line across the merged columns).
  foreach ($r in $lineRows.Keys) { $tr.Rows.Item($r).RowHeight = 13.5 * [math]::Max(1, [math]::Ceiling($lineRows[$r] / 130.0)) }
  $ws.Activate()
  $wb.Save()
  "Saved."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
