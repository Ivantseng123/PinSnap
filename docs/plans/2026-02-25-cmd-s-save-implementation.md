# Cmd + S 快捷鍵存檔功能實作計劃

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目標：** 為 PinSnap 新增 Cmd + S 快捷鍵，讓使用者可將帶有塗鴉的圖片儲存至指定位置。

**架構：** 在現有 `PinnedWindow.performKeyEquivalent` 中新增 Cmd + S 處理，透過 callback 觸發 `PinnedImageWindowController` 的存檔方法，使用 `NSSavePanel` 讓使用者選擇儲存位置。

**技術堆疊：** Swift, AppKit, NSWindow, NSSavePanel, NSBitmapImageRep

---

### Task 1: 在 PinnedWindow 新增 onSaveCommand callback

**Files:**
- Modify: `PinSnap/CaptureManager.swift:53` (在 `var onCopyCommand` 之後新增)

**Step 1: 新增 callback 屬性**

在 `PinnedWindow` class 中 `onCopyCommand` 屬性後方新增：

```swift
var onSaveCommand: (() -> Void)?
```

**Step 2: Commit**

```bash
git add PinSnap/CaptureManager.swift
git commit -m "feat: add onSaveCommand callback property"
```

---

### Task 2: 在 performKeyEquivalent 新增 Cmd + S 處理

**Files:**
- Modify: `PinSnap/CaptureManager.swift:57-66` (在 Cmd + C 處理之後)

**Step 1: 新增 Cmd + S 處理邏輯**

在 `performKeyEquivalent` 方法中，Cmd + C 處理之後新增：

```swift
// Cmd + S 存檔
if isCommand && event.keyCode == 1 {
    onSaveCommand?()
    return true
}
```

**Step 2: Commit**

```bash
git add PinSnap/CaptureManager.swift
git commit -m "feat: handle Cmd+S key equivalent"
```

---

### Task 3: 在 PinnedImageWindowController 設定 callback 綁定

**Files:**
- Modify: `PinSnap/CaptureManager.swift:244-246` (在 onCopyCommand 設定之後)

**Step 1: 新增 onSaveCommand callback 綁定**

在 `(window as? PinnedWindow)?.onCopyCommand = { ... }` 後方新增：

```swift
(window as? PinnedWindow)?.onSaveCommand = { [weak self] in
    self?.saveToFile()
}
```

**Step 2: Commit**

```bash
git add PinSnap/CaptureManager.swift
git commit -m "feat: bind onSaveCommand callback"
```

---

### Task 4: 新增 saveToFile 方法

**Files:**
- Modify: `PinSnap/CaptureManager.swift` (在 copyToClipboard 方法後方新增)

**Step 1: 新增存檔方法**

在 `PinnedImageWindowController` 中新增：

```swift
@objc private func saveToFile() {
    guard let image = pinnedImage else { return }
    
    let finalImage = drawingOverlay.renderOn(image: image)
    
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.png]
    savePanel.nameFieldStringValue = generateFileName()
    savePanel.canCreateDirectories = true
    
    savePanel.beginSheetModal(for: window!) { [weak self] response in
        guard response == .OK, let url = savePanel.url else { return }
        
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            self?.showToast(message: "Save failed ✗")
            return
        }
        
        do {
            try pngData.write(to: url)
            let fileName = url.lastPathComponent
            self?.showToast(message: "Saved to \(fileName) ✓")
        } catch {
            self?.showToast(message: "Save failed ✗")
        }
    }
}

private func generateFileName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())
    return "PinSnap_\(timestamp).png"
}
```

**Step 2: Commit**

```bash
git add PinSnap/CaptureManager.swift
git commit -m "feat: implement saveToFile method"
```

---

### Task 5: 驗證功能

**Step 1: 使用 Xcode 建置專案**

```bash
xcodebuild -project PinSnap.xcodeproj -scheme PinSnap -configuration Debug build
```

**Step 2: 手動測試**

1. 按下 Cmd + Shift + P 截圖
2. 在截圖上隨意塗鴉
3. 按下 Cmd + S 確認彈出儲存面板
4. 選擇位置儲存
5. 確認 Toast 顯示正確訊息
6. 確認檔案成功儲存且包含塗鴉

**Step 3: Commit**

```bash
git add PinSnap/CaptureManager.swift
git commit -m "test: verify Cmd+S save functionality"
```
