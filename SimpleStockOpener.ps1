<#
  SimpleStockOpener.ps1 — Minimal, from-scratch script
  Behavior:
    - Every ticker opens a brand-new Firefox window
    - Tabs in exact order: Yahoo (focused), Zacks, Finviz
    - Same behavior for successive tickers
  Usage:
    - Run the script, then enter tickers when prompted
    - Press Enter on an empty line to exit
#>

$ErrorActionPreference = 'Stop'

function Get-FirefoxPath {
  # 1) Respect explicit env var
  if ($env:FIREFOX -and (Test-Path $env:FIREFOX)) { return $env:FIREFOX }

  # 2) Windows App Paths registry (most reliable)
  $appPathKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe'
  )
  foreach ($k in $appPathKeys) {
    try {
      $exe = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue)."(default)"
      if ($exe -and (Test-Path $exe)) { return $exe }
    } catch {}
  }

  # 3) Mozilla registry
  $mozRoots = @('HKLM:\SOFTWARE\Mozilla\Mozilla Firefox', 'HKLM:\SOFTWARE\WOW6432Node\Mozilla\Mozilla Firefox')
  foreach ($root in $mozRoots) {
    try {
      $cv = (Get-ItemProperty -Path $root -ErrorAction SilentlyContinue).CurrentVersion
      if ($cv) {
        $main = Join-Path $root "$cv\Main"
        $exe = (Get-ItemProperty -Path $main -ErrorAction SilentlyContinue).PathToExe
        if ($exe -and (Test-Path $exe)) { return $exe }
      }
    } catch {}
  }

  # 4) Typical install locations
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Firefox\firefox.exe')
  )
  foreach ($p in $candidates) { if ($p -and (Test-Path $p)) { return $p } }

  # 5) Fallback: try PATH or prompt the user
  Write-Host 'Firefox not found automatically.' -ForegroundColor Yellow
  $manual = Read-Host 'Enter full path to firefox.exe, or press Enter to try "firefox" from PATH'
  if ($manual) {
    if (Test-Path $manual) { return $manual }
    throw "Provided path does not exist: $manual"
  }
  return 'firefox'  # rely on PATH
}

function New-RunProfilePath {
  $root = Join-Path $env:TEMP 'StockOpenerRuns'
  if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root | Out-Null }
  $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss_fff')
  $dir = Join-Path $root ("run_{0}" -f $stamp)
  New-Item -ItemType Directory -Path $dir | Out-Null
  return $dir
}

function Write-UserJs($profileDir) {
  $userJs = @"
user_pref("browser.link.open_newwindow", 3);
user_pref("browser.link.open_newwindow.restriction", 0);
// Keep additional tabs in background so Yahoo stays focused
user_pref("browser.tabs.loadInBackground", true);
user_pref("browser.tabs.loadDivertedInBackground", true);
// Append tabs at the end to preserve Yahoo, Zacks, Finviz order
user_pref("browser.tabs.insertRelatedAfterCurrent", false);
user_pref("browser.tabs.insertAfterCurrent", false);
// Tame first-run noise
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);
// Suppress about:welcome and any first-run homepage overrides
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.page", 1);
"@
  Set-Content -Encoding ASCII -Path (Join-Path $profileDir 'user.js') -Value $userJs
}

function Open-Ticker([string]$Ticker) {
  $Ticker = ($Ticker -replace '\s','').ToUpper()
  if ($Ticker -notmatch '^[A-Z0-9]{1,10}$') {
    Write-Warning "Invalid ticker. Use 1-10 letters/numbers."
    return
  }

  $fx = Get-FirefoxPath
  $profile = New-RunProfilePath
  Write-UserJs $profile

  $y = "https://finance.yahoo.com/quote/$Ticker"
  $z = "https://www.zacks.com/stock/quote/$Ticker"
  $f = "https://finviz.com/quote.ashx?t=$Ticker"

  # Launch an isolated Firefox instance; Yahoo first, others as tabs in same new window
  Start-Process -FilePath $fx -ArgumentList @(
    '-new-instance','-no-remote','-profile', $profile,
    '-new-window', $y,
    '-new-tab',    $z,
    '-new-tab',    $f
  ) | Out-Null
}

# Interactive loop
while ($true) {
  $t = Read-Host 'Enter ticker (blank = exit)'
  if (-not $t) { break }
  Open-Ticker $t
}
