#!/usr/bin/env python3
"""
诊断脚本：分析两个 dylib 之间的 hook 冲突点。
运行方式: python diagnose.py <path_to_libPineappleDylib> <path_to_WeChatLiquidGlass>

这个脚本在你无法编译兼容桥接插件的情况下，至少让你看清冲突全貌。
"""

import sys
import re
import os

# ThemePro 已知 hook 的方法（从字符串分析获取）
THEMEPRO_HOOKS = {
    # 类名 -> [方法列表]
    "MMTabBar": [
        "_setBackgroundNeedsUpdate",
        "initWithFrame:",
        "setFrame:",
    ],
    "MMTabBarBaseViewController": ["viewDidLoad"],
    "MainTabBarViewController": ["viewDidLoad"],
    "NewMainFrameViewController": [
        "viewDidLoad",
        "viewWillAppear:",
        "viewDidAppear:",
        "scrollViewDidScroll:",
    ],
    "NewMainFrameCell": ["setBackgroundColor:"],
    "BaseMsgContentViewController": ["viewDidLoad"],
    "ContactsViewController": ["viewWillAppear:"],
    "NewSettingViewController": ["viewWillAppear:"],
    "FindFriendEntryViewController": ["viewWillAppear:"],
    "MoreViewController": ["viewDidLoad", "viewDidAppear:"],
    "LiteAppViewController": ["viewDidLoad"],
    "MMMsgContentNavBar": ["layoutSubviews"],
    "MMNewMsgContentNavBar": ["layoutSubviews"],
    "MMHeadImageView": ["layoutSubviews"],
    "MMGrowTextView": ["setBackgroundImage:"],
    "MFBannerBtn": ["layoutSubviews"],
    "FakeNavigationBar": ["layoutSubviews"],
    "CellSourceView": ["layoutSubviews"],
    "KindaUIView": ["layoutSubviews"],
    "UITableViewCell": ["layoutSubviews"],
    "FileDetailViewController": ["SetDownloadHide"],
    "WCMktCardHomeViewControllerV2": ["tableView:didSelectRowAtIndexPath:"],
    "UINavigationController": ["pushViewController:animated:"],
}

# LiquidGlass 已知 hook 的 UIKit 层级方法
LIQUIDGLASS_UIKIT_HOOKS = [
    # UIView
    "setFrame:",
    "layoutSubviews",
    "setBackgroundColor:",
    "addSubview:",
    "didAddSubview:",
    "didMoveToSuperview",
    "didMoveToWindow",
    "setHidden:",
    # UIViewController
    "viewWillAppear:",
    "viewDidAppear:",
    "viewDidLoad",
    "viewDidLayoutSubviews",
    "viewWillLayoutSubviews",
    # UIScrollView
    "setContentOffset:",
    "setContentInset:",
    "scrollViewDidScroll:",
    # UINavigationBar
    "setBackgroundImage:forBarMetrics:",
    # UITabBar
    "setBackgroundImage:",
]

def extract_strings(filepath):
    """从二进制文件中提取可读字符串"""
    with open(filepath, "rb") as f:
        data = f.read()
    # ASCII strings >= 8 chars
    strings = set()
    current = []
    for byte in data:
        if 0x20 <= byte < 0x7F:
            current.append(chr(byte))
        else:
            if len(current) >= 8:
                strings.add("".join(current))
            current = []
    if len(current) >= 8:
        strings.add("".join(current))
    return strings


def analyze_file(filepath, label):
    """分析一个 dylib 文件"""
    if not os.path.exists(filepath):
        print(f"  [错误] 文件不存在: {filepath}")
        return set(), set()

    strings = extract_strings(filepath)
    print(f"  [{label}] 提取到 {len(strings):,} 个唯一字符串")

    # 查找 WeChat 类相关字符串
    wc_classes = set()
    wc_methods = set()

    for s in strings:
        # 匹配 ObjC hook 方法: $ClassName_method$
        m = re.search(r'\$(\w+?)_(\w+?)\$_?(method|super)', s)
        if m:
            wc_classes.add(m.group(1))
            wc_methods.add(f"{m.group(1)}.{m.group(2)}")

    print(f"  [{label}] 发现 {len(wc_classes)} 个被 hook 的类")
    print(f"  [{label}] 发现 {len(wc_methods)} 个被 hook 的方法")

    return wc_classes, wc_methods


