class_name XlsxReader
extends RefCounted
## Minimal .xlsx reader: every sheet's cells as text (formulas give their saved
## values). Enough for design spreadsheets; no styles, dates or formula evaluation.


## {"sheets": {name: [[cell text, ...], ...]}, "order": [names], "error": ""}.
## Rows are dense (missing cells are ""); trailing empty rows are dropped.
static func read(path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return {"error": "Can't open %s (is it an .xlsx file?)" % path}
	var files := zip.get_files()
	if not files.has("xl/workbook.xml"):
		zip.close()
		return {"error": "%s isn't an .xlsx workbook" % path}
	var shared := _shared_strings(zip, files)
	var rels := _relationships(zip.read_file("xl/_rels/workbook.xml.rels"))
	var out := {"sheets": {}, "order": [], "error": ""}
	for sheet in _sheet_list(zip.read_file("xl/workbook.xml")):
		var target: String = rels.get(sheet.rid, "")
		if target.begins_with("/"):
			target = target.substr(1)
		elif not target.begins_with("xl/"):
			target = "xl/" + target
		if not files.has(target):
			continue
		out.sheets[sheet.name] = _rows(zip.read_file(target), shared)
		out.order.append(sheet.name)
	zip.close()
	return out


static func _shared_strings(zip: ZIPReader, files: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	if not files.has("xl/sharedStrings.xml"):
		return out
	var p := XMLParser.new()
	p.open_buffer(zip.read_file("xl/sharedStrings.xml"))
	var current := ""
	var in_si := false
	var in_t := false
	var skip_depth := 0 # inside <rPh> (phonetic hints): ignore its text
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var n := p.get_node_name()
				if n == "si":
					in_si = true
					current = ""
					if p.is_empty():
						out.append("")
						in_si = false
				elif n == "rPh" and not p.is_empty():
					skip_depth += 1
				elif n == "t" and not p.is_empty():
					in_t = true
			XMLParser.NODE_ELEMENT_END:
				var n := p.get_node_name()
				if n == "si" and in_si:
					out.append(current)
					in_si = false
				elif n == "rPh":
					skip_depth -= 1
				elif n == "t":
					in_t = false
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_si and in_t and skip_depth == 0:
					current += p.get_node_data()
	return out


static func _relationships(xml: PackedByteArray) -> Dictionary:
	var out := {}
	var p := XMLParser.new()
	if p.open_buffer(xml) != OK:
		return out
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Relationship":
			out[p.get_named_attribute_value_safe("Id")] = p.get_named_attribute_value_safe("Target")
	return out


static func _sheet_list(xml: PackedByteArray) -> Array:
	var out := []
	var p := XMLParser.new()
	p.open_buffer(xml)
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "sheet":
			out.append({"name": p.get_named_attribute_value_safe("name"),
					"rid": p.get_named_attribute_value_safe("r:id")})
	return out


static func _rows(xml: PackedByteArray, shared: PackedStringArray) -> Array:
	var rows := {} # row index -> {col index: text}
	var max_row := -1
	var p := XMLParser.new()
	p.open_buffer(xml)
	var row := -1
	var col := -1
	var kind := ""
	var value := ""
	var in_value := false
	var in_cell := false
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var n := p.get_node_name()
				if n == "row":
					row = p.get_named_attribute_value_safe("r").to_int() - 1
				elif n == "c":
					var ref := p.get_named_attribute_value_safe("r")
					col = _column_index(ref) if ref != "" else col + 1
					var r_from_ref := _row_index(ref)
					if r_from_ref >= 0:
						row = r_from_ref
					kind = p.get_named_attribute_value_safe("t")
					value = ""
					in_cell = not p.is_empty()
				elif (n == "v" or n == "t") and in_cell and not p.is_empty():
					in_value = true
			XMLParser.NODE_ELEMENT_END:
				var n := p.get_node_name()
				if n == "v" or n == "t":
					in_value = false
				elif n == "c" and in_cell:
					in_cell = false
					var text := value
					if kind == "s":
						var i := value.to_int()
						text = shared[i] if i >= 0 and i < shared.size() else ""
					elif kind == "b":
						text = "TRUE" if value == "1" else "FALSE"
					if text != "":
						if not rows.has(row):
							rows[row] = {}
						rows[row][col] = text
						max_row = maxi(max_row, row)
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_value:
					value += p.get_node_data()
	var out := []
	for r in range(max_row + 1):
		var cells: Dictionary = rows.get(r, {})
		var width := 0
		for c in cells:
			width = maxi(width, c + 1)
		var line: Array = []
		line.resize(width)
		line.fill("")
		for c in cells:
			line[c] = cells[c]
		out.append(line)
	return out


## "AB12" -> 27 (0-based column).
static func _column_index(ref: String) -> int:
	var n := 0
	for ch in ref:
		var code := ch.unicode_at(0)
		if code >= 65 and code <= 90:
			n = n * 26 + (code - 64)
		else:
			break
	return n - 1


static func _row_index(ref: String) -> int:
	var digits := ""
	for ch in ref:
		if ch >= "0" and ch <= "9":
			digits += ch
	return digits.to_int() - 1 if digits != "" else -1
