# 鸿蒙客户端的 Core 依赖

开发机首次构建前运行 `gh auth login -h github.com -s read:packages`。已登录时运行
`gh auth refresh -h github.com -s read:packages`。账号需有组织 Core 包的 Read 权限。
IDE 会读取 GitHub CLI 已保存的登录。也可通过环境变量 `GHCR_USERNAME` 和
`GHCR_TOKEN` 提供本人具有 `read:packages` 的 classic PAT。

在 DevEco Studio 运行或使用 Hvigor 构建 HAP 时，`syncDeadlinerCoreKmp` 会调用 Python 3，
安装 `core-package.lock.json` 锁定的 arm64 动态库。首次下载需要访问 ghcr.io，
已校验的文件缓存在 `.deadliner-core/packages/`。升级时同步更新版本和 OCI manifest SHA-256。

需要调试 Core 源码时，设置 `DEADLINER_CORE_SOURCE=local` 和
`DEADLINER_CORE_DIR=/path/to/DeadlinerCore`，再按原流程构建。
