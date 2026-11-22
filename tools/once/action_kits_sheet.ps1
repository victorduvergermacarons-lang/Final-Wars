# One-off (2026-11-22), kept for the record: the spreadsheet side of the Hades-style
# element kits (user brief). Through Excel so formatting and formulas stay.
#  - attacks that needed a target become cones in front of you or projectiles;
#  - Air Step becomes a long dash; Stone Skin stacks; Raise Pillar goes in front of you;
#  - short cooldowns for the Fire combo and Stone Skin's quick presses;
#  - three new abilities: Stone Fist (E21), Ice Slide (W24), Frost Ring (W25).
# Run from the project folder:
#   powershell -File tools/once/action_kits_sheet.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path
param([string]$Path)

$edits = @{
  "F01" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Cone"; "Hitbox Range" = 1.4; "Hitbox Angle" = 90; "Cooldown (s)" = 0.4;
             "Effect" = "Quick flaming jab in front of you (a short cone)." };
  "F02" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Cone"; "Hitbox Range" = 1.5; "Hitbox Angle" = 110; "Cooldown (s)" = 1.2;
             "Effect" = "Flaming kick in front of you (a wide short cone); applies a short burn." };
  "F09" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Cone"; "Hitbox Range" = 1.4; "Hitbox Angle" = 90;
             "Effect" = "Three-hit combo in front of you; the last hit knocks enemies back 1 tile." };
  "W02" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Projectile"; "Hitbox Range" = 5.5; "Projectile Speed" = 16; "Projectile Size" = 0.3;
             "Effect" = "A lash of water flying up to 5 tiles; hits the first enemy." };
  "W07" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Projectile"; "Hitbox Range" = 5.5; "Projectile Speed" = 14; "Projectile Size" = 0.3;
             "Effect" = "A draining wave flying up to 5 tiles: damages the first enemy and heals you for 50% of the damage dealt." };
  "A01" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Cone"; "Hitbox Range" = 1.4; "Hitbox Angle" = 90;
             "Effect" = "Light damage and knock enemies in front of you back 1 tile. Spends wind charges for more." };
  "A02" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Projectile"; "Hitbox Range" = 5.5; "Projectile Speed" = 18; "Projectile Size" = 0.3;
             "Effect" = "A gust flying up to 5 tiles: light damage and interrupts the first enemy's cast." };
  "A05" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Projectile"; "Hitbox Range" = 5.5; "Projectile Speed" = 16; "Projectile Size" = 0.35;
             "Effect" = "A blast flying up to 5 tiles that knocks the first enemy back 3 tiles; bonus damage if it hits a wall or ledge. Spends wind charges for more." };
  "B01" = @{ "Targeting" = "Skillshot"; "Hitbox Shape" = "Projectile"; "Hitbox Range" = 7.5; "Projectile Speed" = 18; "Projectile Size" = 0.2;
             "Effect" = "A quick arrow flying up to 7 tiles." };
  "A03" = @{ "Targeting" = "Ground"; "Hitbox Shape" = "Dash"; "Hitbox Range" = 5; "Hitbox Width" = 0.6; "Cooldown (s)" = 2.5;
             "Effect" = "Long dash up to 5 tiles. Each dash fills a wind charge (up to 3), spent by Air Palm and Air Blast." };
  "E02" = @{ "Cooldown (s)" = 0.3;
             "Effect" = "Stacks up to 3 times: each use adds a third of +20 Physical Defense, for 10s." };
  "E03" = @{ "Hitbox Range" = 1;
             "Effect" = "Raise a pillar on the tile in front of you for 15s: 1 level, up to 3 the longer you hold. A Stone Fist slides it 5 tiles." };
}

