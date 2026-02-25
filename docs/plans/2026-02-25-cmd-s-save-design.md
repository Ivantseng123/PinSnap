# Design: Cmd + S 快捷鍵存檔功能

## 概述

為 PinSnap 截圖釘選工具新增 Cmd + S 快捷鍵支援，讓使用者能夠將帶有塗鴉的圖片儲存至指定位置。

## 現況

- 現有 `PinnedWindow.performKeyEquivalent` 已處理 Cmd + C（複製到剪貼簿）
- 圖片渲染使用 `DrawingOverlayView.renderOn(image:)` 將塗鴉合成至原圖

## 設計

### 實作方式

在現有 `PinnedWindow.performKeyEquivalent` 中新增 Cmd + S 處理：

```swift
// 新增 Cmd + S 存檔功能
if isCommand && event.keyCode == 1 {  // keyCode 1 = S
    onSaveCommand?()
    return true
}
```

### 新增元件

1. **Callback 屬性** (`PinnedWindow`)
   ```swift
   var onSaveCommand: (() -> Void)?
   ```

2. **存檔方法** (`PinnedImageWindowController`)
   ```swift
   @objc private func saveToFile()
   ```

### 存檔流程

1. 觸發 Cmd + S
2. 顯示 `NSSavePanel` 讓使用者選擇路徑
   - 預設檔名：`PinSnap_YYYY-MM-DD_HH-mm-ss.png`
   - 預設格式：PNG
3. 使用 `drawingOverlay.renderOn(image:)` 渲染最終圖片
4. 寫入檔案（使用 `NSBitmapImageRep` 轉換為 PNG 資料）
5. 顯示成功 Toast 提示：「Saved to [filename] ✓」

### 錯誤處理

- 使用者取消儲存 → 無動作
- 寫入失敗 → 顯示錯誤 Toast：「Save failed ✗」

## 影響範圍

- `CaptureManager.swift`
  - `PinnedWindow` class：新增 `onSaveCommand` callback
  - `PinnedWindow.performKeyEquivalent`：新增 Cmd + S 處理
  - `PinnedImageWindowController`：新增 `saveToFile()` 方法

## 相容性

- 支援 macOS 13.0+（與現有專案一致）
- 無需額外權限
