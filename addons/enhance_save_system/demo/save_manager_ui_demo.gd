extends Control
## SaveManagerUI Demo
## 演示 SaveManagerUI 组件的集成方式

@onready var _mode_btn: Button = $VBox/Controls/ModeBtn
@onready var _log: RichTextLabel = $VBox/Log
@onready var _ui_container: Control = $VBox/UIContainer

var _save_ui: SaveManagerUI
var _current_mode: SaveManagerUI.Mode = SaveManagerUI.Mode.LOAD

func _ready() -> void:
	_log.bbcode_enabled = true
	_append("[b]SaveManagerUI Demo[/b]\n")
	_spawn_ui()

func _spawn_ui() -> void:
	if is_instance_valid(_save_ui):
		_save_ui.queue_free()
	var scene := load("res://addons/enhance_save_system/Components/SaveManager/save_manager_ui.tscn")
	_save_ui = scene.instantiate() as SaveManagerUI
	_save_ui.mode = _current_mode
	_save_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_ui.slot_selected.connect(_on_slot_selected)
	_save_ui.slot_deleted.connect(_on_slot_deleted)
	_ui_container.add_child(_save_ui)
	_append("SaveManagerUI 已加载（模式：%s）\n" % ("保存" if _current_mode == SaveManagerUI.Mode.SAVE else "加载"))

func _on_toggle_mode_pressed() -> void:
	_current_mode = SaveManagerUI.Mode.SAVE if _current_mode == SaveManagerUI.Mode.LOAD else SaveManagerUI.Mode.LOAD
	_mode_btn.text = "切换到%s模式" % ("加载" if _current_mode == SaveManagerUI.Mode.SAVE else "保存")
	if is_instance_valid(_save_ui):
		_save_ui.mode = _current_mode
	_append("切换到%s模式\n" % ("保存" if _current_mode == SaveManagerUI.Mode.SAVE else "加载"))

func _on_slot_selected(slot: int) -> void:
	_append("[color=green]槽位 %d 被选中[/color]\n" % slot)

func _on_slot_deleted(slot: int) -> void:
	_append("[color=red]槽位 %d 已删除[/color]\n" % slot)

func _append(text: String) -> void:
	_log.append_text(text)
