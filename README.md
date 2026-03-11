# 📌 PinSnap

一款輕量、無干擾的 macOS 截圖釘選與塗鴉工具。

讓你能夠快速截圖、將圖片釘選在螢幕最上層作為參考，並直接在上面標註塗鴉！

## ✨ 核心功能

- **⌨️ 全局快捷鍵**：支援 `Cmd + Shift + P` 進行自由區域截圖，以及全新 `Cmd + Shift + W` 進行單一視窗擷取，完成後自動釘選於螢幕上。
- **📌 永遠置頂**：釘選的圖片會浮在所有視窗之上，並帶有標準標題列方便拖移，適合工作時對照參考。
- **🎨 快速標註與塗鴉**：透過全新設計的**底部固定式工具欄**，提供多種顏色畫筆、復原操作與滴管選色工具，操作直觀無干擾。
- **📋 一鍵複製**：塗鴉完畢後，點擊複製按鈕（或按下 `Cmd + C`），即可將帶有塗鴉的圖片合成為一張圖並複製到剪貼簿。
- **💾 快速存檔**：點擊儲存按鈕（或按下 `Cmd + S`），即可將標註後的圖片存為 PNG 檔。
- **🔍 支援原況文字 (Live Text)**：可以直接選取並複製釘選圖片中的文字（需 macOS 13.0+）。
- **ℹ️ 版本與快速複製**：可直接在選單列查看當前版本，點擊即可快速複製版本號。
- **🚀 開機自動啟動**：支援在狀態列選單中設定開機自動執行。

## 🚀 安裝指南 (使用 Homebrew)

PinSnap 尚未在 Mac App Store 上架，也沒有經過 Apple 開發者憑證簽名。為了避免 macOS 繁瑣的「無法驗證開發者」警告，我們強烈建議使用 Homebrew 進行安裝。

請打開你的終端機 (Terminal)，依序輸入以下兩行指令：

**1. 加入 PinSnap 軟體源**

Bash

```
brew tap Ivantseng123/tap
```

**2. 安裝 PinSnap (繞過系統隔離驗證)**

Bash

```
brew install --cask pinsnap --no-quarantine
```

> **💡 為什麼要加 `--no-quarantine`？**
>
> 這會告訴 macOS 在下載完成後直接移除隔離標記，讓你安裝後可以直接在「應用程式」資料夾中點開 PinSnap，不會跳出安全性阻擋視窗。

## 🔄 更新與升級

PinSnap 內建自動檢查更新功能。當你在開啟 App 時收到新版本通知，你可以點擊對話框中的 "Copy Command"，或手動執行以下指令來升級：

Bash

```
# 1. 更新 Homebrew 軟體源資訊
brew update

# 2. 升級 PinSnap
brew upgrade --cask pinsnap --no-quarantine
```

## ⚙️ 首次使用與權限設定

由於 PinSnap 需要調用系統截圖功能，首次按下 `Cmd + Shift + P` 或 `Cmd + Shift + W` 截圖時，系統可能會要求權限：

1. 前往 **系統設定** -> **隱私權與安全性** -> **螢幕錄影**。
2. 找到 PinSnap 並將開關 **打開**。
3. 重新啟動 PinSnap 即可正常使用。

## 🛠️ 開發與建置 (For Developers)

如果你想自己編譯這份專案：

1. Clone 此專案：`git clone https://github.com/Ivantseng123/PinSnap.git`
2. 使用 Xcode 打開 `PinSnap.xcodeproj`。
3. 選擇你的 Mac 作為執行目標，按下 `Cmd + R` 即可編譯並執行。

## 📝 版本紀錄

- **v1.0.5**:
  - 重構釘選視窗的初始縮放邏輯，自動根據螢幕解析度調整圖片比例（最高 80%），避免大圖超出螢幕範圍。
  - 修正更新提示按鈕的判斷邏輯，並優化 `project.pbxproj` 編譯設定。
  
- **v1.0.4**：
  - 新增智慧視窗擷取快捷鍵 (`Cmd + Shift + W`)。
  - 全新設計釘選視窗 UI，改為底部固定式工具欄。
  - 恢復標準視窗標題列，優化視窗拖移與層級穩定性。
  - 重構核心截圖邏輯為非同步執行，大幅提升操作流暢度。
- **v1.0.3**：新增選單列版本顯示與點擊複製功能，優化更新提示視窗互動與 UI 字彙。
- **v1.0.2**：新增儲存檔案功能、優化 UI 排版。
- **v1.0.1**：自動檢查更新機制。
- **v1.0.0**：初始版本發布。

------

## 🤝 貢獻者 (Contributors)

<a href="https://github.com/Ivantseng123/PinSnap/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Ivantseng123/PinSnap" /></a>
