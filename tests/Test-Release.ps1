param([string]$LegacyModulePath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root '2plus-Memory-Tool.exe'
$script:checks=0
function Check($value,[string]$reason) { if (-not $value) { throw "FAIL $reason" }; $script:checks++ }
function Reject([scriptblock]$action,[string]$reason) { $failed=$false;try { & $action | Out-Null } catch { $failed=$true };Check $failed $reason }
$assembly=[Reflection.Assembly]::LoadFile($path)
Check ($assembly.GetName().Version.ToString() -eq '1.1.1.0') 'assembly version'
Check ($assembly.EntryPoint.Name -eq 'Main') 'real entry point'
Check (@($assembly.EntryPoint.GetCustomAttributesData() | Where-Object {$_.AttributeType.Name -eq 'STAThreadAttribute'}).Count -eq 1) 'STA entry point'
Check (@($assembly.GetManifestResourceNames()).Count -eq 0) 'no embedded script or payload resources'
Check ($null -ne $assembly.GetType('TwoPlus.MemoryTool.MemoryCore')) 'compiled core in release EXE'
foreach ($reference in $assembly.GetReferencedAssemblies()) {
    Check ($reference.Name -in @('mscorlib','System','System.Core','System.Drawing','System.Windows.Forms','System.Management')) "Framework reference only: $($reference.Name)"
}
$stream=[IO.File]::OpenRead($path)
try {
    $pe=[Reflection.PortableExecutable.PEReader]::new($stream)
    try {
        Check ($pe.PEHeaders.PEHeader.Subsystem.ToString() -eq 'WindowsGui') 'native Windows GUI subsystem'
        Check ($pe.PEHeaders.CorHeader.Flags.ToString() -eq 'ILOnly') 'AnyCPU without prefer32 flag'
        Check ($pe.PEHeaders.PEHeader.ResourceTableDirectory.Size -gt 0) 'native icon/version/manifest'
        Check ($pe.PEHeaders.PEHeader.CertificateTableDirectory.Size -eq 0) 'unsigned status recorded'
        Check ($pe.PEHeaders.CorHeader.ResourcesDirectory.Size -eq 0) 'no managed embedded resources'
    } finally { $pe.Dispose() }
} finally { $stream.Dispose() }
$bytes=[IO.File]::ReadAllBytes($path)
$text=[Text.Encoding]::UTF8.GetString($bytes)
Check ($text.Contains('level="asInvoker"')) 'does not request automatic elevation'
Check ($text.Contains('assemblyIdentity version="1.1.1.0"')) 'embedded manifest version'
$strings=$text+[Text.Encoding]::Unicode.GetString($bytes)
foreach ($forbidden in @('powershell.exe','pwsh.exe','cmd.exe','-ExecutionPolicy','FromBase64String','DownloadString','Invoke-Expression')) {
    Check (-not $strings.Contains($forbidden)) "no script-launcher marker: $forbidden"
}
$work=Join-Path $PSScriptRoot ('release-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
$utf8=[Text.UTF8Encoding]::new($false)
try {
    # Generate a genuine previous-release receipt using the old module, then
    # restore using the new compiled core while retaining a Steam update.
    $configPath=Join-Path $work 'ProjectZomboid64.json'
    $backups=Join-Path $work 'Backups'
    $original='{"mainClass":"zombie/gameStates/MainScreenState","vmArgs":["-Xmx3072m","-XX:+UseZGC"]}'
    [IO.File]::WriteAllText($configPath,$original,$utf8)
    if ($LegacyModulePath) {
        Import-Module $LegacyModulePath -Force -DisableNameChecking
        $legacy=Read-PzConfiguration $configPath
        [void](Save-MemoryPlan $legacy (New-MemoryPlan $legacy 8) $backups 'set' {})
        Remove-Module MemoryCore
    } else {
        # This fixture was captured from the genuine 1.0.3 module. Only the
        # receipt's temporary ConfigPath changes for the machine running tests.
        $fixture=Join-Path $PSScriptRoot 'fixtures'
        $record=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $fixture 'legacy-1.0.3-receipt.json')))
        $record.ConfigPath=$configPath
        $folder=[TwoPlus.MemoryTool.MemoryCore]::BackupDirectory($configPath,$backups)
        [void][IO.Directory]::CreateDirectory($folder)
        Copy-Item -LiteralPath (Join-Path $fixture 'legacy-1.0.3-backup.json') -Destination (Join-Path $folder $record.BackupName)
        $receipt=Join-Path $folder ($record.BackupName.Replace('.json','.applied.json'))
        [IO.File]::WriteAllText($receipt,($record | ConvertTo-Json),$utf8)
    }
    $updated=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/windows-launcher.json')).Replace('-Xmx3072m','-Xmx8192m')
    [IO.File]::WriteAllText($configPath,$updated,$utf8)
    $c=[TwoPlus.MemoryTool.MemoryCore]::Read($configPath)
    $backup=[TwoPlus.MemoryTool.MemoryCore]::LatestBackup($configPath,$backups)
    Check ($backup.Document.Text -ceq $original) 'reads genuine 1.0.3 backup'
    $plan=[TwoPlus.MemoryTool.MemoryCore]::RestorePlan($c,$backup)
    [void][TwoPlus.MemoryTool.MemoryCore]::Save($c,$plan,$backups,'restore',[Action]{})
    Check ([IO.File]::ReadAllText($configPath) -ceq $updated.Replace('-Xmx8192m','-Xmx3072m')) 'old backup restores without reversing Steam update'

    foreach ($bad in @('', ' ', '{', '{"x":}', '{"x":1,}', '{"x" 1}', '[1,]', '[,]', '[1 2]', '00', '01', '+1', '.2', '1.', '1e', 'Infinity', 'NaN', 'undefined', 'true false', '"\x20"', '"\u1"', '"a'+[char]9+'b"', '{"a":1,"a":2}', '{"a":1,"\u0061":2}')) {
        Reject { [TwoPlus.MemoryTool.JsonReader]::Parse($bad) } "reject malformed JSON: $bad"
    }
    Reject { [TwoPlus.MemoryTool.JsonReader]::Parse(('['*70)+'0'+(']'*70)) } 'depth bounded'
    Reject { [TwoPlus.MemoryTool.JsonReader]::Parse(' '*1048577) } 'size bounded'
    foreach ($valid in @('null','true','false','0','-0','-1.3e+05','1E-2','"\u4e2d\u6587"','[1,true,null,"a",{}]','{"空":[],"quote":"\"\\\/\b\f\n\r\t"}')) {
        $node=[TwoPlus.MemoryTool.JsonReader]::Parse($valid)
        Check ($node.End -eq $valid.Length) 'valid JSON fully consumed'
    }
    $invalid=Join-Path $work 'bad-utf8.json'
    [IO.File]::WriteAllBytes($invalid,[byte[]](0xC3,0x28))
    Reject { [TwoPlus.MemoryTool.MemoryCore]::Read($invalid) } 'invalid UTF-8 rejected'
    Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($invalid)) -eq 'wyg=') 'invalid UTF-8 not modified'

    # Independent serializer generates varied escaping/layout. Verify other JSON
    # content by exact text comparison, not by the implementation's parser alone.
    $random=[Random]::new(417)
    $parts=@('中文','quote"','slash\','[braces]{}',"`t`n",'emoji🐺','vmArgs','-Xmx999g')
    for ($i=0;$i -lt 40;$i++) {
        $extra=($parts | Sort-Object {$random.Next()}) -join ' '
        $object=[ordered]@{windows=@{'10.0'=@{vmArgs=@('-XX:+UseZGC',('-Dnote='+$extra))}};mainClass='zombie/gameStates/MainScreenState';vmArgs=@('-Xmx3072m',('-Dtest='+$extra));metadata=@{values=@(1,$true,$null,@{nested=$extra})}}
        $source=$object | ConvertTo-Json -Depth 12 -Compress:($i%2 -eq 0)
        $cfg=[TwoPlus.MemoryTool.Configuration]::new();$cfg.Document=[TwoPlus.MemoryTool.MemoryCore]::ReadText($source)
        $next=[TwoPlus.MemoryTool.MemoryCore]::MakePlan($cfg,12)
        Check ($next.Text -ceq $source.Replace('-Xmx3072m','-Xmx12288m')) 'random escaped metadata untouched'
        $oracle=ConvertFrom-Json -InputObject $next.Text
        Check ($oracle.vmArgs[0] -ceq '-Xmx12288m') 'independent JSON parser accepts output'
    }
    Write-Output "PASS $script:checks release checks: PE metadata, dependencies, no embedded scripts, genuine old backup compatibility, strict JSON boundaries and independent JSON parser round trips."
    Write-Output 'Windows GUI/WMI/registry/NTFS, Authenticode signing, antivirus scanning and actual game launch NOT performed.'
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
