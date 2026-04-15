# 🚀 CoolCMD

**CoolCMD** 是一个为 Windows CMD 深度定制的极客环境增强方案。它将原生 CMD 的轻量级优势与 Linux Shell 的强大功能完美融合，提供丝滑、彩色且带有图标的现代化终端体验，并将启动延迟压榨到了极致。

## ✨ 核心特性

- 🚀 **极致效能**：内建双重缓存机制（`TOOLS` & `LANG`），启动与重载仅需 17~18ms，实现「**闪现**」般的开启体验。
- 🧠 **环境感知**：自动侦测 `LSD`, `Bat`, `Ripgrep`, `Btop` 等工具。若缺失，则智慧降级 (Smart Fallback) 至 `PowerShell` 或 `CMD` 原生指令，确保环境永不崩溃。
- 🌍 **自动语言适配**：自动侦测系统区域设置（如 `zh_CN`, `zh_TW`），智慧生成 `LANG` 环境变数，完美解决 `ls` 与 `grep` 的中文乱码。
- 🎯 **Unix 语义模拟**：提供了 `kill`, `pkill`, `killall`, `free`, `utime`, `clear` 等一系列现有工具不支持的 Unix/Linux 命令的别名实现。
- 🪄 **智能配色引擎**：自动解析 trapd00r/LS_COLORS，让文件列表色彩不再单调，内置 **高性能二级缓存机制**，确保终端秒开。
- 🔧 **现代化工具链**：深度集成 Rust 编写的高性能工具（LSD, Bat, Rg, Procs, Btop, uutils）。
- 🎨 **视觉巅峰**：集成 LSD（图标支持）和 Oh-My-Posh 提示符与图标支持，实现 24 位真彩色终端美学。
- 🛡️ **安全第一**：默认开启 rm, cp, mv 的交互式确认，守护你的数据。
- 🪁 **一键起飞**：通过 curl 一条命令完成全套工具链、字体及配置的自动化部署。

## 📦 一键起飞 (One-Liner)

在 **CMD** 或 **PowerShell** (管理员模式) 中粘贴并运行：

```cmd
curl -fsSL https://bit.ly/coolcmd -o cool.cmd && .\cool.cmd
```

## 🛠️ 包含工具与智慧映射

| 工具         | 智慧映射（Alias）                  | 智慧降级(Fallback)   | 功能                               |
| ------------ | ---------------------------------- | -------------------- | ---------------------------------- |
| LSD          | ls, ll, la, l1, lt, ld, lf ...     | dir (带 /OG 排序)    | 带图标和 24 位真彩色的文件列表     |
| Bat          | cat                                | type                 | 带有语法高亮和 Git 状态的文本查看  |
| Ripgrep (rg) | grep                               | findstr              | 全球最快的文本搜索工具             |
| Btop         | top                                | resmon               | 炫酷的交互式系统资源监视器         |
| Procs        | ps                                 | tasklist             | 彩色的进程信息查看器               |
| uutils       | rm, cp, mv                         | del, copy, move      | GNU Coreutils 的 Rust 跨平台实现   |
| PowerShell   | free, utime, df, du                |                      | 跟 linux 命令一样的 Windows 实现   |
| CMD          | clear, which, kill, pkill, killall | cls, where, taskkill | 将 linux 命令映射为 Windows 命令上 |
| Clink        | cool                               |                      | 热重载命令，修改配置后即刻生效     |


## 🛠️ 自动化安装清单

CoolCMD 的安装脚本 `cool.cmd` 会自动执行以下流程，确保环境一键就位：

1. **核心引擎：** 安装 **Clink**，为 CMD 提供强大的命令补全功能。
2. **Linux 工具链：**
    1. **uutils coreutils**: 提供 `rm`, `cp`, `mv` 等核心命令。
    2. **LSD**: 替代 `ls`，提供图标与色彩支持。
    3. **Bat**: 替代 `cat`，提供语法高亮。
    4. **Ripgrep(rg)** : 提供极速文本搜索。
    5. **btop**: 现代化系统资源监视器。
    6. **Procs**: 进阶进程管理工具。
    7. **PowerShell**: 实现了彩色增强版的 `free`、`uptime`、`df`、`du` 命令。
