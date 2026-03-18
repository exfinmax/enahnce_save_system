# 实现计划：Enhanced Save System 插件扩展

## 概述

按照"先基础层、后上层"的顺序实现六个子系统：
先扩展核心数据结构，再依次实现 Encryptor、AtomicWriter、Compressor、MigrationManager、ModuleRegistry，
然后将各子系统集成到 SaveWriter / SaveSystem，最后实现 UI 层、模板、Demo 和测试。

---

## 任务

- [x] 1. 扩展核心数据结构
  - [x] 1.1 扩展 `core/slot_info.gd`，新增 `description`、`format_version`、`encryption_type`、`compression` 字段，并更新 `make()` 静态工厂方法从 `_meta` 中读取这些字段
    - _需求：5.1_
  - [x] 1.2 扩展 `core/i_save_module.gd`，新增可选虚方法 `migrate_payload(old_payload: Dictionary, old_version: int) -> Dictionary`，默认实现直接返回 `old_payload`
    - _需求：3.3_
  - [ ]* 1.3 为 `SlotInfo` 新字段编写单元测试，验证 `make()` 能正确从 `_meta` 中读取 `format_version`、`encryption_type`、`compression`
    - _需求：5.1_

- [x] 2. 实现 Encryptor（`core/encryptor.gd`）
  - [x] 2.1 创建 `core/encryptor.gd`，定义 `Mode` 枚举（XOR / AES_CBC / AES_GCM），实现 `encrypt(plaintext, key, mode) -> Dictionary` 和 `decrypt(meta, key) -> PackedByteArray` 静态方法；AES-CBC 使用 `AESContext.MODE_CBC` + `HMACContext`（SHA-256），AES-GCM 使用 CTR 模式 + GHASH 认证；IV 每次随机生成 16 字节；Key 派生使用 `key.sha256_buffer()` 取前 32 字节
    - _需求：1.1、1.2、1.3_
  - [x] 2.2 在 `Encryptor` 中实现 `verify_hmac(data, hmac, key) -> bool` 和 `decrypt_xor(data, key) -> PackedByteArray`，保留 XOR 向后兼容
    - _需求：1.4、1.7_
  - [ ]* 2.3 编写属性测试：加密往返（属性 1）
    - **属性 1：加密往返**
    - 对任意明文字节数组和任意加密模式（AES-GCM、AES-CBC），加密后再解密应得到原始明文，且 `_meta.encryption_type` 记录所用模式
    - **验证：需求 1.1、1.2、1.3、1.4**
  - [ ]* 2.4 编写属性测试：完整性验证失败拒绝加载（属性 2）
    - **属性 2：完整性验证失败拒绝加载**
    - 对任意已加密存档，翻转密文任意一位后 `Encryptor.decrypt()` 应返回错误
    - **验证：需求 1.5、1.6**
  - [ ]* 2.5 编写属性测试：XOR 向后兼容（属性 3）
    - **属性 3：XOR 向后兼容**
    - 对任意使用旧版 XOR 加密写入的数据，新版 `decrypt_xor()` 应能正确解密
    - **验证：需求 1.7**

- [x] 3. 实现 AtomicWriter（`core/atomic_writer.gd`）
  - [x] 3.1 创建 `core/atomic_writer.gd`，实现 `write(path, data, backup_enabled) -> Error` 静态方法：先写 `path + ".tmp"`，若 `backup_enabled` 且目标文件存在则 rename 为 `.bak`，再 rename `.tmp` → 目标；任意步骤失败时删除 `.tmp` 并返回 `FAILED`；实现 `get_backup_path()` 和 `get_tmp_path()` 辅助方法
    - _需求：2.1、2.2、2.3、2.4_
  - [ ]* 3.2 编写属性测试：原子写入后文件完整（属性 4）
    - **属性 4：原子写入后文件完整**
    - 对任意存档数据，`AtomicWriter.write()` 后目标文件存在且内容一致，`.tmp` 不残留
    - **验证：需求 2.1、2.2**
  - [ ]* 3.3 编写属性测试：备份写入保留旧数据（属性 5）
    - **属性 5：备份写入保留旧数据**
    - 对任意已存在的存档文件，`backup_enabled=true` 再次写入后 `.bak` 内容为写入前的旧数据
    - **验证：需求 2.3、2.4、2.6**

