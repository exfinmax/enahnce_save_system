# Enhanced Save System

## 概述
Enhanced Save System 是一个功能全面的 Godot 存档系统插件，提供了模块化的存档解决方案，支持输入重映射、自动存档、存档预览图和加密功能。

## 功能特性

### 核心功能
- **纯 JSON 存储**：快速、人可读、无引用解析开销
- **模块化多态**：每个 ISaveModule 子类负责自己数据域
- **双轨道存档**：
  - 全局存档（global.json）：设置、统计等不依赖槽位的数据
  - 槽位存档（slot_01.json … slot_N.json）：关卡进度、玩家状态等
- **Writer 积累模式**：先收集所有模块变更 → 一次性写盘（减少 I/O）
- **自动存档**：可配置的自动存档间隔和槽位
- **存档预览图**：保存游戏状态时自动截图
- **存档加密**：可选的存档文件加密功能
- **导入/导出**：支持存档文件的迁移
- **输入重映射**：内置的输入键位自定义系统

### 模块系统
- **player_module**：玩家状态管理
- **level_module**：关卡进度管理
- **settings_module**：游戏设置管理
- **stats_module**：游戏统计数据管理
- **keybinding_module**：输入键位管理

## 安装方法

1. 将 `addons/enhance_save_system` 目录复制到你的 Godot 项目的 `addons` 目录中
2. 在 Godot 编辑器中，进入 `项目 > 项目设置 > 插件`，启用 "Enhanced Save System"
3. 插件会自动将 `SaveSystem` 注册为 AutoLoad 单例

## 快速上手

### 基本用法
```gdscript
# 保存全局 + 当前槽位
SaveSystem.quick_save()

# 加载全局 + 当前槽位
SaveSystem.quick_load()

# 保存到指定槽位
SaveSystem.save_slot(2)

# 从指定槽位加载
SaveSystem.load_slot(2)

# 导出槽位存档
SaveSystem.export_slot(1, "user://backup/slot1.json")

# 导入槽位存档
SaveSystem.import_slot(1, "user://backup/slot1.json")
```

### 注册自定义模块
```gdscript
# 在场景的 _ready 函数中注册自定义模块
func _ready():
    SaveSystem.register_module(MyCustomModule.new())
```

### 配置选项
在 Godot 编辑器中，选择 AutoLoad 中的 SaveSystem 节点，可以在 Inspector 中配置以下选项：

- **max_slots**：最大槽位数（1-based）
- **auto_register**：是否自动扫描并注册 Modules/ 目录中的模块
- **auto_load_global**：启动时是否自动加载全局存档
- **auto_load_slot**：启动时自动加载的槽位（0 = 不自动加载）
- **game_version**：写入存档元数据的游戏版本
- **auto_save_enabled**：是否启用自动存档
- **auto_save_interval**：自动存档间隔（秒）
- **auto_save_slot**：自动存档槽位
- **save_screenshots_enabled**：是否启用存档预览图
- **screenshot_width**：预览图宽度
- **screenshot_height**：预览图高度
- **encryption_enabled**：是否启用存档加密
- **encryption_key**：加密密钥

## 信号列表

- **global_saved(ok)**：全局存档写盘完成
- **global_loaded(ok)**：全局存档读取完成
- **slot_saved(slot, ok)**：指定槽位写盘完成
- **slot_loaded(slot, ok)**：指定槽位读取完成
- **slot_deleted(slot)**：槽位文件已删除
- **slot_changed(slot)**：当前活跃槽位切换

## 目录结构

```
enhance_save_system/
├── Components/         # UI 组件
│   └── InputRemapping/  # 输入重映射相关组件
├── Modules/            # 存档模块
│   ├── keybinding_module.gd
│   ├── level_module.gd
│   ├── player_module.gd
│   ├── settings_module.gd
│   └── stats_module.gd
├── core/               # 核心功能
│   ├── i_save_module.gd
│   ├── resource_serializer.gd
│   ├── save_resource.gd
│   ├── save_system.gd
│   ├── save_writer.gd
│   └── slot_info.gd
├── demo/               # 示例场景
├── templates/          # 模板文件
├── plugin.cfg
└── save_plugin.gd
```

## 自定义模块

### 创建全局模块
1. 复制 `templates/custom_global_module.gd` 到你的项目中
2. 修改类名和模块键
3. 实现 `collect_data` 和 `apply_data` 方法
4. 调用 `SaveSystem.register_module()` 注册模块

### 创建槽位模块
1. 复制 `templates/custom_slot_module.gd` 到你的项目中
2. 修改类名和模块键
3. 实现 `collect_data` 和 `apply_data` 方法
4. 调用 `SaveSystem.register_module()` 注册模块

## 输入重映射

### 使用方法
1. 在场景中添加 `keybinding_ui.tscn` 组件
2. 或者使用代码创建：

```gdscript
var keybinding_ui = preload("res://addons/enhance_save_system/Components/InputRemapping/keybinding_ui.tscn").instantiate()
add_child(keybinding_ui)
```

## 示例场景

插件包含以下示例场景：

- **SaveDemo.tscn**：基础存档功能演示
- **enhanced_save_demo.tscn**：增强功能演示
- **encryption_test.tscn**：加密功能测试
- **import_export_demo.tscn**：导入/导出功能演示

## 性能优化

- **减少 I/O 操作**：使用 Writer 积累模式，一次性写盘
- **异步操作**：存档操作在主线程中执行，但设计上尽量减少阻塞
- **模块化设计**：每个模块只处理自己的数据，提高可维护性

