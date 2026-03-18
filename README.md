# Enhanced Save System

Godot 4 模块化存档插件，支持 AES 加密、gzip 压缩、原子写入、版本迁移、运行时 UI 和编辑器面板。

---

## 新增功能（v2 扩展）

| 功能 | 说明 |
|------|------|
| AES-GCM / AES-CBC 加密 | 替代旧版 XOR，支持完整性验证 |
| 原子写入 + .bak 备份 | 防止写入中断导致存档损坏 |
| gzip / deflate 压缩 | 大数据存档可节省 60–80% 空间 |
| 版本迁移机制 | 游戏更新后自动升级旧存档 |
| 运行时存档管理 UI | 可嵌入游戏的槽位选择界面 |
| 编辑器底部面板 | 直接在编辑器中查看/删除/导入/导出存档 |
| 配置文件模块注册 | `save_modules.cfg` 控制模块加载顺序 |

---

## 安装

1. 将 `addons/enhance_save_system` 复制到项目 `addons/` 目录
2. `项目 > 项目设置 > 插件` 中启用 **Enhanced Save System**
3. 插件自动注册 `SaveSystem` AutoLoad 单例

---

## 快速上手

```gdscript
# 保存 / 加载
SaveSystem.save_slot(1)
SaveSystem.load_slot(1)
SaveSystem.quick_save()   # 全局 + 当前槽位
SaveSystem.quick_load()

# 删除 / 查询
SaveSystem.delete_slot(1)
SaveSystem.slot_exists(1)
var slots: Array[SlotInfo] = SaveSystem.list_slots()
```

---

## 配置项（Inspector）

### 基础
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `max_slots` | 8 | 最大槽位数 |
| `game_version` | "1.0.0" | 写入存档元数据的版本号 |
| `auto_register` | true | 自动扫描 Modules/ 目录注册模块 |

### 加密
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `encryption_enabled` | false | 启用加密 |
| `encryption_key` | "" | 加密密钥（请勿硬编码到发布版本） |
| `encryption_mode` | "aes_gcm" | `"xor"` / `"aes_cbc"` / `"aes_gcm"` |

> `aes_gcm` 推荐：同时提供加密和完整性验证。`xor` 仅用于向后兼容旧存档。

### 压缩
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `compression_enabled` | false | 启用压缩 |
| `compression_mode` | "gzip" | `"gzip"` / `"deflate"` |

> 压缩和加密同时启用时，管线为：JSON → 压缩 → 加密 → 写文件。

### 原子写入
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `atomic_write_enabled` | true | 先写 .tmp 再重命名，防止写入中断 |
| `backup_enabled` | false | 覆盖前保留 .bak 备份 |

### 自动存档
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `auto_save_enabled` | false | 启用定时自动存档 |
| `auto_save_interval` | 300 | 自动存档间隔（秒） |
| `auto_save_slot` | 1 | 自动存档槽位 |

### 模块注册
| 属性 | 默认值 | 说明 |
|------|--------|------|
| `use_module_config` | false | 使用配置文件控制模块加载顺序 |
| `module_config_path` | "res://save_modules.cfg" | 配置文件路径 |

---

## 文件格式

### 无加密/压缩（向后兼容）
纯 JSON 文本，`_meta` 字段包含版本、时间等元信息。

### 有加密或压缩（v3 二进制格式）
```
[4字节 LE: header_len][header JSON][body]
```
- `header JSON`：包含完整 `_meta`（含 `iv`/`tag`/`hmac` 等加密参数）
- `body`：密文或压缩数据

读取时自动识别格式，旧存档无需迁移。

---

## 信号

```gdscript
signal slot_saved(slot: int, ok: bool)
signal slot_loaded(slot: int, ok: bool)
signal slot_deleted(slot: int)
signal slot_changed(new_slot: int)
signal slot_load_failed(slot: int, reason: String)  # reason: "read_failed" / "integrity_error" / "migration_failed"
signal slot_backed_up(slot: int, backup_path: String)
signal save_migrated(slot: int, old_version: int, new_version: int)
signal global_saved(ok: bool)
signal global_loaded(ok: bool)
```

---

## 版本迁移

```gdscript
# 在游戏启动时注册迁移函数
SaveSystem.register_migration(1, func(payload: Dictionary) -> Dictionary:
    # 将 v1 格式升级到 v2
    if payload.has("player"):
        payload["player"]["stamina"] = 100  # 新增字段
    return payload
)
```

迁移前自动创建 `.pre_migration.bak` 备份。迁移失败时回滚并发出 `slot_load_failed` 信号。

---

## 运行时存档 UI

```gdscript
var ui = preload("res://addons/enhance_save_system/Components/SaveManager/save_manager_ui.tscn").instantiate()
ui.mode = SaveManagerUI.Mode.LOAD  # 或 .SAVE
add_child(ui)
ui.slot_selected.connect(func(slot): print("选择了槽位", slot))
```

---

## 自定义模块

```gdscript
class_name MyModule extends ISaveModule

func get_module_key() -> String: return "my_module"
func is_global() -> bool: return false

func collect_data() -> Dictionary:
    return { "score": GameState.score }

func apply_data(data: Dictionary) -> void:
    GameState.score = data.get("score", 0)

# 可选：版本迁移钩子
func migrate_payload(old_payload: Dictionary, old_version: int) -> Dictionary:
    if old_version < 2:
        old_payload["score"] = old_payload.get("points", 0)  # 字段重命名
    return old_payload
```

参考 `templates/migration_module_template.gd` 和 `templates/compressed_module_template.gd`。

---

## 模块配置文件（save_modules.cfg）

```ini
[module_player]
script = "res://Modules/player_module.gd"
enabled = true
priority = 10

[module_level]
script = "res://Modules/level_module.gd"
enabled = true
priority = 20
```

启用：`SaveSystem.use_module_config = true`

---

## Demo 场景

| 场景 | 说明 |
|------|------|
| `demo/full_feature_demo.tscn` | 加密 + 压缩 + 原子写入综合演示，含**压缩基准测试**按钮 |
| `demo/atomic_write_demo.tscn` | 原子写入和备份演示 |
| `demo/migration_demo.tscn` | 版本迁移完整流程演示 |
| `demo/save_manager_ui_demo.tscn` | SaveManagerUI 组件集成演示 |

---

## 目录结构

```
enhance_save_system/
├── core/
│   ├── save_system.gd        # AutoLoad 单例
│   ├── save_writer.gd        # 静态读写工具（二进制格式）
│   ├── encryptor.gd          # AES-GCM / AES-CBC / XOR
│   ├── compressor.gd         # gzip / deflate
│   ├── atomic_writer.gd      # 原子写入 + .bak 备份
│   ├── migration_manager.gd  # 版本迁移
│   ├── module_registry.gd    # 配置文件模块注册
│   ├── i_save_module.gd      # 模块抽象基类
│   └── slot_info.gd          # 槽位元信息
├── Components/SaveManager/
│   ├── save_manager_ui.gd    # 运行时槽位管理 UI
│   └── save_manager_ui.tscn
├── Modules/                  # 内置存档模块
├── demo/                     # 示例场景
├── templates/                # 模块模板
├── save_modules.cfg          # 模块注册配置示例
└── save_plugin.gd            # 编辑器插件 + 底部面板
```

---

## 兼容性

- Godot 4.2+
- 纯 GDScript，无外部依赖
- 旧版 XOR 加密存档可直接读取（自动识别格式）

## 许可证

MIT License