- [x] 4. 实现 Compressor（`core/compressor.gd`）
  - [x] 4.1 创建 `core/compressor.gd`，定义 `Mode` 枚举（GZIP / DEFLATE），实现 `compress(data, mode) -> PackedByteArray` 和 `decompress(data, mode) -> PackedByteArray` 静态方法，使用 Godot 内置 `PackedByteArray.compress()` / `decompress_dynamic()`；实现 `mode_from_string()` 和 `mode_to_string()` 辅助方法
    - _需求：4.1、4.2、4.3_
  - [ ]* 4.2 编写属性测试：压缩往返（属性 9）
    - **属性 9：压缩往返**
    - 对任意有效字节数组和任意压缩模式（gzip、deflate），压缩后再解压应得到原始数据
    - **验证：需求 4.1、4.2、4.9**

- [ ] 5. 检查点 — 确保所有测试通过，如有疑问请向用户提问

- [x] 6. 实现 MigrationManager（`core/migration_manager.gd`）
  - [x] 6.1 创建 `core/migration_manager.gd`，实现 `register(from_version, migration_fn)` 注册方法和 `migrate(payload, current_version, target_version) -> Dictionary` 迁移方法：深拷贝备份原始 payload，按版本号顺序依次调用迁移函数，每步调用各模块的 `migrate_payload()`（若已重写），更新 `_meta.version`；任意步骤异常时回滚到备份；实现 `needs_migration()` 和 `last_error` 属性
    - _需求：3.1、3.2、3.4、3.5、3.6_
  - [x] 6.2 在 `MigrationManager.migrate()` 中，迁移前自动创建 `.pre_migration.bak` 备份文件（调用 `AtomicWriter` 或直接文件复制）
    - _需求：3.8_
  - [ ]* 6.3 编写属性测试：迁移版本升级（属性 6）
    - **属性 6：迁移版本升级**
    - 对任意版本号低于 `FORMAT_VERSION` 的存档，`migrate()` 应按版本顺序调用所有迁移函数，完成后 `_meta.version` 等于 `FORMAT_VERSION`
    - **验证：需求 3.1、3.2、3.4、3.7**
  - [ ]* 6.4 编写属性测试：迁移失败回滚（属性 7）
    - **属性 7：迁移失败回滚**
    - 对任意存档数据，若迁移过程中任意步骤抛出错误，`migrate()` 应返回与迁移前完全相同的原始数据，`_meta.version` 不变
    - **验证：需求 3.5**
  - [ ]* 6.5 编写属性测试：迁移前备份（属性 8）
    - **属性 8：迁移前备份**
    - 对任意需要迁移的存档文件，`MigrationManager` 在执行迁移前应创建 `.pre_migration.bak` 文件，内容为迁移前的原始存档数据
    - **验证：需求 3.8**

- [x] 7. 实现 ModuleRegistry（`core/module_registry.gd`）
  - [x] 7.1 创建 `core/module_registry.gd`，实现 `load_from_config(config_path) -> Array[ISaveModule]` 方法：解析 `ConfigFile`，按 `priority` 升序排序，跳过 `enabled=false` 的条目，路径不存在时 `push_warning` 并跳过，返回有序模块数组；实现 `_parse_entry()` 辅助方法
    - _需求：6.1、6.2、6.3、6.4、6.5_
  - [x] 7.2 创建 `save_modules.cfg` 示例配置文件，包含注释说明每个字段（`path`、`enabled`、`priority`）的用途和可选值
    - _需求：6.2、7.8_
  - [ ]* 7.3 编写属性测试：配置文件驱动注册顺序（属性 11）
    - **属性 11：配置文件驱动注册顺序**
    - 对任意包含多个模块条目的配置，`load_from_config()` 返回的数组应按 `priority` 升序排列，`enabled=false` 的模块不出现在结果中
    - **验证：需求 6.1、6.2、6.3、6.4**
  - [ ]* 7.4 编写属性测试：无效路径跳过不中断（属性 12）
    - **属性 12：无效路径跳过不中断**
    - 对任意包含不存在脚本路径的配置，`load_from_config()` 应跳过该条目并继续加载其余有效模块，不抛出异常
    - **验证：需求 6.5**

- [ ] 8. 检查点 — 确保所有测试通过，如有疑问请向用户提问