## 兼容性

- 支持 Godot 4.0 及以上版本
- 纯 GDScript 实现，无外部依赖

## 许可证

MIT License

# Enhanced Save System

## Overview
Enhanced Save System is a comprehensive save system plugin for Godot, providing a modular save solution with input remapping, auto-save, save screenshots, and encryption features.

## Features

### Core Features
- **Pure JSON Storage**：Fast, human-readable, no reference resolution overhead
- **Modular Polymorphism**：Each ISaveModule subclass manages its own data domain
- **Dual-track Save**：
  - Global save (global.json)：Settings, statistics, and other slot-independent data
  - Slot save (slot_01.json … slot_N.json)：Level progress, player state, etc.
- **Writer Accumulation Mode**：Collect all module changes first → write to disk once (reduce I/O)
- **Auto-save**：Configurable auto-save interval and slot
- **Save Screenshots**：Automatically capture screenshots when saving game state
- **Save Encryption**：Optional save file encryption
- **Import/Export**：Support for save file migration
- **Input Remapping**：Built-in input key customization system

### Module System
- **player_module**：Player state management
- **level_module**：Level progress management
- **settings_module**：Game settings management
- **stats_module**：Game statistics management
- **keybinding_module**：Input key management

## Installation

1. Copy the `addons/enhance_save_system` directory to your Godot project's `addons` directory
2. In Godot editor, go to `Project > Project Settings > Plugins` and enable "Enhanced Save System"
3. The plugin will automatically register `SaveSystem` as an AutoLoad singleton

## Quick Start

### Basic Usage
```gdscript
# Save global + current slot
SaveSystem.quick_save()

# Load global + current slot
SaveSystem.quick_load()

# Save to specific slot
SaveSystem.save_slot(2)

# Load from specific slot
SaveSystem.load_slot(2)

# Export slot save
SaveSystem.export_slot(1, "user://backup/slot1.json")

# Import slot save
SaveSystem.import_slot(1, "user://backup/slot1.json")
```

### Register Custom Modules
```gdscript
# Register custom module in scene's _ready function
func _ready():
    SaveSystem.register_module(MyCustomModule.new())
```

### Configuration Options
In Godot editor, select the SaveSystem node in AutoLoad, you can configure the following options in Inspector:

- **max_slots**：Maximum number of slots (1-based)
- **auto_register**：Whether to automatically scan and register modules in Modules/ directory
- **auto_load_global**：Whether to automatically load global save on startup
- **auto_load_slot**：Slot to automatically load on startup (0 = no auto load)
- **game_version**：Game version written to save metadata
- **auto_save_enabled**：Whether to enable auto-save
- **auto_save_interval**：Auto-save interval (seconds)
- **auto_save_slot**：Auto-save slot
- **save_screenshots_enabled**：Whether to enable save screenshots
- **screenshot_width**：Screenshot width
- **screenshot_height**：Screenshot height
- **encryption_enabled**：Whether to enable save encryption
- **encryption_key**：Encryption key

## Signal List

- **global_saved(ok)**：Global save write completion
- **global_loaded(ok)**：Global save read completion
- **slot_saved(slot, ok)**：Specific slot write completion
- **slot_loaded(slot, ok)**：Specific slot read completion
- **slot_deleted(slot)**：Slot file deleted
- **slot_changed(slot)**：Current active slot changed

## Directory Structure

```
enhance_save_system/
├── Components/         # UI components
│   └── InputRemapping/  # Input remapping components
├── Modules/            # Save modules
│   ├── keybinding_module.gd
│   ├── level_module.gd
│   ├── player_module.gd
│   ├── settings_module.gd
│   └── stats_module.gd
├── core/               # Core functionality
│   ├── i_save_module.gd
│   ├── resource_serializer.gd
│   ├── save_resource.gd
│   ├── save_system.gd
│   ├── save_writer.gd
│   └── slot_info.gd
├── demo/               # Example scenes
├── templates/          # Template files
├── plugin.cfg
└── save_plugin.gd
```

## Custom Modules

### Create Global Module
1. Copy `templates/custom_global_module.gd` to your project
2. Modify class name and module key
3. Implement `collect_data` and `apply_data` methods
4. Call `SaveSystem.register_module()` to register the module

### Create Slot Module
1. Copy `templates/custom_slot_module.gd` to your project
2. Modify class name and module key
3. Implement `collect_data` and `apply_data` methods
4. Call `SaveSystem.register_module()` to register the module

## Input Remapping

### Usage
1. Add `keybinding_ui.tscn` component to your scene
2. Or create it with code:

```gdscript
var keybinding_ui = preload("res://addons/enhance_save_system/Components/InputRemapping/keybinding_ui.tscn").instantiate()
add_child(keybinding_ui)
```

## Example Scenes

The plugin includes the following example scenes:

- **SaveDemo.tscn**：Basic save functionality demo
- **enhanced_save_demo.tscn**：Enhanced features demo
- **encryption_test.tscn**：Encryption functionality test
- **import_export_demo.tscn**：Import/export functionality demo

## Performance Optimization

- **Reduce I/O Operations**：Use Writer accumulation mode, write to disk once
- **Asynchronous Operations**：Save operations are executed in the main thread, but designed to minimize blocking
- **Modular Design**：Each module only handles its own data, improving maintainability

## Compatibility

- Supports Godot 4.0 and above
- Pure GDScript implementation, no external dependencies

## License

MIT License