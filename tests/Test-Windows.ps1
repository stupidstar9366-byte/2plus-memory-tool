# Native .NET Framework smoke test. Run with Windows PowerShell 5.1 -STA.
# It constructs/disposes the real form; it does not edit a game configuration.
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 for this Framework smoke test.' }
if (-not [Environment]::Is64BitOperatingSystem) { throw 'A 64-bit Windows host is required.' }
Add-Type -AssemblyName System.Windows.Forms
$root=Split-Path $PSScriptRoot -Parent
$assembly=[Reflection.Assembly]::LoadFile((Join-Path $root '2plus-Memory-Tool.exe'))
$type=$assembly.GetType('TwoPlus.MemoryTool.MemoryForm',$true)
$form=[Activator]::CreateInstance($type,$true)
try {
    if ($form.Text -notlike '*1.1.1*') { throw 'Wrong form version.' }
    if ($form.Controls.Count -lt 1) { throw 'Missing form controls.' }
    $form.CreateControl()
    $method=$type.GetMethod('AssertClosed',[Reflection.BindingFlags]'NonPublic,Static')
    $method.Invoke($null,@())
    Write-Output 'PASS native .NET Framework form construction, memory query and game-process WMI query.'
    Write-Output 'No interactive UI, actual game launch or antivirus scan performed.'
} finally { $form.Dispose() }
