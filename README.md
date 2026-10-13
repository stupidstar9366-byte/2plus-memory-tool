# 2plus Memory Tool

A small Windows desktop utility for backing up, setting and restoring the Java heap limit in the Project Zomboid **client** launcher configuration.

**Status: 1.1.1 open-source preview. The project has not yet been approved by SignPath Foundation. Current local builds are unsigned.** A signature verifies publisher identity and file integrity; it is not an antivirus exemption.

## 給玩家

本工具用來設定僵毀玩家端的 Java 記憶體上限。Windows 10／11 64 位元、.NET Framework 4.6.2 或以上可執行。玩家仍可從 2PlusGaming 的 Discord 公告下載成品；本倉庫提供可公開查閱的源码與構建流程。

1. 完全退出遊戲到桌面。
2. 開啟 `2plus-Memory-Tool.exe`，確認遊戲安裝資料夾。
3. 依電腦總記憶體選擇 8、10、12、14 或 16 GB，再按「套用」。
4. 顯示完成後，從 Steam 一般啟動遊戲。

這是 Java 堆積記憶體上限，並非電腦總記憶體，也不涵蓋遊戲的所有占用。需為 Windows 與其他程式預留容量；只有 8 GB RAM 的電腦不適用這五個選項。

Steam 更新或驗證遊戲檔案後，請再次確認設定。若安全軟體攔截，請保留完整偵測名稱交給維護者確認。

## What changes

The app edits only root `-Xmx` and, when necessary, `-Xms` arguments in the selected `ProjectZomboid64.json`. Other launcher text, Windows-specific argument branches, and UTF-8 BOM are retained. Conflicting heap overrides, invalid JSON, a running game, and stale files are rejected.

Before committing a change, the app makes a byte-exact backup under `%LOCALAPPDATA%\2plus\MemoryTool\Backups`. Restore uses validated backup records and changes heap arguments only, so it does not reverse a newer Steam update's classpath or other settings. It supports the previous tool's backup format.

The executable runs a compiled C# Windows Forms interface directly. It does not extract or execute PowerShell scripts. There is no updater, telemetry, background service, process injection, or modification of antivirus settings, saves, mods, server settings or Windows virtual memory.

## Build and verification

See [BUILDING.md](BUILDING.md). The [GitHub Actions workflow](.github/workflows/build.yml) builds from source on a GitHub-hosted Windows runner, runs regression checks, and creates a clearly labelled unsigned artifact. Signing remains disabled until the Foundation accepts the project and signing credentials are configured.

Local core checks are not a Windows usability test or antivirus scan. The [validation record](docs/VALIDATION.md) distinguishes completed checks from pending tests.

## Removal

To undo the memory change, use **還原上次設定** while the game is closed. Then delete the portable EXE. Backups remain in the location above; delete them separately only if you no longer need them. Deleting the EXE alone does not undo an applied memory setting.

## Code signing policy

See [Code signing policy](CODE_SIGNING_POLICY.md) and [Privacy policy](PRIVACY.md). **Free signing is being prepared for application; no approval or certificate is claimed.** Do not describe a build as signed until its Authenticode signature and timestamp have been verified.

## License and attribution

Project source, tests and original generated icon are provided under the [MIT License](LICENSE). Build-only dependencies are described in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This is an independent community utility, not an official Project Zomboid, The Indie Stone, Steam, Microsoft or SignPath product. No game assets, game code or Microsoft runtime files are bundled in the app.
