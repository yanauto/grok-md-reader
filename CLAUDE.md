# grok-md-reader 项目宪法

> **v5 分家铁律**：项目实况在 projects.db（`vitals proj`）；叙事 ADR 在 `docs/decisions/`；**可复跑操作**在 `docs/代码地图.md` 入口 + `docs/工程手册.md` + `docs/playbooks/`；工程日记 `docs/sessions/YYYY-MM-DD.md`（**仅日层，无周/月**）。SessionStart 注入实况；其它 shell 工具先 `vitals proj now grok-md-reader --pretty`；无 shell 声明「实况不可用」，**md 不回退为实况源**。
>
> **宪法不限字符/条数**。禁止写入的是**实况数字与 WIP**（归库），不是篇幅。

## 项目定位

Grok CLI 的 macOS Markdown 伴生阅读器：**装一次 → 工具行路径 Cmd+点击即可打开**（`.md` → MdReader，PDF → Preview 等）。`/open` `/preview` 仅为裸文本路径兜底。

## 记忆分层（v5 · 禁止自创第五套落点）

| 层 | 路径 | 回答什么 |
|---|---|---|
| **宪法** | 本文件 | 铁律、去哪找、开场读什么 |
| **实况** | `vitals proj now/log` | 现在卡在哪、近事件摘要 |
| **工程地图** | `docs/代码地图.md` | 模块 / 放哪 / 运行时 / **操作入口** |
| **工程手册** | `docs/工程手册.md` | 接口、数据口径、环境、坑 |
| **剧本** | `docs/playbooks/` | 逐步可复跑操作 |
| **决策 why** | `docs/decisions/` | 为什么 |
| **日记** | `docs/sessions/YYYY-MM-DD.md` | 当天多场流水（仅日层） |
| **交接冷区** | `docs/handoffs/` | 交接原文；**默认不读** |
| **跨项目 how** | `vitals kb` | 多项目通用 |
| **密钥** | `vitals vault` | 钥匙（正文只写指针；本项目通常无密钥） |

与个人库 my **分叉**：工程不做周记/月记。

## 开场阅读顺序（硬）

1. 本宪法 → 关键路径  
2. hook 注入的 proj 实况；缺则 `vitals proj now grok-md-reader --pretty`  
3. 动代码前 → `@docs/代码地图.md`  
4. 动接口/部署/联调/查库前 → `@docs/工程手册.md`；逐步操作 → `@docs/playbooks/`  
5. **默认不读** `docs/handoffs/`、`.claude/sessions/raw/`、`docs/progress.md`（若存在则冻结非源）

## 项目铁律（本项目独有）

> 通用工程准则已在 `~/.claude/Claude.md` 全局定义。这里只放本项目独有的约定。  
> **宪法与铁律不设条数/字符上限（v5）**。失效条目与用户确认后退役并 `vitals proj log grok-md-reader "[CONVENTION] 退役铁律: …"`。禁止把 WIP/进度数字写进本段。

1. **产品主路径 = 即装即点**（ADR-0002）：`./install.sh` 写入 macOS Launch Services 默认 App；Cmd+点击走系统 `open`。**不**把 skill / Agent 纪律当主体验；**不**承诺聊天气泡内裸路径可点（Grok TUI 限制）。
2. **`/open` `/preview` / `open_path.py` = 兜底**：仅裸文本路径、无 OSC-8 终端、脚本调用。叙事与文档不得再写成「主靠 Agent 打开」。
3. **打开策略唯一源**：`plugins/md-reader/config/readers.example.json`（用户覆盖 `~/.grok/plugin-data/user/md-reader/readers.json`）。`by_extension` + `apps.bundle_id` + `os_defaults.apply_extensions`；Cmd+click 与 `/open` **同源**，禁止两套映射各写各的。
4. **文档打开路由器、不自研 Office/PDF 窗**（ADR-0001）：md 走 MdReader；pdf/office 交给本机 App；未知类型 `default: system`。
5. **安全边界**：只打开本地已存在文件；拒绝 URL；不上传文件内容；渲染离线（marked/hljs 随包）；hook 只记路径可关（`hook_disabled` / `MD_READER_HOOK_DISABLE`）。
6. **侧信道 hook 可靠安装路径**：插件包内 `hooks/hooks.json` headless 实测未必注册；**以** `scripts/install_sidechannel_hook.sh` → `~/.grok/hooks/md-reader-sidechannel.json` **为准**（见 TECH-PLAN / 工程手册）。
7. **不做**：劫持 Grok 点击；hook 画 OSC-8 当主路径（P1 已证死）；终端内 glow 式渲染；本期跨 CLI / 远程 GUI。
8. **改默认 App 有侵入**：`install.sh` 默认会改 `os_defaults.apply_extensions` 所列类型；需跳过用 `--no-set-defaults`。`.txt`/`.html` **故意不进** OS 默认（过宽）。

