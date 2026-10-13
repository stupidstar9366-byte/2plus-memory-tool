# Third-party components and names

The distributed EXE contains this project's compiled C# and an original pixel icon generated from `scripts/make_icon.py`. It does not bundle the game, game assets, fonts, PowerShell, Python, Microsoft reference assemblies or other executables.

Windows and .NET Framework are system dependencies installed separately by the user. The app references `mscorlib`, `System`, `System.Core`, `System.Drawing`, `System.Windows.Forms` and `System.Management`.

Development-only dependencies, downloaded separately rather than copied into this repository:

- Microsoft .NET Framework Reference Assemblies net462 1.0.3, from the official NuGet package. Its package license and notices remain with the downloaded package.
- Microsoft Roslyn bundled with PowerShell 7, used only by the build script under its upstream terms.
- Python 3, used to generate the icon with standard-library code.
- GitHub Actions checkout/upload-artifact and the SignPath signing action, referenced at pinned upstream commits in the workflow.

Project Zomboid and Steam are names of third-party products. References identify the compatible game and installation method; no endorsement or affiliation is claimed.
