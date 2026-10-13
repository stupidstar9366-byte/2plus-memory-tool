# Validation record

Local verification on 2026-10-13:

- Built the 1.1.1 unsigned EXE from the public candidate C# source and generated icon.
- Passed 259 configuration, backup/restore, file-write, RAM-guard, Steam-discovery and process-rule checks against the actual compiled EXE core.
- Passed 147 release-structure, genuine old-backup fixture, strict-JSON and independent-parser checks.
- Parsed all developer PowerShell files, XML files and JSON fixtures successfully.
- Confirmed EXE file/product version `1.1.1.0`, product `2plus Memory Tool`, company `2plus`.

Host: macOS arm64, PowerShell 7.4.20, .NET 8.0.31. This local run did not execute the Windows Forms UI, Windows WMI/registry access, NTFS-specific behavior, antivirus scanning or the game itself.

The GitHub Windows workflow is configured to add a native .NET Framework form-construction/WMI smoke test. Consult the actual Actions run for its result; the presence of the workflow does not mean it has passed.

SignPath submission/approval, a production signature and Windows antivirus acceptance remain unverified. No certificate or clean antivirus verdict is claimed.
