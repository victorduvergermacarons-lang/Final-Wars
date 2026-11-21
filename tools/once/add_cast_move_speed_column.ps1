# One-off (2026-11-21), kept for the record: adds the "Cast Move Speed (%)" column to
# design/Ability_Tree.xlsx (after the last column, formatted like it, left empty: an
# empty cell means the default) and a note at the end of the Timing Rules tab, through
# Excel so the workbook's formatting and formulas stay. Run from the project folder:
#   powershell -File tools/once/add_cast_move_speed_column.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path
param([string]$Path)

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
  $wb = $xl.Workbooks.Open($Path)
  $ws = $wb.Worksheets.Item("Abilities")
  $rows = $ws.UsedRange.Rows.Count
  $last = $ws.UsedRange.Columns.Count
  $found = $false
  for ($c = 1; $c -le $last; $c++) { if ([string]$ws.Cells.Item(1, $c).Text -eq "Cast Move Speed (%)") { $found = $true } }
  if ($found) { throw "The column is already there; nothing changed." }
  $col = $last + 1
  [void]$ws.Range($ws.Cells.Item(1, $last), $ws.Cells.Item($rows, $last)).Copy()
  [void]$ws.Range($ws.Cells.Item(1, $col), $ws.Cells.Item($rows, $col)).PasteSpecial(-4122)
  $ws.Cells.Item(1, $col).Value2 = "Cast Move Speed (%)"
  $ws.Columns.Item($col).ColumnWidth = 18
  [void]$ws.Range($ws.Cells.Item(2, $col), $ws.Cells.Item($rows, $col)).ClearContents()

  $tr = $wb.Worksheets.Item("Timing Rules")
  $end = $tr.UsedRange.Rows.Count
  # A title row and text rows, styled like the Hitbox Rules note above them.
  $titleRow = 0
  for ($r = $end; $r -ge 1; $r--) { if ([string]$tr.Cells.Item($r, 1).Text -like "Hitbox Rules*") { $titleRow = $r; break } }
  if ($titleRow -eq 0) { throw "No Hitbox Rules note on the Timing Rules tab to copy the style from." }
  $lines = @(
    "Moving while casting",
    "Walking during a cast bar, wind-up, channel or timing bar doesn't cancel it: the hero walks at the ability's Cast Move Speed (%) of their current speed (Speed stat, haste and slows still count).",
    "Cast Move Speed (%) column (Abilities tab): 0 to 100; empty = the default, 30% (CombatRules: cast_move_speed_default).",
    "Still cancelled by: a stun, an interrupt, a knockback or pull, a fall, the target leaving range or sight, or another ability's key. Enemies stay planted while they attack."
  )
  $row = $end + 2
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $src = if ($i -eq 0) { $titleRow } else { $titleRow + 1 }
    [void]$tr.Rows.Item($src).Copy()
    [void]$tr.Rows.Item($row).PasteSpecial(-4122)
    $tr.Cells.Item($row, 1).Value2 = $lines[$i]
    $row++
  }
  $ws.Activate()
  $wb.Save()
  "Column $col added; Timing Rules note at rows $($end + 2)-$($row - 1)."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
