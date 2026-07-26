# MdReader viewer

Grok CLI 伴生 Markdown 渲染窗。macOS · Swift · WKWebView · 离线 marked + highlight.js · 热刷新 · History。

## URL scheme

```text
md-reader://open?path=/absolute/path/to/file.md
```

也可：

```bash
open -a MdReader /absolute/path/to/file.md
```

## Build / install

```bash
./viewer/scripts/build_app.sh          # → viewer/dist/MdReader.app
./viewer/scripts/build_app.sh --install  # → ~/Applications/MdReader.app + 注册 scheme
```

依赖：Xcode CLT / `swiftc`（本机已有即可，无需 Tauri/Rust）。

## 资源

`Resources/` 内为构建时拷贝的离线 JS/CSS（运行时无网络）。
