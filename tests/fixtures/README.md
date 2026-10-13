# Test fixtures

`windows-launcher.json` is a representative launcher structure for regression testing, not a copy of any player's private configuration.

`legacy-1.0.3-backup.json` and `legacy-1.0.3-receipt.json` were produced by running the original 1.0.3 backup implementation against a temporary sample configuration. The receipt's local `ConfigPath` was replaced by `__TEMP_CONFIG_PATH__`; tests substitute their own temporary path. The original backup contents and recorded hashes remain unchanged.

No player credentials, real game save data or user-specific file paths are included.
