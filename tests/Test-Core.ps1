$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'Core-Adapter.ps1')
$script:checks = 0
function Check($Value, [string]$Message) { if (-not $Value) { throw "FAIL $Message" }; $script:checks++ }
function Reject([scriptblock]$Action,[string]$Message) {
    $failed=$false
    try { & $Action | Out-Null } catch { $failed=$true }
    Check $failed $Message
}
$work = Join-Path $PSScriptRoot ('run-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
$utf8=New-Object Text.UTF8Encoding($false)
function Fixture([string[]]$VmArguments, [string]$Suffix='') {
    return ([ordered]@{ mainClass='zombie/gameStates/MainScreenState'; classpath=@('java/.','java/projectzomboid.jar');
        vmArgs=$VmArguments; env=[ordered]@{ PATH='C:\遊戲\! & (Steam)\java'; data=$Suffix } } | ConvertTo-Json -Depth 10)
}
function Write-Fixture([string]$Name, [string]$Text, [bool]$Bom=$false) {
    $dir=Join-Path $work $Name
    [void][IO.Directory]::CreateDirectory($dir)
    $path=Join-Path $dir 'ProjectZomboid64.json'
    [IO.File]::WriteAllText($path,$Text,(New-Object Text.UTF8Encoding($Bom)))
    return Read-PzConfiguration $path
}
try {
    # Regression: real Windows launcher structure has root AND per-Windows vmArgs.
    # This is a representative fixture, not a copy of the reporting player's file.
    $windowsText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/windows-launcher.json'))
    foreach ($gb in @(8,10,12,14,16)) {
        foreach ($bom in @($false,$true)) {
            $text=$windowsText
            if ($bom) { $text=$text.Replace("`r`n","`n").Replace("`n","`r`n") }
            $config=Write-Fixture "Windows 分支 $gb GB $bom" $text $bom
            $plan=New-MemoryPlan $config $gb
            $expected=$text.Replace('-Xmx3072m',"-Xmx$($gb*1024)m")
            Check ($plan.Text -ceq $expected) "Windows $gb GB: only root heap changed, all OS branches exact"
            $backups=Join-Path $work 'windows-backups'
            $result=Save-MemoryPlan $config $plan $backups 'set' {}
            $after=Read-PzConfiguration $config.Path
            Check ($after.Document.Text -ceq $expected -and $after.Bom -eq $bom) 'Windows file write and encoding'
            Check ((Get-BytesHash ([IO.File]::ReadAllBytes($result.BackupPath))) -ceq $config.Hash) 'Windows original backup exact'
            Check (-not (Save-MemoryPlan $after (New-MemoryPlan $after $gb) $backups 'set' {}).Changed) 'Windows repeat apply no-op'
            $saved=Get-LatestMemoryBackup $config.Path $backups
            [void](Save-MemoryPlan $after (New-RestorePlan $after $saved) $backups 'restore' {})
            Check ((Read-PzConfiguration $config.Path).Hash -ceq $config.Hash) 'Windows restore exact including nested vmArgs'
        }
    }
    # Preserve every Windows branch, even empty and multi-element arrays.
    foreach ($argsJson in @('[]', '["-XX:+UseZGC"]', '["-XX:+UseG1GC","-Dnote=兩個參數"]')) {
        $text='{"mainClass":"zombie/gameStates/MainScreenState","vmArgs":["-Xmx3072m"],"windows":{"10.0":{"vmArgs":'+$argsJson+'}}}'
        $cfg=Write-Fixture ('windows-shape-'+[Guid]::NewGuid().ToString('N')) $text
        $plan=New-MemoryPlan $cfg 8
        Check ($plan.Text -ceq $text.Replace('-Xmx3072m','-Xmx8192m')) 'valid Windows string array preserved'
    }
    # Fail closed without flattening or converting genuine non-string arguments.
    foreach ($invalidArgs in @('[null]','[123]','[true]','[{}]','[["-XX:+UseZGC"]]',
        '[[]]','["-XX:+UseZGC",null]','["-XX:+UseZGC",["-Xmx16g"]]')) {
        $text='{"mainClass":"zombie/gameStates/MainScreenState","vmArgs":["-Xmx3072m"],"windows":{"10.0":{"vmArgs":'+$invalidArgs+'}}}'
        $invalidPath=Join-Path $work 'invalid-argument-type.json'
        [IO.File]::WriteAllText($invalidPath,$text,$utf8)
        Reject { $invalidConfig=Read-PzConfiguration $invalidPath; Save-MemoryPlan $invalidConfig (New-MemoryPlan $invalidConfig 8) $backups 'set' {} } 'non-string Windows element rejected'
        Check ([IO.File]::ReadAllText($invalidPath) -ceq $text) 'rejected types leave bytes intact'
        $text=$text.Replace('"vmArgs":["-Xmx3072m"]','"vmArgs":'+$invalidArgs).Replace('"windows"','"ignoredMetadata"')
        Reject { Read-PzText $text } 'non-string root element rejected'
    }
    $nestedFirst='{"windows":{"6.1":{"vmArgs":["-XX:+UseG1GC"]},"10.0.17134":{"vmArgs":["-XX:+UseZGC"]}},"mainClass":"zombie/gameStates/MainScreenState","vmArgs":["-Xmx3072m"]}'
    $cfg=Write-Fixture 'nested-before-root' $nestedFirst
    Check ((New-MemoryPlan $cfg 10).Text -ceq $nestedFirst.Replace('-Xmx3072m','-Xmx10240m')) 'root array located even when Windows comes first'
    $escaped=$nestedFirst.Replace('"vmArgs"','"vm\u0041rgs"')
    $cfg=Write-Fixture 'escaped-keys' $escaped
    Check ((New-MemoryPlan $cfg 8).Text -ceq $escaped.Replace('-Xmx3072m','-Xmx8192m')) 'JSON escaped keys decoded without rewriting'
    $tricky=[ordered]@{ metadata=@{vmArgs=@('-Xmx22g');text='"vmArgs": ["-Xmx99g"] { } [ ] \ "'};
        mainClass='zombie/gameStates/MainScreenState'; vmArgs=@('-Dpath=C:\a[b]{c}\','-Dtext="vmArgs": ["-Xmx99g"]','-Xmx3072m');
        windows=@{'6.1'=@{vmArgs=@('-XX:+UseG1GC')}} } | ConvertTo-Json -Depth 10
    $cfg=Write-Fixture 'strings-and-metadata' $tricky
    Check ((New-MemoryPlan $cfg 12).Text -ceq $tricky.Replace('-Xmx3072m','-Xmx12288m')) 'quoted brackets and unrelated metadata vmArgs preserved'
    $noHeap=$windowsText.Replace('"-Xmx3072m",','')
    $cfg=Write-Fixture 'windows-no-heap' $noHeap
    $plan=New-MemoryPlan $cfg 14
    Check ((Read-PzText $plan.Text).Data.vmArgs -contains '-Xmx14336m') 'insert missing heap in root Windows config'
    $restored=Read-PzText (New-RestorePlan ([pscustomobject]@{Document=(Read-PzText $plan.Text)}) $cfg).Text
    Check (($restored.Data.vmArgs -join '|') -ceq ($cfg.Document.Data.vmArgs -join '|')) 'restore missing heap on Windows'
    Check (($restored.Data.windows | ConvertTo-Json -Depth 10) -ceq ($cfg.Document.Data.windows | ConvertTo-Json -Depth 10)) 'restore leaves Windows branches intact'
    foreach ($bad in @(
        $nestedFirst.Replace('"vmArgs":["-Xmx3072m"]','"vmArgs":["-Xmx3072m"],"vmArgs":["-Xmx4096m"]'),
        $nestedFirst.Replace('"vmArgs":["-Xmx3072m"]','"vmArgs":["-Xmx3072m"],"vm\u0041rgs":["-Xmx4096m"]'),
        $nestedFirst.Replace('"-XX:+UseG1GC"','"-XX:+UseG1GC","-Xmx16g"'),
        $nestedFirst.Replace('"-XX:+UseZGC"','"-Xms12g"'),
        $nestedFirst.Replace('"-XX:+UseZGC"','"-XX:MaxHeapSize=16g"'),
        $nestedFirst.Replace('"-XX:+UseZGC"','"-XX:InitialHeapSize=12g"'),
        $nestedFirst.Replace('"-XX:+UseZGC"','"-XX:SoftMaxHeapSize=12g"'),
        $nestedFirst.Replace('"-XX:+UseZGC"','null'),
        $nestedFirst.Replace('["-XX:+UseZGC"]','"-Xmx16g"'),
        $nestedFirst.Replace('"vmArgs":["-XX:+UseZGC"]','"vmArgs":["-XX:+UseZGC"],"vmArgs":["-Xmx16g"]')
    )) {
        $invalidPath=Join-Path $work 'ambiguous-windows.json'
        [IO.File]::WriteAllText($invalidPath,$bad,$utf8)
        Reject { $invalidConfig=Read-PzConfiguration $invalidPath; Save-MemoryPlan $invalidConfig (New-MemoryPlan $invalidConfig 8) $backups 'set' {} } 'ambiguous Windows configuration rejected'
        Check ([IO.File]::ReadAllText($invalidPath) -ceq $bad) 'rejected Windows configuration stays untouched'
    }
    $original=Fixture @('-Xmx3072m','-Xms1024m','-XX:+UseZGC','-Djava.library.path=win64','-javaagent:C:\My Game\helper.jar')
    foreach ($gb in @(8,10,12,14,16)) {
        foreach ($bom in @($false,$true)) {
            $config=Write-Fixture "記憶體 $gb GB ! & (test) $bom" $original $bom
            $plan=New-MemoryPlan $config $gb
            $parsed=Read-PzText $plan.Text
            Check ($parsed.Data.vmArgs[0] -ceq "-Xmx$($gb*1024)m") "exact $gb GB conversion"
            Check ($parsed.Data.vmArgs[1] -ceq '-Xms1024m') 'retains valid Xms'
            Check ($plan.Text -ceq $original.Replace('-Xmx3072m',"-Xmx$($gb*1024)m")) 'no unrelated text changes'
            $backups=Join-Path $work 'backups'
            $result=Save-MemoryPlan $config $plan $backups 'set' {}
            $after=Read-PzConfiguration $config.Path
            Check $result.Changed 'applied'
            Check ($after.Bom -eq $bom) 'encoding preserved'
            Check ((Get-BytesHash ([IO.File]::ReadAllBytes($result.BackupPath))) -ceq $config.Hash) 'byte-exact original backup'
            $again=Save-MemoryPlan $after (New-MemoryPlan $after $gb) $backups 'set' {}
            Check (-not $again.Changed) 'repeat apply is no-op'
            $saved=Get-LatestMemoryBackup $config.Path $backups
            Check ($saved.Hash -ceq $config.Hash) 'correct per-install restore source'
            $restore=New-RestorePlan $after $saved
            [void](Save-MemoryPlan $after $restore $backups 'restore' {})
            Check ((Read-PzConfiguration $config.Path).Hash -ceq $config.Hash) 'restores exact bytes when game unchanged'
            Check ((Get-LatestMemoryBackup $config.Path $backups).Hash -ceq $config.Hash) 'repeat restore does not toggle'
        }
    }
    # Backups from a previous game version must not undo new classpaths, JVM flags or metadata.
    $cfg=Write-Fixture 'updated-version' $original
    $backups=Join-Path $work 'updated-backups'
    [void](Save-MemoryPlan $cfg (New-MemoryPlan $cfg 12) $backups 'set' {})
    $updated=(Fixture @('-Xmx12288m','-Xms1024m','-XX:+UseG1GC','-Dnew=true') 'NEW VERSION').Replace('java/projectzomboid.jar','java/new-engine.jar')
    [IO.File]::WriteAllText($cfg.Path,$updated,$utf8)
    $cfg=Read-PzConfiguration $cfg.Path
    $plan=New-RestorePlan $cfg (Get-LatestMemoryBackup $cfg.Path $backups)
    Check ($plan.Text -ceq $updated.Replace('-Xmx12288m','-Xmx3072m')) 'restore preserves Steam-updated content'
    # Round-trip restoration when the original had no explicit heap options.
    foreach ($VmArguments in @(@(),@('-Dfoo=1'),@('-Xms1024m'),@('-Dfoo=1','-Xms1024m'),@('-Xms1024m','-Dfoo=1'))) {
        $cfg=Write-Fixture ('missing-'+[Guid]::NewGuid().ToString('N')) (Fixture $VmArguments)
        $plan=New-MemoryPlan $cfg 8
        $newCfg=[pscustomobject]@{ Document=(Read-PzText $plan.Text) }
        $restored=Read-PzText (New-RestorePlan $newCfg $cfg).Text
        Check (($restored.Data.vmArgs -join '|') -ceq ($VmArguments -join '|')) 'restore absent Xmx without dangling commas'
    }
    foreach ($VmArguments in @(@('-Xmx16g','-Xms12g'),@('-Xms12g','-Xmx16g'),@('-Da=x','-Xmx16g','-Xms12g','-Db=y'))) {
        $cfg=Write-Fixture ('large-initial-'+[Guid]::NewGuid().ToString('N')) (Fixture $VmArguments)
        $plan=New-MemoryPlan $cfg 8
        $doc=Read-PzText $plan.Text
        Check ($doc.Data.vmArgs -contains '-Xms1024m') 'oversized initial heap adjusted'
        Check ([bool]$plan.Note) 'initial-heap change disclosed'
        $without=Write-Fixture ('no-heaps-'+[Guid]::NewGuid().ToString('N')) (Fixture @('-Da=x','-Db=y'))
        $restored=Read-PzText (New-RestorePlan ([pscustomobject]@{ Document=$doc }) $without).Text
        Check (@($restored.Data.vmArgs | Where-Object {$_ -cmatch '^-Xm[xs]'}).Count -eq 0) 'adjacent heap removal valid'
    }
    foreach ($unit in @('-Xmx8g','-Xmx8G','-Xmx8192m','-Xmx8192M','-Xmx8388608k','-Xmx8589934592')) {
        Check ((Convert-HeapSize $unit) -eq 8GB) "unit conversion $unit"
    }
    Reject { New-MemoryPlan $cfg 9 } 'unsupported setting'
    foreach ($VmArguments in @(@('-Xmx8g','-Xmx12g'),@('-Xmx8g','-XX:MaxHeapSize=12g'),@('-XmxBAD'),@('-Xmsx'))) {
        Reject { Read-PzText (Fixture $VmArguments) } 'ambiguous heap rejected'
    }
    Reject { Read-PzText '{broken' } 'broken JSON rejected'
    Reject { Read-PzText $original.Replace('gameStates/MainScreenState','network/GameServer') } 'dedicated server untouched'
    Reject { Read-PzText $original.Replace('"vmArgs": [','"vmArgs": [123,') } 'nonstring vmArgs rejected'
    $cfg=Write-Fixture 'concurrent-change' $original
    $plan=New-MemoryPlan $cfg 8
    $changed=$original.Replace('-Xmx3072m','-Xmx6g')
    [IO.File]::WriteAllText($cfg.Path,$changed,$utf8)
    Reject { Save-MemoryPlan $cfg $plan $backups 'set' {} } 'concurrent edit detected'
    Check ([IO.File]::ReadAllText($cfg.Path) -ceq $changed) 'concurrent edit retained'
    Check (@(Get-ChildItem -LiteralPath (Split-Path $cfg.Path) -Filter '*.tmp').Count -eq 0) 'failure removes temp only'
    $cfg=Write-Fixture 'running-game' $original
    Reject { Save-MemoryPlan $cfg (New-MemoryPlan $cfg 8) $backups 'set' { throw 'game running' } } 'last-moment game guard'
    Check ((Read-PzConfiguration $cfg.Path).Hash -ceq $cfg.Hash) 'running game config unchanged'
    Check ($null -eq (Get-LatestMemoryBackup $cfg.Path $backups)) 'failed write not a successful restore index'
    $result=Save-MemoryPlan $cfg (New-MemoryPlan $cfg 8) $backups 'set' {}
    [IO.File]::WriteAllText($result.BackupPath,$original+' ',$utf8)
    Check ($null -eq (Get-LatestMemoryBackup $cfg.Path $backups)) 'tampered backup ignored'
    foreach ($gb in @(8,10,12,14,16)) {
        Check (-not (Get-MemoryAdvice $gb 32GB).Block) "all requested choices available on 32 GB: $gb"
        Check (Get-MemoryAdvice $gb 8GB).Block "8 GB computer does not exhaust RAM: $gb"
    }
    Check (Get-MemoryAdvice 14 16GB).Confirm 'low reserve confirmation'
    Check (Get-MemoryAdvice 8 0).Confirm 'unknown RAM confirmation'
    Check (-not (Get-MemoryAdvice 8 16GB).Confirm) 'ordinary 8 of 16 GB single apply'
    $vdf='"libraryfolders" { "0" { "path" "C:\\Program Files (x86)\\Steam" } "1" { "path" "D:\\遊戲庫" } }'
    $paths=@(Get-SteamLibraryPaths $vdf)
    Check ($paths.Count -eq 2 -and $paths[1] -ceq 'D:\遊戲庫') 'modern Steam VDF and Chinese directory'
    Check (@(Get-SteamLibraryPaths '"1" "D:\\SteamLibrary"').Count -eq 1) 'legacy Steam VDF'
    $steam=Join-Path $work 'Steam'
    $game=Join-Path $steam 'steamapps/common/Custom Zomboid'
    [void][IO.Directory]::CreateDirectory($game)
    [IO.File]::WriteAllText((Join-Path $game 'ProjectZomboid64.json'),$windowsText,$utf8)
    [IO.File]::WriteAllText((Join-Path $steam 'steamapps/appmanifest_108600.acf'),'"AppState" { "installdir" "Custom Zomboid" }',$utf8)
    $candidates=@(Get-PzCandidates @($steam) @($game))
    Check ($candidates.Count -eq 1 -and $candidates[0] -eq $game) 'manifest install discovery deduplicated'
    Check (Test-PzProcess @([pscustomobject]@{Name='ProjectZomboid64.exe';CommandLine=$null})) 'native game process'
    Check (Test-PzProcess @([pscustomobject]@{Name='javaw.exe';CommandLine='java zombie.gameStates.MainScreenState'})) 'Java alternate launch process'
    Check (-not (Test-PzProcess @([pscustomobject]@{Name='java.exe';CommandLine='java minecraft.Main'}))) 'unrelated Java allowed'
    Reject { Test-PzProcess @([pscustomobject]@{Name='java.exe';CommandLine=$null}) } 'unknown Java fails closed'
    Write-Output "PASS $script:checks compiled C# core checks: all capacities, nested Windows vmArgs, JSON structure, conflicts, file writes, exact backups, restore across updates, repeat use, UTF-8 BOM, Chinese paths, Xms, stale files, failure cleanup, RAM advice, Steam discovery and process guards."
    Write-Output ('Core test runtime: '+[Runtime.InteropServices.RuntimeInformation]::OSDescription+'; '+[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)
    Write-Output 'This suite does not perform interactive Windows UI, antivirus or game-launch tests.'
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
