# 🚀 CoolCMD

**CoolCMD** 是一个为 Windows CMD 用户打造的极客环境增强方案。它通过 Clink、Oh-My-Posh 和 Rust 工具链，将原生 CMD 改造为具备 Linux 灵魂的现代化终端。

## ✨ 特性

- Linux 命令融合：在 CMD 中直接使用 ls, rm, cat, grep, cp, mv 等常用命令。
- 智能配色注入：自动解析并加载 trapd00r/LS_COLORS，并具备 **性能缓存机制**（由 LS_COLORS_FULL_CACHE 驱动），实现秒开。
- 视觉增强：完美的图标支持（LSD）和语法高亮（Bat）。
- 安全保障：默认开启 rm, cp, mv 的交互式确认，防止误删。
- 一键部署：通过 curl 一条命令完成全套工具链和配置的安装。

## 📦 一键起飞 (One-Liner)

在你的 CMD (管理员模式) 中粘贴并运行以下指令：

```cmd
curl -fsSL https://bit.ly/coolcmd -o cool.cmd && cool.cmd
```

## 🛠️ 包含工具

| 工具             | 功能                               |
| ---------------- | ---------------------------------- |
| Clink            | 强大的 CMD 自动补全与 Lua 脚本扩展 |
| Oh-My-Posh       | 极漂亮的命令行提示符 (Prompt)      |
| LSD              | 带图标和色彩的 ls 替代品           |
| Bat              | 支持语法高亮的 cat 替代品          |
| Ripgrep (rg)     | 全世界最快的搜索工具 (grep 别名)   |
| Uutils Coreutils | Rust 编写的 Linux 核心工具集       |
| MesloLGM NF      | 完美的 Nerd Font 字体支持          |

## ⚙️ 配置文件说明

- coolcmd.lua: 核心逻辑中心。处理别名映射、环境注入及缓存管理。
- LS_COLORS: 原始配色数据库。
- LS_COLORS_FULL_CACHE: 自动生成的预处理缓存文件，显著提升启动速度。

## 🙏 特别致谢

- 感谢 trapd00r 提供的全量 LS_COLORS 数据库。
- 感谢 **我的 AI 协作伙伴**：在漫长的 Debug 过程中，它帮我搞定了复杂的 Lua 字符串清洗、递归项过滤、CMD 字符限制绕过以及缓存机制的逻辑设计。如果没有这位博学又耐心的 AI peer，CoolCMD 的诞生可能还要再晚几个小时。🤭

## ⚠️ 注意事项

安装完成后，请务必在 **Windows Terminal** 设置中手动将字体切换为 **「MesloLGM NF」**，否则图标无法正常显示。
