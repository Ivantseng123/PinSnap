# 自訂快捷鍵設定 - 設計文件

## 1. 功能概述

在 PinSnap 選單列 App 中新增設定視窗，讓使用者能自訂截圖快捷鍵。採用類似 macOS 系統設定的快捷鍵錄製方式。

## 2. 使用者流程

1. 使用者點擊選單列 Icon
2. 點擊「設定...」選項
3. 設定視窗開啟，顯示目前快捷鍵
4. 使用者點擊「錄製快捷鍵」按鈕
5. 按下想要設定的按鍵組合
6. 系統驗證按鍵組合是否衝突
7. 儲存設定並立即生效

## 3. UI/UX 設計

### 3.1 選單列選項

在現有選單中新增：
```
[設定...]
```

### 3.2 設定視窗

- **視窗大小**：400 x 200 points（固定）
- **視窗標題**：PinSnap 設定
- **布局**：

```
┌────────────────────────────────────────┐
│           PinSnap 設定                 │
├────────────────────────────────────────┤
│                                        │
│  截圖快捷鍵                            │
│  ┌──────────────────────┬─────────┐   │
│  │ Cmd + Shift + P      │ 錄�製   │   │
│  └──────────────────────┴─────────┘   │
│                                        │
│  [儲存]  [取消]                        │
│                                        │
└────────────────────────────────────────┘
```

### 3.3 錄製狀態

- 按鈕文字變為「按下快捷鍵...」
- 接收鍵盤事件（Command、Option、Control、Shift + 其他鍵）
- 按下 Escape 取消錄製

## 4. 技術設計

### 4.1 儲存機制

使用 `UserDefaults` 儲存：
- `hotkey_keyCode`: Int - 按鍵代碼
- `hotkey_modifiers`: Int - 修飾鍵標誌

### 4.2 架構

```
AppDelegate.swift
├── setupMenuBar() - 新增「設定...」選項
├── openSettings() - 開啟設定視窗
└── setupGlobalHotkey() - 讀取 UserDefaults 註冊快捷鍵

HotkeySettingsWindowController.swift (新檔)
├── NSWindowController 子類
├── 管理設定視窗生命週期

HotkeySettingsViewController.swift (新檔)
├── NSViewController 子類
├── 處理快捷鍵錄製 UI
└── 儲存設定至 UserDefaults
```

### 4.3 快捷鍵驗證

- 檢查是否與系統快捷鍵衝突
- 檢查是否與常用 App 快捷鍵衝突
- 顯示警告但允許使用者Override

### 4.4 HotKey 庫整合

使用現有的 `HotKey` 庫：
- 讀取設定：`UserDefaults` 取得 keyCode 和 modifiers
- 註冊快捷鍵：`HotKey(key:modifiers:)` 或 `HotKey(keyCode:modifiers:)`

## 5. 相容性

- 最低支援版本：macOS 12.0 (Monterey)
- 使用 macOS 原生 API

## 6. 測試案例

1. 開啟設定視窗正常顯示
2. 錄製新快捷鍵（Cmd+Shift+X）並儲存
3. 使用新快捷鍵觸發截圖
4. 重新啟動 App，快捷鍵仍然生效
5. 取消錄製（按 Escape）回到原狀
6. 設定衝突快捷鍵顯示警告

## 7. 待後續擴充

- 其他快捷鍵（複製、透明度、畫筆模式、切換視窗）
- 快捷鍵衝突檢測
- 匯入/匯出設定
