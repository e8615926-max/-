class_name DayReportPanel
extends BasePanel
## Итоги прошедшего дня: изменение ресурсов и события.

const KIND_COLORS := {"good": UITheme.GOOD, "bad": UITheme.BAD, "info": UITheme.TEXT, "story": UITheme.TEAL}


func _init(report: Dictionary) -> void:
	super("День %d завершён" % int(report["day"]), Vector2(820, 560))

	var delta: Dictionary = report["delta"]
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for res in ResourceDefs.IDS:
		var change := int(delta.get(res, 0))
		var chip := UI.card(UITheme.PANEL_DARK, 8)
		var box := UI.hbox(8)
		chip.add_child(box)
		box.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 3))
		var color := UITheme.TEXT_DIM
		if change > 0:
			color = UITheme.GOOD
		elif change < 0:
			color = UITheme.BAD
		var value := UI.label(UI.signed(change), 22, color)
		value.custom_minimum_size.x = 48
		box.add_child(value)
		row.add_child(chip)
	content.add_child(row)

	content.add_child(UI.section_title("События"))
	var parts := UI.scroll_list(6)
	content.add_child(parts[0])
	var list: VBoxContainer = parts[1]
	for line: Dictionary in report["lines"]:
		var color: Color = KIND_COLORS.get(line.get("kind", "info"), UITheme.TEXT)
		var entry := UI.hbox(10)
		var mark := ColorRect.new()
		mark.color = color
		mark.custom_minimum_size = Vector2(6, 6)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(mark)
		entry.add_child(UI.wrap_label(line["text"], 18, color))
		list.add_child(entry)

	var ok := UI.accent_button("Начать день %d" % (int(report["day"]) + 1), 0, 68)
	ok.pressed.connect(close)
	content.add_child(ok)
