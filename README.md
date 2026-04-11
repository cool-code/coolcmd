# 🚀 CoolCMD

**CoolCMD** 是一个为 Windows CMD 深度定制的极客环境增强方案。它将原生 CMD 的轻量级优势与 Linux Shell 的强大功能完美融合，提供丝滑、彩色且带有图标的现代化终端体验。

## ✨ 特性

- Linux 命令融合：在 CMD 中直接使用 ls, rm, cat, grep, ps, top, df 等命令。
- 智能配色引擎：自动解析 trapd00r/LS_COLORS，内置 **高性能二级缓存机制**，确保终端秒开。
- Unix 信号兼容：特别优化的 kill 系列宏，支持忽略 -9 等 Unix 信号参数，完美适配 Linux 用户习惯。
- 视觉巅峰：深度集成 LSD（图标支持）和 Oh-My-Posh（现代提示符）。
- 安全第一：默认开启 rm, cp, mv 的交互式确认，守护你的数据。
- 一键起飞：通过 curl 一条命令完成全套工具链、字体及配置的自动化部署。

## 📦 一键起飞 (One-Liner)

在 CMD 或 PowerShell (管理员模式) 中运行：

```cmd
curl -fsSL https://bit.ly/coolcmd -o cool.cmd && .\cool.cmd
```

## 🛠️ 包含工具集 (Rust-powered)

| 命令     | 工具         | 功能                                  |
| -------- | ------------ | ------------------------------------- |
| ls / ll  | LSD          | 带图标和 24 位真彩色的文件列表        |
| cat      | Bat          | 带有语法高亮和 Git 状态的文本查看     |
| grep     | Ripgrep (rg) | 全球最快的文本搜索工具                |
| top      | Btop         | 炫酷的交互式系统资源监视器            |
| ps       | Procs        | 彩色的进程信息查看器                  |
| rm/cp/mv | uutils       | GNU Coreutils 的 Rust 跨平台实现      |
| cool     | Clink        | [独家] 热重载命令，修改配置后即刻生效 |


## 🛠️ 自动化安装清单

CoolCMD 的安装脚本 `cool.cmd` 会自动执行以下流程，确保环境一键就位：

1. **核心引擎：** 安装 **Clink** (透过注册表动态侦测路径) 并设置为 CMD 自动注入。
2. **Linux 工具链：**
    1. **uutils coreutils**: 提供 `rm`, `cp`, `mv`, `df`, `du` 等核心命令。
    2. **LSD**: 替代 `ls`，提供图标与色彩支持。
    3. **Bat**: 替代 `cat`，提供语法高亮。
    4. **Ripgrep(rg)** : 提供极速文本搜索。
    5. **btop**: 现代化系统资源监视器。
    6. **Procs**: 进阶进程管理工具。
3. **视觉与主题：**
    1. Oh-My-Posh: 安装主题引擎并自动部署 `jandedobbeleer` 经典配置。
    2. Meslo Nerd Font: 透过 Oh-My-Posh 自动下载并安装适配图标的专用字体。
4. **配置同步：**
   1. 从 GitHub 云端拉取最新的 `coolcmd.lua` 与 `LS_COLORS` 数据。
   2. **自动注入 cool 重载指令**，精确匹配当前系统的 Clink 安装路径。
   3. 自动清理旧缓存，触发首次启动的高性能解析。

## ⚙️ 配置文件

- coolcmd.lua: 核心 Lua 逻辑。管理别名映射、环境变量注入及缓存机制。
- LS_COLORS: 原始配色数据库。
- LS_COLORS_FULL_CACHE: 自动生成的解析缓存，避免重复计算（如果原始 LS_COLORS 有手动更新，请删除该文件以同步更新）。

## 🧠 开发者笔记 (Developer Notes)

CoolCMD 在设计上绕过了许多 CMD 的原生限制：


1. **环境变量长度突破：** 通过 Lua 动态读取缓存并注入 os.setenv，解决了 setx 命令的 1024 字符限制，同时实现了 8000+ 字符的智能截断，确保 LS_COLORS 既全又不崩溃。
2. **进程管理宏逻辑：**
   1. 针对 `kill -9 <PID>`，我们设计了基于 `$T` 命令链和 `for` 循环的别名逻辑。
   2. 该逻辑会自动迭代所有参数并提取最后一个作为有效目标，从而实现对 Unix 信号参数的「语义忽略」。
   3. 使用 `@echo off` 隐藏中间件逻辑，保持输出界面整洁。
3. **热更新机制：** 通过 `cool` 别名调用 Clink 内部的 `set` 触发器，强制刷新脚本执行环境，无需重启窗口即可更新别名和配色。通过 `cool` 别名重新加载 Clink 跟使用 <kbd>ctrl</kbd>+<kbd>x</kbd>,<kbd>ctrl</kbd>+<kbd>r</kbd> 快捷键不同，如果更新的脚本有错误，使用快捷键重新加载 Clink 会导致 Clink 崩溃，而使用 `cool` 别名方式不会，它拒绝加载错误脚本，保持原来的环境不变。
4. **静默安装：** 使用了 `--source winget` 与 `autorun install -- -q`，尽量减少弹窗干扰。
5. **清理自毁：** 脚本执行完毕后会启动一个后台进程自我删除 ` (del "%~f0")`，保持用户下载目录整洁。

## 🙏 特别致谢

- 感谢 trapd00r 提供的全量 LS_COLORS 数据库。
- 感谢 **AI 协作伙伴**：在漫长的 Debug 过程中，协助完成了复杂的 Lua 字符串清洗、多方案热重载测试以及 CMD 别名嵌套限制的规避。

## ⚠️ 注意事项

安装完成后，请务必在 **Windows Terminal** 设置中手动将字体切换为 **「MesloLGM Nerd Font」**，否则图标无法正常显示。
