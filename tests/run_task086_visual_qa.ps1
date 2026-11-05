param(
    [Parameter(Mandatory=$true)][string]$GodotBin,
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
function Invoke-GodotCheck([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $logs "task086-$Name.log"
    & $GodotBin @Arguments *> $log
    $code = $LASTEXITCODE
    $errors = Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:|Parse Error|FAIL'
    Write-Output "$Name exit=$code errors=$($errors.Count)"
    if ($code -ne 0 -or $errors) {
        $errors | Select-Object -First 5 | ForEach-Object { Write-Output $_.Line }
        throw "Godot check failed: $Name. See $log"
    }
}
$project = Join-Path $root 'client'
Invoke-GodotCheck 'import' @('--headless', '--path', $project, '--editor', '--quit')
foreach ($test in @('task086_events', 'task086_effects', 'task086_creatures',
    'animated_actor', 'camera_profile', 'task057_animation_action',
    'task076_wolf_windup', 'task061_rigged_wolf', 'task048_passive',
    'task072_equipment_validation', 'task073_staff_ui')) {
    Invoke-GodotCheck $test @('--headless', '--path', $project, '--script', "res://tests/${test}_e2e.gd")
}
if ($Render) {
    foreach ($test in @('task035_interaction', 'task056_combat_vfx', 'task062_game_audio')) {
        Invoke-GodotCheck $test @('--path', $project, '--rendering-method', 'gl_compatibility', '--script', "res://tests/${test}_e2e.gd")
    }
    foreach ($profile in @('high', 'low')) {
        $output = Join-Path $PSScriptRoot "artifacts/task086/$profile"
        $arguments = @('--path', $project, '--rendering-method', 'gl_compatibility',
            'res://visual_fx/Preview.tscn', '--', "--capture-dir=$output")
        if ($profile -eq 'low') { $arguments += '--low' }
        Invoke-GodotCheck "preview-$profile" $arguments
    }
}
