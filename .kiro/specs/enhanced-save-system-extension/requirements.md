# 需求文档

## 简介

本文档描述对 Godot 4 插件 **Enhanced Save System**（`addons/enhance_save_system/`）的功能扩展与优化需求。
现有系统已具备模块化存档框架（ISaveModule）、双轨存档（global.json + slot_XX.json）、JSON 存储、ResourceSerializer、自动注册模块、自动存档、存档导入/导出、截图预览、XOR 加密等能力。

本次扩展涵盖六个方向：
1. 加密机制增强（AES-GCM/AES-CBC + HMAC，替换 XOR）
2. 写入原子性与备份（临时文件 + 重命名 + 可选 .bak）
3. 存档迁移机制（版本迁移钩子）
4. 性能与文件规模优化（可选压缩 + 按模块分文件）
5. 存档管理 UI（运行时槽位选择 UI + 编辑器面板）
6. 模块注册灵活性（配置列表 + 显式注册顺序）

同时提供配套的模板文件和 Demo 场景，帮助开发者快速上手新功能。

---

## 词汇表

- **SaveSystem**：AutoLoad 单例，存档系统的唯一全局入口。
- **SaveWriter**：纯静态读写工具，负责序列化/反序列化和文件 I/O。
- **ISaveModule**：存档模块抽象基类，所有模块必须继承此类。
- **Encryptor**：新增加密子系统，负责 AES-GCM/AES-CBC + HMAC 加密与验证。
- **AtomicWriter**：新增原子写入子系统，负责临时文件写入与重命名覆盖。
- **MigrationManager**：新增迁移管理器，负责存档版本升级。
- **Compressor**：新增压缩子系统，负责 gzip/deflate 压缩与解压。
- **SaveManagerUI**：新增运行时存档管理界面组件。
- **EditorPanel**：新增编辑器插件面板，用于开发时管理存档。
- **ModuleRegistry**：新增模块注册配置系统，支持配置文件驱动的注册顺序。
- **Payload**：存档文件中除 `_meta` 外的模块数据字典。
- **Slot**：存档槽位，对应 `slot_XX.json` 文件。
- **FORMAT_VERSION**：存档文件格式版本号，当前为 2。
- **HMAC**：基于哈希的消息认证码，用于验证数据完整性。
- **AES-GCM**：带认证的 AES 加密模式，同时提供加密和完整性验证。
- **AES-CBC**：AES 密码块链接模式，需配合 HMAC 使用。

---

## 需求

### 需求 1：加密机制增强

**用户故事：** 作为游戏开发者，我希望存档文件使用强加密算法保护，以防止玩家轻易篡改存档数据。

#### 验收标准

1. THE Encryptor SHALL 支持 AES-GCM 和 AES-CBC 两种加密模式，并在 `_meta` 中记录所用加密类型。
2. WHEN 加密模式为 AES-GCM 时，THE Encryptor SHALL 同时提供数据加密和完整性验证，无需额外 HMAC。
3. WHEN 加密模式为 AES-CBC 时，THE Encryptor SHALL 附加 HMAC-SHA256 签名以验证数据完整性。
4. WHEN 读取存档文件时，THE Encryptor SHALL 根据 `_meta.encryption_type` 字段自动选择对应解密方式。
5. IF 存档文件的 HMAC 验证失败，THEN THE Encryptor SHALL 返回错误码并拒绝加载该存档。
6. IF 存档文件的 HMAC 验证失败，THEN THE SaveSystem SHALL 发出 `slot_load_failed(slot, "integrity_error")` 信号。
7. THE SaveSystem SHALL 保留对旧版 XOR 加密存档的向后兼容读取支持，以便平滑迁移。
8. WHERE 开发者启用加密功能，THE SaveSystem SHALL 提供 `encryption_mode` 配置项，可选值为 `"xor"`、`"aes_cbc"`、`"aes_gcm"`。

### 需求 2：写入原子性与备份

**用户故事：** 作为游戏开发者，我希望存档写入过程具备原子性，以防止因写入中断（如断电、崩溃）导致存档文件损坏。

#### 验收标准