- [x] 9. 集成 SaveWriter（`core/save_writer.gd`）
  - [x] 9.1 修改 `SaveWriter.write_json()`：集成 `Compressor`（若 `compression_enabled`）和 `Encryptor`（替换内置 XOR），将加密/压缩元信息写入 `_meta`；集成 `AtomicWriter`（若 `atomic_write_enabled`）替换直接写文件逻辑；写入顺序：JSON 字符串 → compress → encrypt → AtomicWriter
    - _需求：2.1、4.1、4.8_
  - [x] 9.2 修改 `SaveWriter.read_json()`：读取时根据 `_meta` 字段自动选择解密（`Encryptor.decrypt()`）和解压（`Compressor.decompress()`）路径；读取顺序：读文件 → decrypt → decompress → JSON.parse；`_meta.encryption_type` 不存在时降级为 XOR 向后兼容
    - _需求：1.4、1.7、4.2、4.3、4.8_
  - [x] 9.3 在 `SaveWriter.write_json()` 中实现分模块文件写入（`split_modules_enabled=true`）：将每个模块数据写入独立文件 `slot_XX_<module_key>.json`，主文件保留 `_meta` 和 `_index`
    - _需求：4.5、4.6_
  - [x] 9.4 在 `SaveWriter.read_json()` 中实现分模块文件读取：检测 `_meta.split_modules=true` 时，按 `_index` 读取各模块独立文件并合并
    - _需求：4.5、4.6_
  - [ ]* 9.5 编写属性测试：压缩加密组合顺序（属性 10）
    - **属性 10：压缩加密组合顺序**
    - 对任意存档数据，在压缩和加密同时启用时，写入后读取应得到原始数据（验证先压缩后加密、先解密后解压的顺序正确性）
    - **验证：需求 4.8**

- [x] 10. 集成 SaveSystem（`core/save_system.gd`）
  - [x] 10.1 在 `save_system.gd` 中新增配置属性：`encryption_mode`（"xor"/"aes_cbc"/"aes_gcm"）、`atomic_write_enabled`（默认 true）、`backup_enabled`（默认 false）、`compression_enabled`（默认 false）、`compression_mode`（"gzip"/"deflate"）、`split_modules_enabled`（默认 false）、`use_module_config`（默认 false）、`module_config_path`（默认 "res://save_modules.cfg"）
    - _需求：1.8、2.5、4.4、4.7、6.6_
  - [x] 10.2 在 `save_system.gd` 中新增信号：`slot_load_failed(slot, reason)`、`slot_backed_up(slot, backup_path)`、`save_migrated(slot, old_version, new_version)`；在 `load_slot()` 中集成 `MigrationManager`，迁移成功后发出 `save_migrated` 信号，HMAC 验证失败时发出 `slot_load_failed` 信号；在 `save_slot()` 中备份成功后发出 `slot_backed_up` 信号
    - _需求：1.6、2.6、3.7_
  - [x] 10.3 修改 `SaveSystem.register_module()` 支持可选 `priority: int` 参数，内部按 priority 升序维护模块执行顺序；修改 `_auto_register_modules()` 在 `use_module_config=true` 时委托给 `ModuleRegistry.load_from_config()`
    - _需求：6.6、6.7_
  - [x] 10.4 更新 `SaveSystem.list_slots()` 使用扩展后的 `SlotInfo.make()`，确保新字段（`format_version`、`encryption_type`、`compression`）正确填充
    - _需求：5.1_
  - [ ]* 10.5 编写属性测试：priority 参数影响执行顺序（属性 13）
    - **属性 13：priority 参数影响执行顺序**
    - 对任意通过 `register_module(module, priority)` 注册的模块集合，`collect_data` 和 `apply_data` 的调用顺序应与 priority 升序一致
    - **验证：需求 6.7**

- [ ] 11. 检查点 — 确保所有测试通过，如有疑问请向用户提问

