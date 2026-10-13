$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$cache=Join-Path $root '.packages'
$package=Join-Path $cache 'microsoft.netframework.referenceassemblies.net462.1.0.3.nupkg'
$extracted=Join-Path $cache 'net462-1.0.3'
$expected='ee692a845743500910855d4c330ca6e9ef87c16e16f740e4474d187185d66e21'
$url='https://api.nuget.org/v3-flatcontainer/microsoft.netframework.referenceassemblies.net462/1.0.3/microsoft.netframework.referenceassemblies.net462.1.0.3.nupkg'
[void][IO.Directory]::CreateDirectory($cache)
if (-not (Test-Path -LiteralPath $package)) { Invoke-WebRequest -Uri $url -OutFile $package }
if ((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected) {
    throw 'Reference package hash mismatch. No compilation performed.'
}
if (-not (Test-Path -LiteralPath $extracted)) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($package,$extracted)
}
$framework=Join-Path $extracted 'build/.NETFramework/v4.6.2'
if (-not (Test-Path -LiteralPath (Join-Path $framework 'mscorlib.dll'))) { throw 'Reference package is incomplete.' }
return $framework
