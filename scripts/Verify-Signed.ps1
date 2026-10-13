param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop'
$file=Join-Path $Directory '2plus-Memory-Tool.exe'
$signature=Get-AuthenticodeSignature -LiteralPath $file
if ($signature.Status -ne 'Valid') { throw ('Signature verification failed: '+$signature.Status) }
if (-not $signature.TimeStamperCertificate) { throw 'A trusted timestamp is required for the signed release.' }
if ($signature.SignerCertificate.Subject -notmatch 'SignPath Foundation') { throw 'Unexpected publisher; review before release.' }
$hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $Directory 'SHA256SUMS.txt'),$hash+"  2plus-Memory-Tool.exe`n",[Text.UTF8Encoding]::new($false))
$data=[ordered]@{version='1.1.1';status='authenticode-valid';sha256=$hash;publisher=$signature.SignerCertificate.Subject;timestampPresent=$true;commit=$env:GITHUB_SHA;runner=$env:RUNNER_OS}
[IO.File]::WriteAllText((Join-Path $Directory 'build-info.json'),($data|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "PASS signature and timestamp: $hash"