3. **视觉与主题：**
    1. **Oh-My-Posh**: 安装主题引擎并自动部署 `jandedobbeleer` 经典配置。
    2. **Meslo Nerd Font**: 透过 **Oh-My-Posh** 自动下载并安装适配图标的专用字体。
4. **配置同步：**
   1. 从 GitHub 云端拉取最新的 `coolcmd.lua` 与 `LS_COLORS` 数据。
   2. 自动清理旧缓存，触发首次启动的高性能解析。

## ⚙️ 配置文件

- `coolcmd.lua`: 核心大脑，处理智慧路由与热重载逻辑。
- `LS_COLORS`: 原始配色数据库。
- `LS_COLORS_FULL_CACHE`:  **「自动生成」** 避免重复计算（如果原始 `LS_COLORS` 有手动更新，请删除该文件以同步更新）。
- `LS_ICONS`: 原始图标数据库（du 命令使用）。
- `LS_ICONS_FULL_CACHE`:  **「自动生成」** 避免重复计算（如果原始 `LS_ICONS` 有手动更新，请删除该文件以同步更新）。
- `LANG_ENV.lua`: **「自动生成」** 存储侦测到的系统语言环境。如果想要设置为跟系统语言不同的环境语言，可以直接修改该配置文件。
- `COOL_TOOLS_CACHE.lua`: **「自动生成」** 存储工具侦测结果，消除 `where` 查询延迟。如果不喜欢某个工具的实现（比如 du，df），想要使用回退实现，可以直接将文件中的工具从 true 改为 false。


## 🧠 开发者笔记 (Developer Notes)

CoolCMD 在设计上绕过了许多 CMD 的原生限制：


- **环境变量长度突破**：通过 Lua 动态读取缓存并注入 `os.setenv`，解决了 `setx` 命令的 `1024` 字符限制，同时实现了 `8000+` 字符的智能截断，确保 `LS_COLORS` 既全又不崩溃。
- **进程管理宏逻辑**：
   1. 针对 `kill -9 <PID>`，我们设计了基于 `$T` 命令链和 `for` 循环的别名逻辑。
   2. 该逻辑会自动迭代所有参数并提取最后一个作为有效目标，从而实现对 Unix 信号参数的「语义忽略」。
   3. 使用 `@echo off` 隐藏中间件逻辑，保持输出界面整洁。
- **热重载机制**：输入 `cool` 即可调用内置 `CLINK_EXE` 执行 `clink set`，强制刷新脚本执行环境，无需重启窗口即可更新别名和配色。通过 `cool` 别名重新加载 `Clink` 跟使用 <kbd>ctrl</kbd>+<kbd>x</kbd>,<kbd>ctrl</kbd>+<kbd>r</kbd> 快捷键不同，如果更新的脚本有错误，使用快捷键重新加载 `Clink` 会导致个性提示符崩溃，而使用 `cool` 别名方式不会，它拒绝加载错误脚本，保持原来的环境不变。
- **静默安装**：使用了 `--source winget` 与 `autorun install -- -q`，尽量减少弹窗干扰。
- **清理自毁**：脚本执行完毕后会启动一个后台进程自我删除 ` (del "%~f0")`，保持用户下载目录整洁。
- **17ms 的秘密**：通过 `os.isfile` 和 `dofile` 预加载解析后的 `Lua` 缓存，避开了 `CMD` 频繁启动新进程的开销。
- **Doskey 避坑**：针对 `uptime`、`free`、`du`、`df` 的实现，我们巧妙避开了 `$t`、`$g`、`$b`、`$e`、`$f`、`$q` 等保留关键字，确保转义稳定。

## 🙏 特别致谢

- 感谢 trapd00r 提供的全量 LS_COLORS 数据库。
- 感谢 **AI 协作伙伴**：在漫长的 Debug 过程中，协助完成了复杂的 Lua 字符串清洗、多方案热重载测试以及 CMD 别名嵌套限制的规避。在解决「引号嵌套」、「换行符陷阱」、「别名递归」以及「17ms 性能极限」等问题上提供了关键的底层逻辑支持。

## ⚠️ 注意事项

安装完成后，请务必在 **Windows Terminal** 设置中手动将字体切换为 **「MesloLGM Nerd Font」**，否则图标无法正常显示。
