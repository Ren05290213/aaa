# 侧载构建说明（断食 → 灵动岛）

这份 fork 在 Fud AI 8.0 的基础上加了**断食的灵动岛 + 锁屏小组件**。

Windows 上没有 Xcode，所以用 GitHub Actions 的 macOS 机器编译出**未签名 IPA**，
再用爱思助手签名安装。

## 一、动了哪些代码

| 文件 | 作用 |
|---|---|
| `ios/calorietracker/Models/FastingActivityAttributes.swift` | 灵动岛的数据模型（开始时间、目标时长） |
| `ios/calorietracker/Services/FastingLiveActivity.swift` | 启动 / 更新 / 结束 Live Activity，7.5 小时自动换新卡 |
| `ios/FudAIWidgets/FastingActivityAttributes.swift` | 同上模型的副本（Widget 扩展独立编译） |
| `ios/FudAIWidgets/FastingLiveActivityWidget.swift` | 灵动岛三种形态 + 锁屏卡片 |
| `ios/FudAIWidgets/FastingWidget.swift` | 锁屏小组件：按进食窗口自动切换显示 |
| `ios/calorietracker/AppIntents/FastingScheduleIntent.swift` | 「Apply Fasting Schedule」意图，供快捷指令定时调用 |
| `ios/calorietracker/Models/EatingWindowStore.swift` | 后台读取进食窗口 |
| `ios/calorietracker/Info.plist` | 打开 `NSSupportsLiveActivities` |

倒计时由系统渲染（`Text(_, style: .timer)` / `.relative`），App 在后台甚至被杀掉也继续走。

## 二、为了能装进你的手机，改了签名相关的东西

1. **Bundle ID 全部改成 `com.fudai.sideload`**（含扩展、Watch、App Group）。
   原因：`com.apoorvdarshan.*` 这些 App ID 已经注册在作者的团队名下，别的团队注册不了。
   想换名字，全局替换 `com.fudai.sideload` 即可（App Group 是 `group.com.fudai.sideload`）。
2. **去掉了 iCloud / CloudKit 和关联域权限**，保留 App Group 和 HealthKit。

## 三、构建（只需点一次）

1. 在 GitHub 新建一个**空仓库**，把本目录推上去：
   ```bash
   git init && git add -A && git commit -m "fasting live activity"
   git remote add origin https://github.com/<你的账号>/fud-ai.git
   git push -u origin main
   ```
   `.gitignore` 已排除 1.2 GB 的动作帧图，实际约 40 MB。
2. 打开仓库 → **Actions** → **Build unsigned IPA** → **Run workflow**。
3. 等 20–40 分钟，产物在运行页底部 **Artifacts** → `FudAI-unsigned-ipa`。

> 前提：runner 必须装了 **Xcode 27**。Fud AI 用了 iOS 27 的 FoundationModels 图像接口，
> 低于 27 会在编译前直接失败并写明原因。

## 四、爱思助手签名安装

1. 解压得到的 `FudAI-unsigned.ipa`。
2. 爱思助手 → **IPA 签名** → 选你的付费证书 → bundle id 保持
   `com.fudai.sideload` 不要改（改了扩展就对不上）。
3. 安装。首次打开若提示「不受信任」，去 设置 → 通用 → VPN与设备管理 信任。

## 五、进食窗口（可随时改）

**设置 → Tracking & Notifications → 断食 → Eating Window**

- 开关打开后出现 `Window Opens` / `Window Closes` 两个时间选择器，默认 `08:00 – 16:00`。
- 支持跨午夜（例如 `20:00 – 04:00` 吃）。
- 改完立即生效，小组件会自己刷新。

## 六、锁屏小组件（全天显示，零点击）

小组件库里叫 **Fud AI Fasting**，支持锁屏圆形 / 矩形 / 单行，以及桌面小号。

- 窗口内显示 `Eating` 与倒计时，窗口外显示 `Fasting` 与倒计时。
- 手动开始的断食优先显示，手动断食结束后自动回到日程显示。
- 只做显示，**不会自动写断食历史**。

## 七、让灵动岛每天自动出现（快捷指令，零点击）

### 7.1 先设窗口

设置 → Tracking & Notifications → 断食 → Eating Window，例如 `08:00 – 16:00`。

### 7.2 建两条个人自动化

1. 打开「快捷指令」→ 底部「自动化」→ 右上「+」→「时间」。
2. 时间设 **16:00**，重复「每天」，**取消勾选「运行前询问」**，下一步。
3. 添加动作 → 搜索 **Fud AI** → 选 **Apply Fasting Schedule**。
4. 完成。再重复一次，时间设 **08:00**，动作选同一个。

同一个意图自己判断阶段：

- 16:00 跑：处于断食阶段 → 开始一次断食 → 点亮灵动岛，同时写断食历史
- 08:00 跑：处于进食窗口 → 结束这次断食 → 灵岛收起

### 7.3 改窗口时要同步改哪里

自动化是**按钟点触发**的，不知道你的窗口。改窗口就顺手把两条自动化的时间改掉。

不想操心的话，可以把自动化改成每小时跑一次：意图是幂等的（窗口内没有断食就什么都不做，
断食阶段已有断食也什么都不做），代价是每小时唤起一次 App 进程。

### 7.4 如果系统拒绝后台启动

苹果要求 Live Activity 由前台 App 创建。被拒时意图会发一条通知
**Fasting countdown is waiting**，断食本身照常开始，只是灵岛需要你点开 App 一次补上。

## 八、灵动岛 8 小时上限怎么绕

单张 Live Activity 在灵动岛最多活跃 8 小时：

1. 16:00 开始断食 → 灵动岛跑到 24:00
2. 24:00 之后点一下锁屏小组件（会打开 App）→ App 自动把旧卡片换新，再给 8 小时
3. 08:00 达标

## 九、已知限制

- **别用 iCloud 备份 / 恢复**：权限被去掉了，点「从 iCloud 恢复」会闪退。其他功能不受影响。
- 灵动岛只在 iPhone 14 Pro 及更新机型上出现；其他机型是锁屏卡片。
- 证书过期后 App 会打不开，需要重新签一次。
