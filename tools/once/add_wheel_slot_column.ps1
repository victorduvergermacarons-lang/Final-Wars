# One-off (2026-11-22), kept for the record: adds the "Wheel Slot" column to
# design/Ability_Tree.xlsx (after the last column, formatted like it), filled for the
# implemented element abilities (user request: weapon on X, ranged attacks on Y, dash
# for Fire and Air and Earth's resistance buff on A), and a note at the end of the
# Timing Rules tab, through Excel so the workbook's formatting and formulas stay.
# Run from the project folder:
#   powershell -File tools/once/add_wheel_slot_column.ps1 -Path (Resolve-Path design/Ability_Tree.xlsx).Path
param([string]$Path)

$slots = @{
  "F03" = "Y"; "F06" = "Y"; "W02" = "Y"; "W04" = "Y"; "W06" = "Y"; "W07" = "Y"; "E01" = "Y"; "A02" = "Y"; "A05" = "Y";
  "F05" = "A"; "A03" = "A"; "E02" = "A"
}

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
    if ($h -eq "Wheel Slot") { throw "The column is already there; nothing changed." }
    if ($h -eq "ID") { $idCol = $c }
  }
  if ($idCol -eq 0) { throw "No ID column on the Abilities tab." }
  $col = $last + 1
  [void]$ws.Range($ws.Cells.Item(1, $last), $ws.Cells.Item($rows, $last)).Copy()
  [void]$ws.Range($ws.Cells.Item(1, $col), $ws.Cells.Item($rows, $col)).PasteSpecial(-4122)
  $ws.Cells.Item(1, $col).Value2 = "Wheel Slot"
  $ws.Columns.Item($col).ColumnWidth = 12
  [void]$ws.Range($ws.Cells.Item(2, $col), $ws.Cells.Item($rows, $col)).ClearContents()
  $marked = 0
  for ($r = 2; $r -le $rows; $r++) {
    $id = [string]$ws.Cells.Item($r, $idCol).Text
    if ($slots.ContainsKey($id)) {
      $ws.Cells.Item($r, $col).Value2 = $slots[$id]
      $marked++
    }
  }

  $tr = $wb.Worksheets.Item("Timing Rules")
  $end = $tr.UsedRange.Rows.Count
  $titleRow = 0
  for ($r = $end; $r -ge 1; $r--) { if ([string]$tr.Cells.Item($r, 1).Text -like "Hitbox Rules*") { $titleRow = $r; break } }
  if ($titleRow -eq 0) { throw "No Hitbox Rules note on the Timing Rules tab to copy the style from." }
  $lines = @(
    "Wheel Slot (where a new ability goes on the ability wheel)",
    "X = attack (left click): the equipped weapon's ability goes there by itself (Sword, Bow, Hammer trees), so element abilities leave it empty. Y = ranged attacks (right click). A = dash, or a defensive buff for Earth (Q). B = everything else (Shift); empty also means B.",
    "Only the first placement: the player can drag abilities anywhere afterwards. A slot already holding an ability of its own kind keeps it; the newcomer goes to B, then any free slot."
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
  "Column $col added ($marked abilities given a slot); Timing Rules note at rows $($end + 2)-$($row - 1)."
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
