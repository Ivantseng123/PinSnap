# 📌 PinSnap

一款輕量、無干擾的 macOS 截圖釘選與塗鴉工具。
讓你能夠快速截圖、將圖片釘選在螢幕最上層作為參考，並直接在上面標註塗鴉！

![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-FA7343?style=for-the-badge&logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

## ✨ 核心功能

* **⌨️ 全局快捷鍵**：隨時按下 `Cmd + Shift + P` 進行截圖，完成後自動釘選於螢幕上。
* **📌 永遠置頂**：釘選的圖片會浮在所有視窗之上，方便工作時對照參考。
* **🎨 快速標註與塗鴉**：內建畫筆模式，支援多種顏色、復原操作與滴管選色工具。
* **👻 調整透明度**：可隨時調整釘選視窗的透明度，避免遮擋底下的重要資訊。
* **📋 一鍵複製**：塗鴉完畢後，點擊複製按鈕（或按下 `Cmd + C`），即可將帶有塗鴉的圖片合成為一張圖並複製到剪貼簿。
* **💾 快速存檔**：點擊儲存按鈕（或按下 Cmd + S），即可將標註後的圖片存為 PNG 檔。
* **🔍 支援原況文字 (Live Text)**：可以直接選取並複製釘選圖片中的文字（需 macOS 13.0+）。
* **🚀 開機自動啟動**：支援在狀態列選單中設定開機自動執行。

---

## 🚀 安裝指南 (使用 Homebrew)

PinSnap 尚未在 Mac App Store 上架，也沒有經過 Apple 開發者憑證簽名。為了避免 macOS 繁瑣的「無法驗證開發者」警告，我們強烈建議使用 [Homebrew](https://brew.sh/) 進行安裝。

請打開你的**終端機 (Terminal)**，依序輸入以下兩行指令：

### 1. 加入 PinSnap 軟體源
```bash
brew tap Ivantseng123/tap

```

### 2. 安裝 PinSnap (繞過系統隔離驗證)

```bash
brew install --cask pinsnap --no-quarantine

```

> **💡 為什麼要加 `--no-quarantine`？**
> 這會告訴 macOS 在下載完成後直接移除隔離標記，讓你安裝後可以直接在「應用程式」資料夾中點開 PinSnap，不會跳出安全性阻擋視窗。

---

## 🔄 更新與升級

PinSnap 內建自動檢查更新功能。當你在開啟 App 時收到新版本通知，請打開**終端機 (Terminal)** 並執行以下指令來升級至最新版本：

```bash
# 1. 更新 Homebrew 軟體源資訊
brew update

# 2. 升級 PinSnap (同樣建議加上 --no-quarantine 以維持順暢體驗)
brew upgrade --cask pinsnap --no-quarantine

```

> **💡 小撇步：** > 如果你想手動檢查有沒有新版本，也可以隨時執行 `brew outdated` 來查看是否有可用的更新。


## ⚙️ 首次使用與權限設定

由於 PinSnap 需要調用系統截圖功能，首次按下 `Cmd + Shift + P` 截圖時，系統可能會要求權限：

1. 前往 **系統設定** -> **隱私權與安全性** -> **螢幕錄影**。
2. 找到 `PinSnap` 並將開關 **打開**。
3. 重新啟動 PinSnap 即可正常使用。

---

## 🛠️ 開發與建置 (For Developers)

如果你想自己編譯這份專案：

1. Clone 此專案：`git clone https://github.com/Ivantseng123/PinSnap.git`
2. 使用 Xcode 打開 `PinSnap.xcodeproj`。
3. 選擇你的 Mac 作為執行目標，按下 `Cmd + R` 即可編譯並執行。

---

## 📝 版本紀錄：
   * **v1.0.2**：新增儲存檔案功能、優化 UI 排版。
   * **v1.0.1**：自動檢查更新機制。
   * **v1.0.0**：初始版本發布。

## 👨‍💻 作者

**Ivan Tseng** (@Ivantseng123)