def main():
    print("=" * 60)
    print("WeChat 液态玻璃 & ThemePro 冲突诊断")
    print("=" * 60)

    themepro_path = sys.argv[1] if len(sys.argv) > 1 else None
    liquidglass_path = sys.argv[2] if len(sys.argv) > 2 else None

    # 默认路径
    if not themepro_path:
        themepro_path = os.path.join(
            os.path.dirname(__file__),
            "..",
            "deb_extracted",
            "var", "jb", "usr", "lib", "TweakInject",
            "libPineappleDylib.dylib",
        )
    if not liquidglass_path:
        liquidglass_path = os.path.join(
            os.path.dirname(__file__), "..", "WeChatLiquidGlass.dylib"
        )

    print("\n[1] 分析 ThemePro (libPineappleDylib)...")
    tp_classes, tp_methods = analyze_file(themepro_path, "ThemePro")

    print("\n[2] 分析液态玻璃 (WeChatLiquidGlass)...")
    lg_classes, lg_methods = analyze_file(liquidglass_path, "LiquidGlass")

    print("\n" + "=" * 60)
    print("[3] 冲突分析")
    print("=" * 60)

    # 从 ThemePro 已知 hook 和 LiquidGlass UIKit hook 中分析冲突
    print("\n--- UIKit 生命周期方法双重 Hook 冲突 ---")
    print("以下方法被两个插件同时 hook（在不同类上）：")

    for tp_class, tp_methods_list in THEMEPRO_HOOKS.items():
        for tp_method in tp_methods_list:
            # 提取基础方法名（去掉参数标签）
            base_method = tp_method.split(":")[0]
            for lg_method in LIQUIDGLASS_UIKIT_HOOKS:
                lg_base = lg_method.split(":")[0]
                if base_method == lg_base:
                    print(f"  ⚠️  {tp_class}.{tp_method}  ⇄  UIView.{lg_method}")
                    break

    print("\n--- 具体冲突场景 ---")
    conflicts = [
        ("MMTabBar.setFrame:", "UIView.setFrame:",
         "ThemePro 调整 TabBar frame → 触发 LiquidGlass UIView 层 frame hook → 递归"),
        ("MMTabBar.initWithFrame:", "UIView.setFrame:",
         "TabBar 初始化时两边同时介入 → frame 反复修改"),
        ("NewMainFrameCell.setBackgroundColor:", "UIView.setBackgroundColor:",
         "主框架 Cell 颜色设置 → 触发 LiquidGlass 颜色处理 → 可能触发布局"),
        ("各种类.layoutSubviews", "UIView.layoutSubviews",
         "layoutSubviews 是冲突最密集的方法 → 两边互相触发可能性最高"),
        ("各种类.viewDidLoad", "UIViewController.viewDidLoad",
         "控制器初始化时两边都添加子视图 → addSubview 链式触发"),
        ("各种类.viewWillAppear:", "UIViewController.viewWillAppear:",
         "页面即将显示时两边都做视觉调整 → 互相触发"),
    ]
    for a, b, desc in conflicts:
        print(f"  🔴 {a}")
        print(f"     ⇄ {b}")
        print(f"     → {desc}")
        print()

    print("=" * 60)
    print("[4] 解决方案")
    print("=" * 60)
    print("""
推荐方案：安装 AACompat 兼容桥接插件（本目录）
  - 使用 theos 编译: make package install
  - 该插件在 UIView/UIViewController 基类层面添加重入保护
  - 阻断两个插件之间的无限递归

备选方案：禁用液态玻璃的部分功能（治标不治本）
  - 在 WeChat 启动前设置 NSUserDefaults:
    defaults write com.tencent.xin wclg_liquid_glass_enabled -bool NO
    但这可能不会阻止 hook 安装，只是让 hook 内逻辑跳过

临时方案：二选一
  - 只保留其中一个插件
  - 同时使用时，在 WeChat 冷启动时可能仍会偶发崩溃
""")

    print("诊断完成。")


if __name__ == "__main__":
    main()