$new = @(
  @{ "copy" = "E01"; "ID" = "E21"; "Ability" = "Stone Fist"; "Taught By" = "Stone Fist Scroll"; "Prerequisites" = ""; "Scales With" = "Phys Atk";
     "Effect" = "Short-range punch in front of you. Punching your own pillar slides it 5 tiles, hitting what it meets.";
     "Targeting" = "Skillshot"; "Targeting Details" = "Cone in front, 1.4 tiles"; "Cooldown (s)" = 0.6;
     "Hitbox Shape" = "Cone"; "Hitbox Range" = 1.4; "Hitbox Angle" = 90; "Hitbox Width" = ""; "Hitbox Radius" = ""; "Projectile Speed" = ""; "Projectile Size" = "";
     "Pierce" = "No"; "Timing Status" = "Not implemented"; "Timing Bar (s)" = ""; "Timing Zones" = ""; "Timing Notes" = "" },
  @{ "copy" = "W01"; "ID" = "W24"; "Ability" = "Ice Slide"; "Taught By" = "Ice Slide Scroll"; "Prerequisites" = ""; "Scales With" = "";
     "Effect" = "Ice mode: slide on ice up to 4 tiles where you aim."; "Role" = "Mobility";
     "Targeting" = "Ground"; "Targeting Details" = "Dash up to 4 tiles"; "Cooldown (s)" = 4;
     "Hitbox Shape" = "Dash"; "Hitbox Range" = 4; "Hitbox Width" = 0.6; "Hitbox Angle" = ""; "Hitbox Radius" = ""; "Projectile Speed" = ""; "Projectile Size" = "";
     "Pierce" = "No"; "Timing Status" = "Not implemented"; "Timing Bar (s)" = ""; "Timing Zones" = ""; "Timing Notes" = "" },
  @{ "copy" = "W01"; "ID" = "W25"; "Ability" = "Frost Ring"; "Taught By" = "Frost Ring Scroll"; "Prerequisites" = ""; "Scales With" = "0.8 Magic Atk";
     "Effect" = "Ice mode: frost bursts around you, damaging and slowing enemies within 2 tiles for 2s."; "Role" = "Damage";
     "Targeting" = "Self"; "Targeting Details" = "Circle of 2 tiles around you"; "Cooldown (s)" = 6;
     "Hitbox Shape" = "Self Circle"; "Hitbox Radius" = 2; "Hitbox Range" = ""; "Hitbox Angle" = ""; "Hitbox Width" = ""; "Projectile Speed" = ""; "Projectile Size" = "";
     "Pierce" = "No"; "Timing Status" = "Not implemented"; "Timing Bar (s)" = ""; "Timing Zones" = ""; "Timing Notes" = "" }
)

function Set-Cell($ws, [int]$r, [int]$c, $v) {
  $cell = $ws.Range($ws.Cells.Item($r, $c), $ws.Cells.Item($r, $c))
  if ($v -is [string]) { $cell.Value2 = [string]$v } else { $cell.Value2 = [double]$v }
}

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
  $wb = $xl.Workbooks.Open($Path)
  $ws = $wb.Worksheets.Item("Abilities")
  $rows = $ws.UsedRange.Rows.Count
  $cols = $ws.UsedRange.Columns.Count
  $col = @{}
  for ($c = 1; $c -le $cols; $c++) { $col[[string]$ws.Cells.Item(1, $c).Text] = $c }
  $rowOf = @{}
  for ($r = 2; $r -le $rows; $r++) { $id = [string]$ws.Cells.Item($r, $col["ID"]).Text; if ($id -ne "") { $rowOf[$id] = $r } }
  foreach ($n in $new) { if ($rowOf.ContainsKey($n["ID"])) { throw "$($n["ID"]) is already in the sheet; nothing changed." } }

  foreach ($id in $edits.Keys) {
    $r = $rowOf[$id]
    foreach ($h in $edits[$id].Keys) {
      if (-not $col.ContainsKey($h)) { throw "No column $h" }
      Set-Cell $ws $r $col[$h] $edits[$id][$h]
    }
  }
  $next = $rows + 1
  foreach ($n in $new) {
    [void]$ws.Rows.Item($rowOf[$n["copy"]]).Copy()
    [void]$ws.Rows.Item($next).PasteSpecial(-4104)
    foreach ($h in $n.Keys) {
      if ($h -eq "copy") { continue }
      if (-not $col.ContainsKey($h)) { throw "No column $h" }
      Set-Cell $ws $next $col[$h] $n[$h]
    }
    $next++
  }
  $wb.Save()
  "Edited $($edits.Count) abilities; added $($new.Count) (rows $($rows + 1)-$($next - 1))."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
