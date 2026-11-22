# One-off (2026-11-22), kept for the record: the spreadsheet side of the held
# abilities (user brief): Flame Dash goes 2 tiles on a tap and up to 6 held; Fire
# Punch and Fire Kick step forward. Through Excel so formatting and formulas stay.
# Run from the project folder:
#   powershell -File tools/once/held_abilities_sheet.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path
param([string]$Path)

$edits = @{
  "F05" = @{ "Hitbox Range" = 6; "Targeting Details" = "Dash where you walk: 2 tiles on a tap, up to 6 held";
             "Effect" = "Dash where you walk, leaving burning ground: 2 tiles on a tap, up to 6 the longer you hold." };
  "F01" = @{ "Effect" = "Quick flaming jab in front of you (a short cone); you step a little forward." };
  "F02" = @{ "Effect" = "Flaming kick in front of you (a wide short cone) with a longer step forward; applies a short burn." };
}

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
  foreach ($id in $edits.Keys) {
    $r = $rowOf[$id]
    foreach ($h in $edits[$id].Keys) {
      if (-not $col.ContainsKey($h)) { throw "No column $h" }
      Set-Cell $ws $r $col[$h] $edits[$id][$h]
    }
  }
  $wb.Save()
  "Edited $($edits.Count) abilities."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
