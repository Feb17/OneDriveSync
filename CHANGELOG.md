# Changelog

## v1.0.2 - 2026-02-18

### 发布说明
- `Connect OneDrive` 改为一键浏览器鉴权，不再要求用户进入 Terminal 手动执行 `rclone config`。
- 新增版本包含 OneDrive 连接流程体验升级与发布链路修复。

### 关键改动清单
- OneDrive 连接体验：
  - 使用 `rclone config create/update --non-interactive` 自动完成配置流程
  - 自动处理配置状态机与默认选项，浏览器完成微软 OAuth 即可
  - 连接流程失败时自动清理临时 remote，避免残留脏配置
- 设置页交互调整：
  - 连接提示从“回到 Terminal 完成配置”更新为“浏览器登录授权”
  - 账户连接成功后直接进入命名步骤，移除冗余轮询等待
- 更新检查修复：
  - GitHub Release API 地址切换为 `Feb17/OneDriveSync`
  - `User-Agent` 改为按当前 app 版本动态生成

### 验收结果摘要
- 已通过：Debug 构建、版本号提升、发布前代码编译检查。
- 待线上验证：真实微软账号 OAuth 全链路与 release 拉取更新提示。

## v1.0.1 - 2026-02-18

### 发布说明
- `OneDriveSync` 保留菜单栏应用原有交互与同步能力。
- 云盘提供方实现统一为 OneDrive，通用功能路径保持不变。

### 关键改动清单
- 工程与应用标识替换：
  - 统一为 `OneDriveSync`
  - Target、Product、App 名称、Bundle 相关资源同步替换
- OneDrive Provider 适配：
  - `rclone` remote 类型统一为 `onedrive`
  - 账户发现逻辑改为仅显示 `onedrive` remote
  - 新增账户改为交互式 `rclone config`，兼容 OneDrive 的 drive 选择流程
- 账户管理一致性：
  - 保留账户重命名、删除能力
  - 重命名实现改为直接更新 `rclone.conf` section 名称并做回滚校验，避免 OneDrive 二次 OAuth 卡住
- 同步能力保持一致：
  - 保留 `sync/copy/progress/cancel`
  - 保留单目录同步、`Sync All`、状态更新、错误汇总、通知策略
- 定时与启动能力保持一致：
  - 保留 15m/30m/1h/每日 定时触发
  - 保留开机启动配置与菜单栏入口
- 数据与配置命名空间：
  - `UserDefaults` key 使用 `OneDriveSync.Folders`、`OneDriveSync.Settings`
  - 不迁移旧 Google 配置
- 链接与文案替换：
  - `Open in OneDrive` 菜单动作与网页回退行为已对齐
  - 网页回退地址改为 `https://onedrive.live.com`
- 更新检查：
  - 保留 GitHub latest release 检查能力
  - 仓库切换到 `saihgupr/OneDriveSync`
- 打包能力保持：
  - 保留内置 `rclone` 拷贝与路径探测逻辑，Debug/Release 均可运行

### 验收结果摘要
- 已通过：构建、OneDrive 登录后远端读写、同步、进度与取消、链接打开回退、菜单栏应用可启动。
- 手动验收已完成：菜单栏入口、目录管理、同步交互、通知/定时链路与旧版一致。
