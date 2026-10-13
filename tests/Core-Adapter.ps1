# Test adapter for the existing behavior suite. Every operation executes the
# compiled C# core from the release EXE; no PowerShell implementation is used.
$releaseRoot=Split-Path $PSScriptRoot -Parent
[void][Reflection.Assembly]::LoadFile((Join-Path $releaseRoot '2plus-Memory-Tool.exe'))
function Wrap-Document($d) {
    [pscustomobject]@{Native=$d;Text=$d.Text;Data=(ConvertFrom-Json -InputObject $d.Text)}
}
function Wrap-Configuration($c) {
    if ($null -eq $c) { return $null }
    [pscustomobject]@{Native=$c;Path=$c.Path;Hash=$c.Hash;Bom=$c.Bom;Document=(Wrap-Document $c.Document)}
}
function Read-PzText([string]$text) { Wrap-Document ([TwoPlus.MemoryTool.MemoryCore]::ReadText($text)) }
function Read-PzConfiguration([string]$path) { Wrap-Configuration ([TwoPlus.MemoryTool.MemoryCore]::Read($path)) }
function New-MemoryPlan($c,[int]$gb) { [TwoPlus.MemoryTool.MemoryCore]::MakePlan($c.Native,$gb) }
function New-RestorePlan($c,$backup) {
    $native=[TwoPlus.MemoryTool.Configuration]::new()
    $native.Document=$c.Document.Native
    [TwoPlus.MemoryTool.MemoryCore]::RestorePlan($native,$backup.Native)
}
function Save-MemoryPlan($c,$plan,[string]$backupRoot,[string]$action,[scriptblock]$guard) {
    [TwoPlus.MemoryTool.MemoryCore]::Save($c.Native,$plan,$backupRoot,$action,[Action]$guard)
}
function Get-LatestMemoryBackup([string]$path,[string]$root) { Wrap-Configuration ([TwoPlus.MemoryTool.MemoryCore]::LatestBackup($path,$root)) }
function Get-BytesHash([byte[]]$bytes) { [TwoPlus.MemoryTool.MemoryCore]::Hash($bytes) }
function Convert-HeapSize([string]$value) { [TwoPlus.MemoryTool.MemoryCore]::HeapBytes($value) }
function Get-MemoryAdvice([int]$gb,[double]$bytes) { [TwoPlus.MemoryTool.MemoryCore]::Assess($gb,$bytes) }
function Get-SteamLibraryPaths([string]$vdf) { [TwoPlus.MemoryTool.MemoryCore]::LibraryPaths($vdf) }
function Get-PzCandidates([string[]]$roots,[string[]]$extras) { [TwoPlus.MemoryTool.MemoryCore]::Candidates($roots,$extras) }
function Test-PzProcess([object[]]$processes) {
    $list=[Collections.Generic.List[TwoPlus.MemoryTool.ProcessInfo]]::new()
    foreach ($p in $processes) { $native=[TwoPlus.MemoryTool.ProcessInfo]::new();$native.Name=$p.Name;$native.CommandLine=$p.CommandLine;$list.Add($native) }
    [TwoPlus.MemoryTool.MemoryCore]::GameRunning($list)
}
