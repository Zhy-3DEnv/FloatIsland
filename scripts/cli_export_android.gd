@tool
extends EditorScript

func _run() -> void:
	print("Use Godot CLI to export Android APK:")
	print('  godot --headless --path "D:/folat-island" --export-debug "Android" "D:/folat-island/build/FolatIsland.apk"')
