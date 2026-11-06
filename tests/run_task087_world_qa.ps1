param([Parameter(Mandatory=$true)][string]$GodotBin)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $root 'client'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$priorApiUrl = $env:ELDORIA_PG_API_URL
$priorSavePath = $env:ELDORIA_SAVE_PATH
$priorWsBind = $env:ELDORIA_WS_BIND
$env:ELDORIA_PG_API_URL = ''
$env:ELDORIA_SAVE_PATH = ''
$env:ELDORIA_WS_BIND = '127.0.0.1'
function Start-Check([string]$Name, [string[]]$Arguments) {
    Start-Process -FilePath $GodotBin -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/task087-$Name.log" -RedirectStandardError "$logs/task087-$Name.err"
}
function Finish-Check([string]$Name, $Process, [int]$Timeout=60) {
    if (-not $Process.WaitForExit($Timeout*1000)) {
        Stop-Process -Id $Process.Id -ErrorAction SilentlyContinue
        throw "$Name timed out; see task087-$Name logs"
    }
    $Process.Refresh()
    $errors = @(Select-String -Path "$logs/task087-$Name.log","$logs/task087-$Name.err" -Pattern 'SCRIPT ERROR|ERROR:|Parse Error|FAIL|Assertion failed')
    $results.Add(@{test=$Name;exit_code=$Process.ExitCode;errors=$errors.Count})
    Write-Output "$Name exit=$($Process.ExitCode) errors=$($errors.Count)"
    if ($Process.ExitCode -ne 0 -or $errors.Count -gt 0) {
        $errors | Select-Object -First 5 | ForEach-Object { Write-Output $_.Line }
        throw "$Name failed"
    }
}
function Run-Check([string]$Name, [string[]]$Arguments) {
    $process = Start-Check $Name $Arguments
    Finish-Check $Name $process
}
try {
    Run-Check 'import' @('--headless','--path',$project,'--editor','--import')
    Run-Check 'scene' @('--headless','--path',$project,'--quit-after','90','--','--test')
    foreach ($test in @('collision_perf_e2e','task037_collision_benchmark','task075_mana_herb_world_e2e','task087_world_contract')) {
        Run-Check $test @('--headless','--path',$project,'--script',"res://tests/$test.gd",'--','--test')
    }
    foreach ($test in @('forest_resource_visual_e2e','task063_atmosphere_e2e')) {
        Run-Check $test @('--path',$project,'--rendering-method','gl_compatibility','--script',"res://tests/$test.gd",'--','--test')
    }
    $previousSave = $env:ELDORIA_SAVE_PATH
    $env:ELDORIA_SAVE_PATH = Join-Path $logs ("task087-save-"+[guid]::NewGuid().ToString()+'.json')
    try {
        Run-Check 'depletion-save' @('--headless','--path',$project,'--script','res://tests/forest_depletion_persistence_e2e.gd','--','--test')
        Run-Check 'depletion-restore' @('--headless','--path',$project,'--script','res://tests/forest_depletion_persistence_e2e.gd','--','--restored')
    } finally { $env:ELDORIA_SAVE_PATH = $previousSave }
    foreach ($protocol in @('resource','websocket')) {
        $arguments = @('--headless','--path',$project,'--','--dedicated-server')
        if ($protocol -eq 'websocket') { $arguments += '--websocket' }
        $server = Start-Check "$protocol-server" $arguments
        $clientA = $null
        $clientB = $null
        try {
            Start-Sleep -Milliseconds 1200
            $clientA = Start-Check "$protocol-a" @('--headless','--path',$project,'--script',"res://tests/${protocol}_e2e.gd",'--','--a')
            Start-Sleep -Milliseconds 500
            $clientB = Start-Check "$protocol-b" @('--headless','--path',$project,'--script',"res://tests/${protocol}_e2e.gd",'--','--b')
            Finish-Check "$protocol-a" $clientA 45
            Finish-Check "$protocol-b" $clientB 45
            $serverErrors = @(Select-String -Path "$logs/task087-$protocol-server.log","$logs/task087-$protocol-server.err" -Pattern 'SCRIPT ERROR|ERROR:|FAIL')
            if ($serverErrors.Count) { throw "$protocol server errors" }
        } finally {
            foreach ($process in @($clientA,$clientB,$server)) {
                if ($null -ne $process -and -not $process.HasExited) { Stop-Process -Id $process.Id }
            }
        }
    }
} finally {
    $env:ELDORIA_PG_API_URL = $priorApiUrl
    $env:ELDORIA_SAVE_PATH = $priorSavePath
    $env:ELDORIA_WS_BIND = $priorWsBind
    $results | ConvertTo-Json | Set-Content "$logs/task087-results.json"
}
