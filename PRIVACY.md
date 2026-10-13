# Privacy policy

The desktop application does not send telemetry, crash reports, account information, files or usage statistics to the maintainer or to any other service. It has no analytics, advertising, online account or automatic update feature.

All normal operations happen on the user's computer:

- Read total installed RAM to explain available capacity.
- Read Steam installation registry entries and library manifests to locate game folders.
- Read the selected game launcher JSON and keep a backup before changing heap arguments.
- Read local process names and Java command lines through Windows WMI solely to check whether Project Zomboid is still running. These are not saved or transmitted.
- Open the backup folder in Windows Explorer only when the user presses that button.

Backups and local receipts contain the original game JSON, the file path, hashes and the action taken. They are stored under `%LOCALAPPDATA%\2plus\MemoryTool\Backups`; the user controls when to delete them. A manually selected network folder is accessed only as directed by the user.

Development and distribution services are separate from the app. GitHub hosts public source and build records. SignPath would process release artifacts if this project is accepted. Discord may host community downloads. Using those websites is subject to their own privacy policies. The app itself does not connect to them.

When reporting a problem, remove passwords, personal paths and unrelated information before attaching logs or screenshots to a public issue.
