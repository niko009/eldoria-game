param(
    [Parameter(Mandatory=$false)][string]$GameDir = $PSScriptRoot,
    [Parameter(Mandatory=$false)][int]$WaitForPid = 0,
    [switch]$TestOnly
)
# Bundled with Eldoria, never execute code obtained from the manifest.
# One script handles first launch, in-game auto-update, rollback and restart.
$ErrorActionPreference = 'Stop'
$manifestUrl = 'https://bacus.dev/projects/eldoria/latest.json'
$folder = [IO.Path]::GetFullPath($GameDir)
$versionPath = Join-Path $folder 'version.txt'
$stage = Join-Path ([IO.Path]::GetTempPath()) ('eldoria-update-' + [Guid]::NewGuid().ToString('N'))
$backup = Join-Path $stage 'backup'
function Log([string]$message) { Write-Host ('[Eldoria updater] ' + $message) }
function Read-Version {
    if (!(Test-Path $versionPath)) { return [version]'0.0.0' }
    try { return [version](Get-Content -LiteralPath $versionPath -Raw).Trim() }
    catch { return [version]'0.0.0' }
}
function Require-Release([object]$m) {
    if ($m.schema -ne 1) { throw 'Unsupported release manifest' }
    if (($m.version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$')) { throw 'Invalid release version' }
    $wanted = "https://bacus.dev/projects/eldoria/Eldoria-Windows-$($m.version).zip"
    if ($m.windows.url -cne $wanted) { throw 'Unexpected release URL' }
    if ($m.windows.sha256 -cnotmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid checksum' }
    if ([long]$m.windows.bytes -lt 50000 -or [long]$m.windows.bytes -gt 300000000) { throw 'Invalid archive size' }
}
try {
    Log "Checking $manifestUrl"
    $release = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 20
    Require-Release $release
    $latest = [version]$release.version
    $current = Read-Version
    if ($current -ge $latest) {
        Log "Current version $current is up to date"
    } else {
        Log "Updating $current -> $latest"
        New-Item -ItemType Directory -Path $stage -Force | Out-Null
        $archive = Join-Path $stage 'release.zip'
        Invoke-WebRequest -Uri $release.windows.url -OutFile $archive -TimeoutSec 120
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actualHash -ine $release.windows.sha256) { throw 'Release hash mismatch' }
        if ((Get-Item $archive).Length -ne [long]$release.windows.bytes) { throw 'Archive size mismatch' }
        $expanded = Join-Path $stage 'new'
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
        foreach ($name in @('Eldoria.exe','Eldoria.pck','EldoriaUpdater.ps1')) {
            if (!(Test-Path -LiteralPath (Join-Path $expanded $name) -PathType Leaf)) {
                throw "Missing release component: $name"
            }
        }
        if ($TestOnly) {
            Log 'TEST PASS: downloaded archive and verified checksum, bytes and contents'
            exit 0
        }
        if ($WaitForPid -gt 0) {
            # A running EXE cannot be replaced. Wait for it to exit.
            try { Wait-Process -Id $WaitForPid -Timeout 25 -ErrorAction Stop } catch { Start-Sleep -Milliseconds 500 }
        }
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        $names = @('Eldoria.exe','Eldoria.pck','EldoriaUpdater.ps1','README.txt')
        foreach ($name in $names) {
            $dest = Join-Path $folder $name
            if (Test-Path -LiteralPath $dest) { Copy-Item -LiteralPath $dest -Destination (Join-Path $backup $name) -Force }
        }
        try {
            foreach ($name in $names) {
                $src = Join-Path $expanded $name
                if (Test-Path -LiteralPath $src) {
                    Copy-Item -LiteralPath $src -Destination (Join-Path $folder $name) -Force
                }
            }
            Set-Content -LiteralPath $versionPath -Value ([string]$latest) -NoNewline -Encoding ascii
            Log "Installed v$latest"
        } catch {
            foreach ($name in $names) {
                $old = Join-Path $backup $name
                if (Test-Path -LiteralPath $old) { Copy-Item -LiteralPath $old -Destination (Join-Path $folder $name) -Force }
            }
            throw
        }
    }
    if (-not $TestOnly) {
        Start-Process -FilePath (Join-Path $folder 'Eldoria.exe') -WorkingDirectory $folder
    }
} catch {
    Log "ERROR: $($_.Exception.Message)"
    if (-not $TestOnly -and (Test-Path (Join-Path $folder 'Eldoria.exe'))) {
        Log 'Starting existing version; download current ZIP manually if the error persists.'
        Start-Process -FilePath (Join-Path $folder 'Eldoria.exe') -WorkingDirectory $folder
    }
    exit 1
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