1. WHEN SaveSystem 写入存档文件时，THE AtomicWriter SHALL 先将数据写入同目录下的临时文件（后缀 `.tmp`），再通过重命名操作覆盖目标文件。
2. IF 临时文件写入失败，THEN THE AtomicWriter SHALL 删除临时文件并返回写入失败状态，不影响原有存档文件。
3. WHERE 开发者启用备份功能，THE AtomicWriter SHALL 在覆盖目标文件前将旧文件重命名为 `.bak` 备份。
4. WHERE 开发者启用备份功能，WHEN 新文件写入成功后，THE AtomicWriter SHALL 保留最新一份 `.bak` 备份文件。
5. THE SaveSystem SHALL 提供 `atomic_write_enabled` 配置项（默认 `true`）和 `backup_enabled` 配置项（默认 `false`）。
6. WHEN `backup_enabled` 为 `true` 且存档写入成功时，THE SaveSystem SHALL 发出 `slot_backed_up(slot, backup_path)` 信号。

### 需求 3：存档迁移机制

**用户故事：** 作为游戏开发者，我希望系统能自动将旧版本存档升级到当前格式，以保证游戏更新后玩家存档不丢失。

#### 验收标准

1. THE MigrationManager SHALL 维护一个从旧版本号到新版本号的迁移函数注册表。
2. WHEN 加载存档文件时，IF 存档的 `_meta.version` 低于当前 `FORMAT_VERSION`，THEN THE MigrationManager SHALL 按版本号顺序依次调用对应的迁移函数。
3. THE ISaveModule SHALL 提供可选重写方法 `migrate_payload(old_payload: Dictionary, old_version: int) -> Dictionary`，供模块自定义迁移逻辑。
4. WHEN 迁移完成后，THE MigrationManager SHALL 将 `_meta.version` 更新为当前 `FORMAT_VERSION`。
5. IF 迁移过程中任意步骤抛出错误，THEN THE MigrationManager SHALL 回滚到迁移前的原始数据并返回迁移失败状态。
6. THE SaveSystem SHALL 提供 `register_migration(from_version: int, migration_fn: Callable)` 方法，供开发者注册全局迁移函数。
7. WHEN 存档迁移成功时，THE SaveSystem SHALL 发出 `save_migrated(slot, old_version, new_version)` 信号。
8. THE MigrationManager SHALL 在迁移前自动创建原始存档的备份文件（后缀 `.pre_migration.bak`）。

### 需求 4：性能与文件规模优化

**用户故事：** 作为游戏开发者，我希望在存档数据量较大时能够压缩存档文件或按模块分文件存储，以降低内存峰值和 I/O 开销。

#### 验收标准

1. WHERE 开发者启用压缩功能，THE Compressor SHALL 在写入 JSON 字符串前使用 gzip 或 deflate 算法进行压缩，并在 `_meta.compression` 字段记录所用算法。
2. WHEN 读取存档文件时，THE Compressor SHALL 根据 `_meta.compression` 字段自动选择对应解压方式。
3. IF `_meta.compression` 字段不存在，THEN THE Compressor SHALL 将文件视为未压缩格式直接读取。
4. THE SaveSystem SHALL 提供 `compression_enabled` 配置项（默认 `false`）和 `compression_mode` 配置项，可选值为 `"gzip"` 和 `"deflate"`。
5. WHERE 开发者启用按模块分文件存储，THE SaveWriter SHALL 将每个模块的数据写入独立文件（命名规则：`slot_XX_<module_key>.json`）。
6. WHERE 开发者启用按模块分文件存储，THE SaveWriter SHALL 仍在主槽位文件中保留 `_meta` 信息和模块文件索引。
7. THE SaveSystem SHALL 提供 `split_modules_enabled` 配置项（默认 `false`）。
8. WHEN 压缩和加密同时启用时，THE SaveWriter SHALL 先压缩再加密，读取时先解密再解压。
9. FOR ALL 有效的存档数据，压缩后再解压 SHALL 得到与原始数据完全相同的内容（往返属性）。

### 需求 5：存档管理 UI

