extends ColorRect

func show_text(text: String):
	$Label.text = text
	show()

func hide():
	$Label.text = ""
	super.hide()
