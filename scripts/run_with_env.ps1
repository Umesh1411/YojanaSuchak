# Helper: run Flutter with .env values passed as --dart-define
# Usage: .\scripts\run_with_env.ps1 (will read .env from project root)

Param(
    [string]$Target = 'run'
)

if (-not (Test-Path '.env')) {
    Write-Host 'No .env file found. Create .env (copy from .env.example) and add GEMINI_API_KEY.' -ForegroundColor Yellow
    exit 1
}

# Read .env lines
$envText = Get-Content .env | Where-Object { $_ -and -not $_.Trim().StartsWith('#') }
$dict = @{}
foreach ($line in $envText) {
    $parts = $line -split '=', 2
    if ($parts.Length -eq 2) {
        $k = $parts[0].Trim()
        $v = $parts[1].Trim()
        if ($v -ne '') { $dict[$k] = $v }
    }
}

$defines = @()
if ($dict.ContainsKey('GEMINI_API_KEY')) { $defines += "--dart-define=GEMINI_API_KEY=$($dict['GEMINI_API_KEY'])" }
if ($dict.ContainsKey('GEMINI_MODEL')) { $defines += "--dart-define=GEMINI_MODEL=$($dict['GEMINI_MODEL'])" }

if ($defines.Count -eq 0) {
    Write-Host 'No dart-define values found in .env (GEMINI_API_KEY or GEMINI_MODEL).' -ForegroundColor Yellow
    exit 1
}

# Run flutter with defines
$cmd = "flutter $Target $($defines -join ' ')"
Write-Host "Running: $cmd"
Invoke-Expression $cmd
