param([string]$FrameworkReferenceDirectory)
# Developer build script; this file is never shipped inside or executed by the EXE.
# Requires PowerShell 7 with bundled Roslyn and .NET Framework 4.6.2 reference assemblies.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if (-not $FrameworkReferenceDirectory) { $FrameworkReferenceDirectory=& (Join-Path $PSScriptRoot 'scripts/Restore-References.ps1') }
$python=Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python=Get-Command python3 -ErrorAction Stop }
& $python.Source (Join-Path $PSScriptRoot 'scripts/make_icon.py')
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed.' }
Add-Type -Path (Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll')
Add-Type -Path (Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll')
$references=@((Get-ChildItem (Join-Path $PSHOME 'ref') -Filter '*.dll').FullName)
$references+=Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'
$references+=Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Compiler.cs'))) -ReferencedAssemblies $references -CompilerOptions '/nowarn:1701'
[TwoPlusDesktopCompiler]::Build($PSScriptRoot,$FrameworkReferenceDirectory)
