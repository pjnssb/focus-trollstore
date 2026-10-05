# 专注（Focus）

一个类似 Forest 的 iOS 专注白名单 App，面向 TrollStore 环境，使用 Apple 的 **FamilyControls + ManagedSettings + DeviceActivity**。

专注开始后，除白名单里的 App 外，其他可屏蔽的 App 都会被系统盾牌拦住；计时结束或手动点“放弃专注”后自动解除。

## 功能

- 单次专注计时：15 / 25 / 45 / 60 / 90 分钟，或 5–180 分钟自定义。
- 使用系统 `FamilyActivityPicker` 选择白名单 App。
- 通过 `ManagedSettingsStore` 的 `.all(except:)` 屏蔽非白名单 App。
- 通过 `DeviceActivityMonitor` 扩展在 App 后台或被强杀后，计时结束仍能自动解除屏蔽。
- 自定义盾牌文案：“专注中 / 完成计时后才能使用该 App”。
- 不包含树苗、花园、统计、通知、暂停、网页/分类屏蔽。

## 环境要求

- 目标设备：iOS 16.0–17.0，且已安装 TrollStore。
- 构建：macOS + Xcode 26.6 + XcodeGen + ldid，或直接使用 GitHub Actions。
- 不需要 Apple Developer 账号，因为最终 IPA 使用 ldid 注入 entitlements，并通过 TrollStore 安装。

## 快速开始

### 方式一：GitHub Actions（推荐）

1. 把仓库上传到 GitHub。
2. 进入 **Actions** → **Build TrollStore IPA** → **Run workflow**。
3. 构建完成后，在该 workflow 的 **Artifacts** 中下载 `Focus-TrollStore-IPA`。
4. 解压得到 `Focus.ipa`，用 TrollStore 打开安装。

如果要发布版本，打一个 `v*` tag，例如：

```bash
git tag v1.0.0
git push origin v1.0.0
```

workflow 会自动创建 GitHub Release，并附上 `Focus.ipa`。

### 方式二：本地 macOS 构建

```bash
brew install xcodegen ldid
chmod +x scripts/build-ipa.sh
./scripts/build-ipa.sh
```

构建产物是仓库根目录下的 `Focus.ipa`。把它传到 iPhone，用 TrollStore 打开安装。

## 首次使用

1. 打开 App，按提示授权 Screen Time 访问。
2. 点“选择允许的 App”，在白名单里勾选专注期间允许使用的 App。「专注」和「TrollStore」会自动放行，不需要手动添加。
3. 选择专注时长。
4. 点“开始专注”。
5. 打开非白名单 App 时会出现盾牌；白名单 App 不受影响。
6. 盾牌上可以点“本 App 用 5 分钟”：只临时放行当前 App，累计使用满 5 分钟后重新上盾。
7. 计时结束自动解除；也可以回到 App 点“放弃专注”立即解除。

## 工作原理

- `FamilyControls` 负责申请 Screen Time 授权，并提供系统级 App 选择器。
- `ManagedSettings` 负责写入盾牌规则。白名单模式使用：

  ```swift
  store.shield.applicationCategories = .all(except: whitelist.applicationTokens)
  ```

- `DeviceActivity` 负责在后台按计划触发结束事件。
- `DeviceActivityMonitor` 扩展在 `intervalDidEnd` 时清空盾牌，因此主 App 被切后台或被强杀后，计时结束仍能解除屏蔽。
- 主 App 与两个扩展通过 App Group `group.com.example.Focus` 共享 session 状态。

## 项目结构

```text
.
├── FocusApp/                         # 主 App 源码
│   ├── FocusApp.swift
│   ├── ContentView.swift
│   ├── FocusStore.swift
│   └── Views/
├── Shared/                           # 主 App 与扩展共享的模型和存储
├── Extensions/
│   ├── DeviceActivityMonitor/        # 后台计时结束解禁
│   ├── ShieldConfiguration/          # 自定义盾牌文案
│   └── ShieldAction/                 # 本 App 用 5 分钟按钮
├── scripts/build-ipa.sh              # 构建 + ldid 签名 + 打包 IPA
├── .github/workflows/                # GitHub Actions 构建流程
└── project.yml                       # XcodeGen 工程定义
```

## 已知限制