**用户故事：** 作为游戏开发者，我希望插件提供开箱即用的存档槽位选择界面和编辑器管理面板，以减少重复的 UI 开发工作。

#### 验收标准

1. THE SaveManagerUI SHALL 提供一个可实例化的场景（`save_manager_ui.tscn`），展示所有槽位的截图预览、存档时间和描述信息。
2. WHEN 玩家点击某个槽位时，THE SaveManagerUI SHALL 发出 `slot_selected(slot: int)` 信号。
3. WHEN 玩家点击删除按钮时，THE SaveManagerUI SHALL 弹出确认对话框，确认后调用 `SaveSystem.delete_slot(slot)`。
4. THE SaveManagerUI SHALL 实时反映 SaveSystem 的 `slot_saved`、`slot_loaded`、`slot_deleted` 信号，自动刷新显示内容。
5. THE SaveManagerUI SHALL 支持"保存"和"加载"两种操作模式，通过 `mode` 属性切换（可选值：`"save"`、`"load"`）。
6. THE EditorPanel SHALL 在 Godot 编辑器底部面板中提供存档管理界面，支持查看、删除、导入、导出存档槽位。
7. WHEN 编辑器处于运行模式时，THE EditorPanel SHALL 实时刷新槽位列表。
8. THE EditorPanel SHALL 支持将存档文件导出到开发者指定路径，并支持从外部文件导入覆盖指定槽位。

### 需求 6：模块注册灵活性

**用户故事：** 作为游戏开发者，我希望能够通过配置文件控制模块的注册顺序和启用状态，以便在不修改代码的情况下管理模块加载行为。

#### 验收标准

1. THE ModuleRegistry SHALL 支持读取 `save_modules.cfg` 配置文件，按文件中定义的顺序加载并注册模块。
2. THE `save_modules.cfg` 文件 SHALL 支持为每个模块条目指定脚本路径、启用状态（`enabled`）和加载优先级（`priority`）。
3. WHEN `save_modules.cfg` 存在时，THE ModuleRegistry SHALL 优先使用配置文件中的顺序，忽略文件系统的自然排序。
4. WHEN `save_modules.cfg` 中某模块的 `enabled` 为 `false` 时，THE ModuleRegistry SHALL 跳过该模块的加载，不发出警告。
5. IF `save_modules.cfg` 中指定的脚本路径不存在，THEN THE ModuleRegistry SHALL 发出警告并跳过该条目，继续加载其余模块。
6. THE SaveSystem SHALL 提供 `use_module_config` 配置项（默认 `false`）和 `module_config_path` 配置项（默认 `"res://save_modules.cfg"`）。
7. THE SaveSystem 的 `register_module()` 方法 SHALL 支持可选的 `priority: int` 参数，数值越小越先执行 `collect_data` 和 `apply_data`。

### 需求 7：模板与 Demo

**用户故事：** 作为游戏开发者，我希望插件提供完整的模板文件和 Demo 场景，以便快速理解和使用新增功能。

#### 验收标准

1. THE 插件 SHALL 提供 `templates/migration_module_template.gd`，演示如何为模块实现 `migrate_payload` 迁移钩子。
2. THE 插件 SHALL 提供 `templates/compressed_module_template.gd`，演示如何在模块中配合压缩功能使用。
3. THE 插件 SHALL 提供 `demo/atomic_write_demo.tscn` 场景，演示原子写入和备份功能的使用方式。
4. THE 插件 SHALL 提供 `demo/migration_demo.tscn` 场景，演示从旧版本存档迁移到新版本的完整流程。
5. THE 插件 SHALL 提供 `demo/save_manager_ui_demo.tscn` 场景，演示 SaveManagerUI 组件的集成方式。
6. THE 插件 SHALL 提供 `demo/full_feature_demo.tscn` 场景，综合演示所有新增功能（加密 + 压缩 + 原子写入 + 迁移 + UI）。
7. WHEN 运行任意 Demo 场景时，THE Demo SHALL 在不依赖外部资源的情况下独立运行，并在界面上显示操作结果。
8. THE 插件 SHALL 提供 `save_modules.cfg` 示例配置文件，包含注释说明每个字段的用途和可选值。