- [x] 12. 实现 SaveManagerUI（`Components/SaveManager/`）
  - [x] 12.1 创建 `Components/SaveManager/slot_card.gd` 和 `slot_card.tscn`：节点结构为 `SlotCard (PanelContainer)` → `VBoxContainer` → `PreviewImage (TextureRect)`、`TimeLabel`、`DescLabel`、`HBoxContainer`（`ActionButton` + `DeleteButton`）；`ActionButton` 文本根据父级 `mode` 显示"保存"或"加载"
    - _需求：5.1_
  - [x] 12.2 创建 `Components/SaveManager/save_manager_ui.gd` 和 `save_manager_ui.tscn`：节点结构为 `SaveManagerUI (Control)` → `VBoxContainer`（`TitleLabel` + `ScrollContainer` → `SlotGrid (GridContainer)`）+ `ConfirmDialog`；实现 `mode` 属性（SAVE/LOAD）、`slot_selected(slot)` 和 `slot_deleted(slot)` 信号、`refresh()` 方法；在 `_ready()` 中连接 `SaveSystem` 的 `slot_saved`、`slot_loaded`、`slot_deleted` 信号自动刷新
    - _需求：5.1、5.2、5.3、5.4、5.5_
  - [x] 12.3 在 `SaveManagerUI` 中实现删除确认流程：点击删除按钮弹出 `ConfirmDialog`，确认后调用 `SaveSystem.delete_slot(slot)` 并发出 `slot_deleted` 信号
    - _需求：5.3_

- [x] 13. 实现编辑器面板（`save_plugin.gd` 扩展）
  - [x] 13.1 在 `save_plugin.gd` 中新增 `_build_editor_panel() -> Control` 方法，构建底部面板节点结构：`EditorPanel (VBoxContainer)` → `ToolBar (HBoxContainer)`（`RefreshButton`、`ExportButton`、`ImportButton`）+ `SlotTree (Tree)`（列：槽位/时间/版本/操作）；在 `_enter_tree()` 中调用 `add_control_to_bottom_panel()` 注册面板
    - _需求：5.6_
  - [x] 13.2 在编辑器面板中实现 `_refresh_slot_list()`、`_on_export_pressed(slot)`、`_on_import_pressed(slot)`、`_on_delete_pressed(slot)` 方法；运行模式下连接 `SaveSystem` 信号实时刷新槽位列表
    - _需求：5.7、5.8_

- [x] 14. 创建模板文件
  - [x] 14.1 创建 `templates/migration_module_template.gd`，演示如何继承 `ISaveModule` 并重写 `migrate_payload(old_payload, old_version) -> Dictionary`，包含版本分支处理示例和注释说明
    - _需求：7.1_
  - [x] 14.2 创建 `templates/compressed_module_template.gd`，演示如何在模块中配合 `Compressor` 使用，包含在 `collect_data` / `apply_data` 中手动压缩大型数据的示例
    - _需求：7.2_

- [x] 15. 创建 Demo 场景
  - [x] 15.1 创建 `demo/atomic_write_demo.tscn` 和 `demo/atomic_write_demo.gd`：演示 `AtomicWriter` 原子写入和备份功能，界面显示写入结果和 `.bak` 文件状态，不依赖外部资源
    - _需求：7.3、7.7_
  - [x] 15.2 创建 `demo/migration_demo.tscn` 和 `demo/migration_demo.gd`：演示从旧版本（version=1）存档迁移到当前 `FORMAT_VERSION` 的完整流程，界面显示迁移前后的 `_meta.version` 变化，不依赖外部资源
    - _需求：7.4、7.7_
  - [x] 15.3 创建 `demo/save_manager_ui_demo.tscn` 和 `demo/save_manager_ui_demo.gd`：实例化 `SaveManagerUI` 组件，演示保存/加载模式切换和槽位操作，不依赖外部资源
    - _需求：7.5、7.7_
  - [x] 15.4 创建 `demo/full_feature_demo.tscn` 和 `demo/full_feature_demo.gd`：综合演示加密 + 压缩 + 原子写入 + 迁移 + UI 的完整工作流，界面显示每个步骤的操作结果，不依赖外部资源
    - _需求：7.6、7.7_

- [x] 16. 最终检查点 — 确保所有测试通过，如有疑问请向用户提问

---

## 备注

- 标有 `*` 的子任务为可选测试任务，可跳过以加快 MVP 进度
- 每个任务均引用具体需求条款以保证可追溯性
- 属性测试使用 GdUnit4 框架，每个属性测试最少运行 100 次迭代
- 每个属性测试文件顶部须包含注释：`# Feature: enhanced-save-system-extension, Property N: <属性描述>`
- 实现顺序：基础层（1-4）→ 迁移/注册层（6-7）→ 集成层（9-10）→ UI 层（12-13）→ 模板/Demo（14-15）
