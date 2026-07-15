param(
    [Parameter(Mandatory = $true)]
    [int]$ProcessId,
    [Parameter(Mandatory = $true)]
    [string]$Package,
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [Parameter(Mandatory = $true)]
    [string]$Relaunch,
    [switch]$NoRelaunch
)

$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP ("SalesCrmInstaller\" + [guid]::NewGuid().ToString('N'))
$log = Join-Path $env:TEMP 'sales-crm-update.log'

try {
    $deadline = (Get-Date).AddSeconds(60)
    while (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
        if ((Get-Date) -ge $deadline) {
            throw 'برنامه در زمان تعیین شده بسته نشد.'
        }
        Start-Sleep -Milliseconds 250
    }

    if (-not (Test-Path -LiteralPath $Package -PathType Leaf)) {
        throw 'بسته به روزرسانی دانلودشده پیدا نشد.'
    }
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        throw 'پوشه نصب برنامه پیدا نشد.'
    }

    $staging = Join-Path $work 'staging'
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    Expand-Archive -LiteralPath $Package -DestinationPath $staging -Force

    # The old self-contained updater was about 67 MB and is obsolete from
    # 0.0.7-alpha onward. Remove it after the CRM process has stopped.
    $legacyUpdater = Join-Path $Target 'sales_crm_updater.exe'
    if (Test-Path -LiteralPath $legacyUpdater) {
        Remove-Item -LiteralPath $legacyUpdater -Force
    }

    Copy-Item -Path (Join-Path $staging '*') -Destination $Target -Recurse -Force
    if (-not $NoRelaunch) {
        Start-Process -FilePath $Relaunch `
            -WorkingDirectory (Split-Path -Parent $Relaunch) `
            -WindowStyle Normal
    }

    Remove-Item -LiteralPath $Package -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}
catch {
    $message = $_.Exception.Message
    "$(Get-Date -Format o) $message" | Set-Content -LiteralPath $log -Encoding UTF8
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            'به روزرسان فروش یار CRM',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    catch {
        # The log remains available when a graphical error dialog is unavailable.
    }
    exit 1
}
