param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $root 'artifacts/unsigned' }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Package directory already exists; choose a fresh output directory.' }
[void][IO.Directory]::CreateDirectory($OutputDirectory)
foreach ($name in @('2plus-Memory-Tool.exe','README.md','LICENSE','PRIVACY.md','CODE_SIGNING_POLICY.md')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $OutputDirectory $name)
}
$file=Join-Path $OutputDirectory '2plus-Memory-Tool.exe'
$hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256SUMS.txt'),$hash+"  2plus-Memory-Tool.exe`n",[Text.UTF8Encoding]::new($false))
$data=[ordered]@{version='1.1.1';status='unsigned';sha256=$hash;commit=$env:GITHUB_SHA;runner=$env:RUNNER_OS;powerShell=$PSVersionTable.PSVersion.ToString();builtFromSource=$true}
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'build-info.json'),($data | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "Packaged unsigned build: $hash"
