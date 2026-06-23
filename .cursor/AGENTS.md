# FolatIsland Agent 分工

本项目用 **Cursor Rules** 划分职责。在对应对话里 `@` 相关文件或规则名即可激活。

| Agent | 规则文件 | 专属对话怎么开 |
|-------|----------|----------------|
| **Git 版本管理** | `.cursor/rules/agent-git.mdc` | 新建 Chat → `@.gitignore` 或 `@agent-git` |
| **打包** | `.cursor/rules/agent-export-apk.mdc` | 新建 Chat → `@export_presets.cfg` 或 `@agent-export-apk` |
| Avatar | `agent-avatar.mdc` | `@scenes/avatar.tscn` |
| 场景 | `agent-scene.mdc` | `@scene1.tscn` |
| 核心逻辑 | `agent-core.mdc` | `@scripts/player.gd` |

## Git Agent 快捷入口

- **典型指令**：「提交当前改动」「推送到 GitHub」「开 PR」「检查不该提交的文件」
- Git 对话只谈版本管理；改代码请换 Core/Scene/Avatar 对话

## 打包 Agent 快捷入口

- **快捷键**：`Ctrl + Shift + B` → 导出 + 签名 + 安装
- **脚本**：`bash build_install.sh` 或双击 `build_install.bat`
- **典型指令**：「打包安装」「adb 安装」「修签名/横屏/天空盒」

打包对话只谈导出、签名、安装、移动端配置；玩法和美术请换其他 Agent 对话。
