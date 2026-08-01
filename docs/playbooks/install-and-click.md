# 剧本：首次安装与 Cmd+点击验收

## 前置条件

- macOS（Apple Silicon / Intel 均可；需能跑 `swiftc`）
- 已装：Python 3、Xcode Command Line Tools（`xcode-select --install`）、Grok CLI
- 仓库已 clone，cwd = 仓库根

## 步骤（可复制命令）

```bash
cd /path/to/grok-md-reader

# 1. 全量安装：App + 插件链 + 侧信道 hook + OS 默认 + doctor
./install.sh

# 若不想改系统默认打开方式：
# ./install.sh --no-set-defaults

# 2. 随时自检
./install.sh --doctor

# 3. 单测（可选）
python3 -m pytest tests/ -q
```

自定义映射后再写默认：

```bash
mkdir -p ~/.grok/plugin-data/user/md-reader
cp plugins/md-reader/config/readers.example.json \
  ~/.grok/plugin-data/user/md-reader/readers.json
# 编辑 readers.json 后：
./install.sh --set-defaults
```

## 验收

1. **doctor**：MdReader 路径/bundle 可见；`.md` 默认指向 `com.yanauto.mdreader`（或你配置的 app）；关键扩展无报错。  
2. **Grok 工具行**：让 agent `write` 一个 `.md`，在工具行路径上 **Cmd+点击** → 应打开 **MdReader** 并渲染。  
3. **PDF（可选）**：工具行 Cmd+点击 `.pdf` → Preview（或你映射的 App）。  
4. **兜底**：在聊天里发纯文本路径时用 `/open /绝对路径` 应同样打开。  
5. **插件**：`~/.grok/plugins/md-reader` 为指向本仓库的符号链接。

## 回滚 / 失败时

| 现象 | 处理 |
|---|---|
| `swiftc` 找不到 | `xcode-select --install` |
| doctor 报 MdReader 缺失 | `./viewer/scripts/build_app.sh --install` 后重跑 `--doctor` |
| Cmd+点击仍进错 App | `./install.sh --set-defaults`；确认用户 `readers.json` 未覆盖成意外映射 |
| 不想保留默认 App 改动 | 在「系统设置 → 桌面与程序坞 / 文件关联」改回，或对应用户习惯 App 再 `--set-defaults` 指回去 |
| hook 无 history | 确认跑过 install 的侧信道步；查 `~/.grok/hooks/md-reader-sidechannel.json`；无 `hook_disabled` |
| 聊天路径点不了 | **预期**（TUI）；用 `/open`，不是安装失败 |

## 密钥指针（无正文）

本路径**无** vault 密钥。无需 `vitals vault`。