- **Always Allowed App 不会被拦截**：iOS 设置 → Screen Time → Always Allowed 里的 App 会绕过第三方盾牌，这是系统行为。
- **同一设备通常只能有一个第三方 App 持有 FamilyControls 授权**：如果设备上已有其他 Screen Time 类 App，需要先解除它的授权。
- **后台解禁是分钟级**：`DeviceActivitySchedule` 使用小时/分钟，后台解禁可能在结束分钟触发，最多延迟约 59 秒；前台计时仍精确到秒。
- **只支持 App 白名单**：`FamilyActivityPicker` 里选中的分类和网页在首版会被忽略。
- **后台安全网是 24 小时**：App 会向系统申请一个 24 小时的 DeviceActivity 窗口作为安全网，实际时长由 App 内计时器控制；如果 App 被强杀，屏蔽会保留到你重新打开 App 或 24 小时窗口结束。
- **本 App 用 5 分钟**：只临时放行当前被拦的 App，其他 App 继续屏蔽；累计使用满 5 分钟后重新上盾。
- **「专注」和「TrollStore」会自动放行**：App 会按 bundle id 自动把「专注」和「TrollStore」加入例外列表。
- **只支持单次专注**：没有暂停/恢复、循环番茄钟、树苗、花园、统计、通知。
- **TrollStore 版本限制**：TrollStore 目前支持 iOS 14.0 beta 2–16.6.1、16.7 RC、17.0；iOS 17.0.1 及以上不支持。
- **需要真机测试**：Screen Time API 在模拟器上不能完整工作。

## 常见问题

### 授权失败或盾牌不生效

1. 确认设备上安装的是通过本项目构建的 IPA，而不是 Xcode 直接安装的调试包。
2. 检查 `Focus.ipa` 中主 App 和两个扩展的二进制是否都带有 `com.apple.developer.family-controls`：

   ```bash
   codesign -d --entitlements :- Payload/Focus.app/Focus
   codesign -d --entitlements :- Payload/Focus.app/PlugIns/DeviceActivityMonitor.appex/DeviceActivityMonitor
   codesign -d --entitlements :- Payload/Focus.app/PlugIns/ShieldConfiguration.appex/ShieldConfiguration
   ```

3. 检查三个 target 是否都使用同一个 App Group：`group.com.example.Focus`。

### 启动设备活动监控时报 application-identifier 错误

- 确认主 App 和两个扩展的 entitlements 都包含：
  - `application-identifier` = `ABCDE12345.<对应 bundle id>`
  - `com.apple.developer.team-identifier` = `ABCDE12345`
- 如果仍然报错，可以把三个 entitlements 文件里的 `ABCDE12345` 统一换成另一个 10 位 Team ID，再重新构建。

### 后台计时结束没有解除

- 确认 `DeviceActivityMonitor.appex` 已经嵌入到 `Focus.app/PlugIns/`。
- 确认该扩展的 entitlements 包含 `com.apple.developer.family-controls`。
- 尝试用 1 分钟会话测试；如果仍然不触发，请查看 GitHub Actions 构建日志和 Xcode 设备日志。

### 白名单 App 也被拦截

- 重新打开白名单选择器，确认选中的是 App，而不是分类或网页。
- 如果希望允许某些 App，确认白名单里至少有一个 App；选择 0 个 App 会屏蔽所有可屏蔽的 App。
- 某些系统 App 可能无法被第三方盾牌精确控制，这属于系统限制。

### 主 App 自身被盾牌拦住

理论上主 App 不应该被自己设置的盾牌拦住。如果测试时发现“专注”App 也打不开，说明当前系统把主 App 纳入了 `.all(except:)` 的范围。解决办法是增加一个最小 `ShieldAction` 扩展，在盾牌上提供“结束专注”按钮，通过 App Group 写入结束请求，主 App 下次启动时读取并清理盾牌。

## 修改 Bundle ID 和 App Group

默认值：

- Bundle ID：`com.example.Focus`
- App Group：`group.com.example.Focus`

修改时需要同步更新：

1. `project.yml` 中三个 target 的 `PRODUCT_BUNDLE_IDENTIFIER`。
2. `FocusApp/FocusApp.entitlements`、`Extensions/DeviceActivityMonitor/DeviceActivityMonitor.entitlements`、`Extensions/ShieldConfiguration/ShieldConfiguration.entitlements` 里的 App Group。
3. `Shared/SharedDefaults.swift` 里的 `appGroupID`。

## 免责声明

本项目仅用于个人专注和自控。请勿用于监控他人设备、绕过他人授权或任何非法用途。
