# One-off (2026-11-22), kept for the record: adds the "Manual Aim" column to
# design/Ability_Tree.xlsx (after the last column, formatted like it) with Yes on a
# first draft of abilities (ground areas, the lobbed rock, Aimed Shot), and a note
# at the end of the Timing Rules tab, through Excel so the workbook's formatting and
# formulas stay. Run from the project folder:
#   powershell -File tools/once/add_manual_aim_column.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path
param([string]$Path)

$draft = @("F07", "F08", "W09", "E01", "E03", "E05", "B02")

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
  $wb = $xl.Workbooks.Open($Path)
  $ws = $wb.Worksheets.Item("Abilities")
  $rows = $ws.UsedRange.Rows.Count
  $last = $ws.UsedRange.Columns.Count
  $idCol = 0
  for ($c = 1; $c -le $last; $c++) {
    $h = [string]$ws.Cells.Item(1, $c).Text
    if ($h -eq "Manual Aim") { throw "The column is already there; nothing changed." }
    if ($h -eq "ID") { $idCol = $c }
  }
  if ($idCol -eq 0) { throw "No ID column on the Abilities tab." }
  $col = $last + 1
  [void]$ws.Range($ws.Cells.Item(1, $last), $ws.Cells.Item($rows, $last)).Copy()
  [void]$ws.Range($ws.Cells.Item(1, $col), $ws.Cells.Item($rows, $col)).PasteSpecial(-4122)
  $ws.Cells.Item(1, $col).Value2 = "Manual Aim"
  $ws.Columns.Item($col).ColumnWidth = 12
  [void]$ws.Range($ws.Cells.Item(2, $col), $ws.Cells.Item($rows, $col)).ClearContents()
  $marked = 0
  for ($r = 2; $r -le $rows; $r++) {
    if ($draft -contains [string]$ws.Cells.Item($r, $idCol).Text) {
      $ws.Cells.Item($r, $col).Value2 = "Yes"
      $marked++
    }
  }

  $tr = $wb.Worksheets.Item("Timing Rules")
  $end = $tr.UsedRange.Rows.Count
  $titleRow = 0
  for ($r = $end; $r -ge 1; $r--) { if ([string]$tr.Cells.Item($r, 1).Text -like "Hitbox Rules*") { $titleRow = $r; break } }
  if ($titleRow -eq 0) { throw "No Hitbox Rules note on the Timing Rules tab to copy the style from." }
  $lines = @(
    "Manual Aim (controller)",
    "Manual Aim column (Abilities tab): Yes = on a controller this ability is always aimed by hand with the right stick (hold its button, aim, let go), whatever the player's aim setting (Auto-lock or Twin-stick). Empty or No = it follows the setting.",
    "Keyboard and mouse always aim at the cursor. First draft (AI, to confirm): Fireball, Burning Ground, Ice Spikes, Rock Throw, Raise Pillar, Earth Wall, Aimed Shot."
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
  "Column $col added ($marked abilities marked Yes); Timing Rules note at rows $($end + 2)-$($row - 1)."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
