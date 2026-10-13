# Building from source

The app targets .NET Framework 4.6.2 as a Windows GUI executable. A 64-bit Windows installation is required to run it. The runtime application does not require PowerShell or Python.

Build prerequisites: PowerShell 7 with bundled Roslyn, Python 3, and internet access to NuGet for the first reference-assembly restore. These are developer tools only.

```powershell
pwsh -NoProfile -File Build.ps1
pwsh -NoProfile -File tests/Test-Core.ps1
pwsh -NoProfile -File tests/Test-Release.ps1
```

The build restores the exact `Microsoft.NETFramework.ReferenceAssemblies.net462` version `1.0.3` from NuGet and verifies its SHA-256. `scripts/make_icon.py` creates the original icon without fonts or external artwork. `Compiler.cs` compiles the three C# source files directly; no script or runtime payload is embedded.

An offline build can supply the reference directory explicitly:

```powershell
pwsh -NoProfile -File Build.ps1 -FrameworkReferenceDirectory '<reference-folder>/build/.NETFramework/v4.6.2'
```

On Windows, also run the .NET Framework smoke test with **Windows PowerShell 5.1**:

```powershell
powershell -NoProfile -STA -File tests/Test-Windows.ps1
```

That test constructs and disposes the form and queries local process information. It does not modify a live game configuration. It is not a substitute for interactive testing, DPI checks, game launch or an antivirus scan.

Package with `pwsh -NoProfile -File scripts/Package.ps1`. Output is labelled unsigned. Build information records the source commit and runner environment when run in GitHub Actions. Different compiler versions may produce different binary hashes; origin verification relies on the actual hosted build record.

The regression suite uses temporary fixtures, including a receipt originally produced by version 1.0.3. It does not access real player save files. To additionally regenerate that receipt using an old developer checkout, `tests/Test-Release.ps1` accepts the optional `-LegacyModulePath` argument.

Signing setup after Foundation acceptance is documented in [signing/SETUP.md](signing/SETUP.md).
