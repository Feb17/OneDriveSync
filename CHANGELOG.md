# Changelog

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