## 工程化栈

- **语言**：Python 3（插件脚本 / 测试）· Swift（MdReader viewer，`swiftc`，无 Tauri/Rust）
- **测试**：`python3 -m pytest tests/ -q`（`open_path` dry-run · `apply_os_defaults` plan/doctor · `on_md_write`）
- **入口**：`./install.sh`（全量）；`--doctor` / `--set-defaults` / `--no-set-defaults`
- **产物**：`~/Applications/MdReader.app`（bundle id `com.yanauto.mdreader`，scheme `md-reader://`）
- **插件链接**：`~/.grok/plugins/md-reader` → 仓库 `plugins/md-reader`
- **代码怎么组织 / 加新东西放哪** → `@docs/代码地图.md`

## 收尾协议（确认闸门）

**不得自行启动收尾。** 仅：① 用户 `/wrap-up` ② 口头结束短语经 hook 检测后你问「要走 /wrap-up 吗？」得肯定才执行。

误听一次的伤害上限 = 多问一句。纯告别无保存语义 → 不问。

## 开场协议

1. 复述「下一步」  
2. 等用户确认再动手  
3. 需求冲突则先更新 `vitals proj now`  
4. hook 失败 → 手动 `vitals proj now grok-md-reader --pretty`，别凭印象  

不替用户说话；指不出原句则重问。

## 压缩后恢复协议

1. `vitals proj now grok-md-reader --pretty` + `vitals proj recent --project grok-md-reader --days 7 --pretty`  
2. 决策 → `docs/decisions/`  
3. 操作 → 地图入口 / 手册 / playbooks  
4. 回报用户后继续  

无证据不宣布 context 异常。宁可多查一次库，也不要凭印象继续。

## 工具结果纪律（防编造）

- 当场可见输出才可报  
- 字段矛盾停下重取  
- 慢通道：单次往返 + 哨兵 + timeout  

## 决策 / 铁律 / 操作晋升

- 决策：wrap-up 清单确认后 ADR  
- 铁律：用户明确「本项目必须/禁止…」可当场问是否写入本文件  
- **操作晋升（硬）**：首次打通或修正可复跑路径 → 必须更新地图入口和/或 playbook 和/或工程手册  

## 命令速查

| 命令 | 用途 |
|---|---|
| `/wrap-up` | proj now + log + 操作晋升 + 日文件 + 可选 ADR/kb |
| `/decision` | 单条 ADR + 指针事件 |

`/checkpoint` 已废止（v5）。中段留痕：当场 `vitals proj now` 或写手册/剧本。

## 关键路径

| 想知道什么 | 去哪 |
|---|---|
| 进度 / 下一步 | `vitals proj now grok-md-reader --pretty` |
| 近事件 | `vitals proj recent --project grok-md-reader --days 7 --pretty` |
| 代码 / 操作入口 | `@docs/代码地图.md` |
| 接口 · 数据 · 环境 · 坑 | `@docs/工程手册.md` |
| 逐步部署/装机/自检 | `@docs/playbooks/`（首装见 `install-and-click.md`） |
| 历史决策 | `docs/decisions/`（ADR-0001 路由 · ADR-0002 OS 默认） |
| 工程日记 | `docs/sessions/YYYY-MM-DD.md` |
| 交接（冷） | `docs/handoffs/`（默认不读） |
| **怎么做没做过的跨项目事** | 先 `vitals kb find <关键词>`，命中 `kb show <id>`；池里没有、摸出来了 → wrap-up 时经确认 `kb add`（`--project grok-md-reader`；密钥不入池，写 vault 指针） |
| 密钥 / token | `vitals vault list`（无值）；ask 级**本轮明确同意**后 `vault get <名> --approved`。本项目运行时**无**服务端密钥依赖 |
| 跨项目 how（短） | `vitals kb find …` |
| raw | `.claude/sessions/raw/` |
| 方向/探针结论 | `docs/TECH-PLAN.md` · `docs/ARCHITECTURE.md` · `docs/ROADMAP.md` |
| 用户向说明 | 根 `README.md` / `README.zh-CN.md` |

> `vitals proj` **读**命令全部只读、无游标副作用，随时可跑。写入发生在 `/wrap-up`、`/decision` 与用户明确要求的 `proj now --set`。

## 项目状态

- 记忆框架：**v5**（升级 2026-07-27）
- 初始化日期：2026-07-26
- 当前阶段与下一步：**仅** `vitals proj now grok-md-reader`（实况不进本文件）
