# AACompat — WeChat 液态玻璃 & ThemePro 兼容桥接

## 问题

`WeChatLiquidGlass.dylib`（液态玻璃）和 `libPineappleDylib.dylib`（ThemePro）
同时加载时，微信闪退或卡在地球页面。

**根因**：两个插件在 UIView/UIViewController 的生命周期方法上
（`setFrame:`、`layoutSubviews`、`addSubview:`、`viewWillAppear:` 等）
都安装了 Method Hook，各自的 hook 实现内部修改视图时触发对方 hook，
形成无限递归 → 栈溢出崩溃。

## 原理

AACompat 在 UIView/UIViewController 基类层面用 `_Thread_local` 计数器
检测重入。当同一个线程在 Hook 内部再次触发同一个或另一个 Hook 时
（计数器 > 1），直接走真正的原始方法实现，阻断递归循环。

```
正常路径: LiquidGlass → ThemePro → AACompat(守卫) → 原始方法
重入路径: LiquidGlass → ThemePro → AACompat(检测重入→跳过) → 原始方法
```

## 编译

需要 [theos](https://github.com/theos/theos) 开发环境：

```bash
# 设置 THEOS 环境变量
export THEOS=/opt/theos

# 编译
cd CompatibilityBridge
make package

# 安装到设备（通过 SSH）
make install
```

编译产物：`packages/com.aa.compat_1.0.0_iphoneos-arm64.deb`

## 安装

将编译好的 deb 安装到越狱 iPhone：

```bash
# 方式 1: 通过 theos
make install

# 方式 2: 手动安装
scp packages/com.aa.compat_1.0.0_iphoneos-arm64.deb root@<device-ip>:/tmp/
ssh root@<device-ip> "dpkg -i /tmp/com.aa.compat_1.0.0_iphoneos-arm64.deb && killall -9 WeChat"
```

**关键**：插件文件名 `AACompat.dylib` 在字母顺序上排在
`libPineappleDylib.dylib` 和 `WeChatLiquidGlass.dylib` 之前，
确保最先加载（innermost hook 位置）。

## 诊断

运行诊断脚本查看冲突详情：

```bash
python diagnose.py
```

## 注意事项

1. **这不是 100% 完美的方案** — 两个插件的视觉修改仍可能互相覆盖
   （例如 TabBar 上 ThemePro 的背景图和 LiquidGlass 的毛玻璃叠加），
   但至少不会崩溃。

2. **如果仍有崩溃** — 可能是两个插件在某个未被 guard 的方法上冲突。
   检查 `/var/mobile/Library/Logs/CrashReporter/` 下的崩溃日志，
   把调用栈发过来补充 guard。

3. **性能影响** — 每个被 guard 的方法增加了一次 TLS 变量访问和一个分支判断，
   开销极小（纳秒级），不会对微信流畅度产生可感知的影响。
