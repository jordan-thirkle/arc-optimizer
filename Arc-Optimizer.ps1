Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management
[System.Windows.Forms.Application]::EnableVisualStyles()

# ═══════════════════════════════════════════════════════════════
# ARC OPTIMIZER v1.1 — Arc Raiders Competitive Config Tool
# ═══════════════════════════════════════════════════════════════
# Microsoft Store ready — privacy policy, error handling, clean uninstall
# ═══════════════════════════════════════════════════════════════

$Script:Version = "1.1.0"
$Script:PrivacyAccepted = $false

# ── PRIVACY CONSENT (first run) ──
function Show-PrivacyConsent {
  $consentPath = "$env:LOCALAPPDATA\ArcOptimizer\privacy.consent"
  if (Test-Path $consentPath) { $Script:PrivacyAccepted = $true; return }

  $msg = "Arc Optimizer v$Script:Version`n`n" +
    "This tool modifies ARC Raiders game configuration files locally.`n" +
    "It does NOT collect, transmit, or store any personal data.`n" +
    "No network connections are made.`n`n" +
    "Full privacy policy: https://github.com/jordan-thirkle/arc-optimizer/blob/main/PRIVACY.md`n`n" +
    "By clicking Accept, you agree to use this tool at your own risk.`n" +
    "Game config files will be modified with automatic backups."

  $result = [Windows.Forms.MessageBox]::Show($msg, "Arc Optimizer — Privacy Notice", "OKCancel", "Information")
  if ($result -eq "OK") {
    New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\ArcOptimizer" -Force | Out-Null
    Set-Content -Path $consentPath -Value "Accepted" -Encoding UTF8
    $Script:PrivacyAccepted = $true
  } else {
    [Windows.Forms.MessageBox]::Show("Privacy consent required to run Arc Optimizer.", "Consent Required", "OK", "Error")
    [Environment]::Exit(0)
  }
}

# ── COMMAND-LINE HANDLING ──
function Invoke-Cleanup {
  param([switch]$Uninstall)
  if (-not $Uninstall) { return }

  $r = [Windows.Forms.MessageBox]::Show(
    "This will:`n" +
    "- Remove Engine.ini (if present)`n" +
    "- Remove read-only flag from GameUserSettings.ini`n" +
    "- Remove ArcOptimizer_Backups folder (if you choose)`n`n" +
    "Your game settings will NOT be changed. Continue?",
    "Arc Optimizer — Clean Uninstall", "YesNo", "Question"
  )
  if ($r -ne "Yes") { return }

  $log = @()
  $enginePath = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\Engine.ini"
  if (Test-Path $enginePath) {
    attrib -R $enginePath 2>$null
    Remove-Item $enginePath -Force -ErrorAction SilentlyContinue
    $log += "Removed: Engine.ini"
  }
  $cfgPath = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\GameUserSettings.ini"
  if (Test-Path $cfgPath) {
    attrib -R $cfgPath 2>$null
    $log += "Removed read-only: GameUserSettings.ini"
  }
  $bakPath = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\ArcOptimizer_Backups"
  if (Test-Path $bakPath) {
    $r2 = [Windows.Forms.MessageBox]::Show("Remove backup folder ($bakPath)?", "Backups", "YesNo", "Question")
    if ($r2 -eq "Yes") {
      Remove-Item $bakPath -Recurse -Force -ErrorAction SilentlyContinue
      $log += "Removed: ArcOptimizer_Backups"
    }
  }
  $consentPath = "$env:LOCALAPPDATA\ArcOptimizer\privacy.consent"
  if (Test-Path $consentPath) {
    Remove-Item $consentPath -Force -ErrorAction SilentlyContinue
  }

  [Windows.Forms.MessageBox]::Show(($log -join "`n"), "Cleanup Complete", "OK", "Information")
  [Environment]::Exit(0)
}

# Check for command-line flags
if ($args -contains "-Uninstall" -or $args -contains "--uninstall") {
  Invoke-Cleanup -Uninstall
}

# Show privacy consent before UI
Show-PrivacyConsent

# ── ARCADIA COLOR PALETTE (Arc Raiders inspired) ──
$C = @{
  bg      = "#0A0E17"
  card    = "#111827"
  inner   = "#1A2332"
  border  = "#1E2D3D"
  text    = "#E2E8F0"
  sec     = "#94A3B8"
  dim     = "#64748B"
  accent  = "#00E5FF"   # Arc Raiders cyan
  accent2 = "#00B4D8"
  green   = "#10B981"
  yellow  = "#F59E0B"
  red     = "#EF4444"
  orange  = "#F97316"
}

function Hex($h) {
  return [System.Drawing.Color]::FromArgb(255,
    [Int32]::Parse($h.Substring(1,2),"HexNumber"),
    [Int32]::Parse($h.Substring(3,2),"HexNumber"),
    [Int32]::Parse($h.Substring(5,2),"HexNumber"))
}

# ── PATHS ──
$Paths = @{
  Config  = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\GameUserSettings.ini"
  Engine  = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\Engine.ini"
  Backup  = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\ArcOptimizer_Backups"
  Steam   = "D:\SteamLibrary\steamapps\common\ARC Raiders\start_protected_game.exe"
  WinGDK  = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WinGDKClient\GameUserSettings.ini"
}

# ── SYSTEM DETECTION ──
function Get-GPU {
  try {
    $s = & "nvidia-smi" "--query-gpu=name,driver_version,memory.total,temperature.gpu,power.draw,clocks.current.graphics,clocks.current.memory" "--format=csv,noheader" 2>$null
    if ($LASTEXITCODE -eq 0 -and $s) {
      $p = $s.Trim() -split ", "
      return @{Name=$p[0];Driver=$p[1];VRAM=$p[2];Temp=$p[3];Power=$p[4];CoreClock=$p[5];MemClock=$p[6]}
    }
  } catch {}
  return $null
}

function Get-RTX {
  if (-not (Test-Path $Paths.Config)) { return "N/A" }
  $c = Get-Content $Paths.Config -Raw -ErrorAction SilentlyContinue
  if ($c -match "NvReflexMode=Boost") { return "On + Boost" }
  if ($c -match "NvReflexMode=On") { return "On" }   ; return "Off"
}

function Get-Power {
  $p = powercfg /getactivescheme 2>$null
  if ($p -match "AMD Ryzen High Performance") { return "Ryzen High Perf", $true }
  if ($p -match "High Performance") { return "High Performance", $true }
  if ($p -match "Balanced") { return "Balanced", $false }; return "Unknown", $false
}

function Get-AudioCount {
  try { return @(Get-CimInstance Win32_PnPEntity | Where-Object {$_.Name -match 'Headphone|Speaker|Realtek|27G2' -and $_.PNPClass -eq 'AudioEndpoint'} | Select-Object -ExpandProperty Name).Count }
  catch { return 0 }
}

function Get-CfgDir {
  if (Test-Path $Paths.Config) { return $Paths.Config }
  if (Test-Path $Paths.WinGDK) { return $Paths.WinGDK }
  return $null
}

function New-Backup {
  $cfg = Get-CfgDir
  if (-not $cfg) { return $null }
  New-Item -ItemType Directory -Path $Paths.Backup -Force | Out-Null
  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  $name = [System.IO.Path]::GetFileNameWithoutExtension($cfg)
  Copy-Item $cfg "$($Paths.Backup)\$name.$ts.bak" -Force
  return $ts
}

function Get-Backups {
  if (-not (Test-Path $Paths.Backup)) { return @() }
  return @(Get-ChildItem "$($Paths.Backup)\*.bak" | Sort-Object LastWriteTime -Descending | ForEach-Object {$_.Name})
}

# ── OPTIMIZATION ENGINE ──
$SettingMap = [ordered]@{
  "sg.ViewDistanceQuality"       = @{val="3";    label="High";       why="See enemies at longer range";       impact="high"}
  "sg.AntiAliasingQuality"       = @{val="0";    label="Off";        why="DLSS handles AA, free FPS";         impact="low"}
  "sg.ShadowQuality"             = @{val="0";    label="Low";        why="Spot enemies in shadows + FPS";     impact="high"}
  "sg.GlobalIlluminationQuality" = @{val="0";    label="Low";        why="RTXGI is Static anyway";            impact="low"}
  "sg.ReflectionQuality"         = @{val="0";    label="Low";        why="Costs FPS, no gameplay benefit";    impact="med"}
  "sg.PostProcessQuality"        = @{val="0";    label="Low";        why="Removes bloom/lens flare";          impact="med"}
  "sg.TextureQuality"            = @{val="4";    label="Epic";       why="12GB VRAM handles it free";         impact="low"}
  "sg.EffectsQuality"            = @{val="0";    label="Low";        why="Less visual clutter in combat";     impact="med"}
  "sg.FoliageQuality"            = @{val="0";    label="Low";        why="See through bushes - PvP edge";     impact="high"}
  "sg.ShadingQuality"            = @{val="1";    label="Default";    why="Minor visual tweak";                impact="low"}
  "sg.ResolutionQuality"         = @{val="100";  label="100%";       why="Let DLSS handle scaling";           impact="med"}
  "DLSSMode"                     = @{val="Balanced";   label="Balanced";   why="Best FPS/clarity tradeoff";      impact="med"}
  "DLSSModel"                    = @{val="Transformer"; label="Transformer"; why="DLSS 4.5 sharper, less ghosting"; impact="med"}
  "NvReflexMode"                 = @{val="Boost"; label="Boost";     why="Lowest input latency possible";      impact="high"}
  "FrameRateLimit"               = @{val="0";    label="Uncapped";   why="Reflex works best uncapped";         impact="high"}
  "FullscreenMode"               = @{val="0";    label="Exclusive";  why="Lowest input latency mode";          impact="high"}
  "MotionBlurScale"              = @{val="0";    label="Off";        why="Eliminates blur during movement";    impact="med"}
  "LensDistortionEnabled"        = @{val="False";label="Off";        why="Cleaner view without fisheye";       impact="low"}
  "RTXGIQuality"                 = @{val="Static";label="Static";    why="RT ray tracing kills FPS";           impact="high"}
  "RTXGIResolutionQuality"       = @{val="0";    label="Off";        why="Free FPS with no visual loss";       impact="med"}
  "PerformanceOverlayMode"       = @{val="FPS";  label="FPS";        why="Monitor performance in real-time";   impact="low"}
  "SecondaryResolutionScalePercentage" = @{val="100"; label="100%";  why="Consistent rendering resolution";    impact="low"}
}

$EngineContent = @"
; Arc Optimizer v1.0 — UE5 Competitive Tweaks
[SystemSettings]
r.DefaultFeature.MotionBlur=0
r.MotionBlurQuality=0
r.MotionBlur.Max=0
r.DefaultFeature.DepthOfField=0
r.DepthOfFieldQuality=0
r.DefaultFeature.Bloom=0
r.BloomQuality=0
r.DefaultFeature.LensFlare=0
r.LensFlareQuality=0
r.Tonemapper.Quality=1
r.Tonemapper.Sharpen=0.5
r.DefaultFeature.AmbientOcclusion=0
r.AmbientOcclusionLevels=0
r.ShadowQuality=0
r.Shadow.MaxResolution=512
r.Shadow.CSM.MaxCascades=1
r.VolumetricFog=0
r.LightShaftQuality=0
r.EyeAdaptationQuality=0
r.SSR.Quality=0
r.DefaultFeature.AntiAliasing=0
r.PostProcessAAQuality=0
r.Streaming.PoolSize=4096
r.Streaming.MaxEffectiveScreenFraction=0.5
"@

function Read-Settings {
  $cfg = Get-CfgDir
  if (-not $cfg) { return @{} }
  $d = @{}
  Get-Content $cfg -Raw -ErrorAction SilentlyContinue -split "`n" | ForEach-Object {
    if ($_ -match "^(sg\.\w+|\w+)=(.+)$") { $d[$matches[1]] = $matches[2].Trim() }
  }
  return $d
}

function Apply-Opt {
  if (-not $Script:PrivacyAccepted) { return @("ERROR: Privacy consent required") }
  $cfg = Get-CfgDir
  if (-not $cfg) { return @("ERROR: Config not found. Launch ARC Raiders once first.") }
  $r = @()
  try { $bk = New-Backup } catch { $bk = $null }
  if ($bk) { $r += "Backup saved: $bk" } else { $r += "No backup needed" }

  try { $c = Get-Content $cfg -Raw } catch { return @("ERROR: Cannot read config file: $($_.Exception.Message)") }
  $o = $c

  $swaps = @{
    "sg.ResolutionQuality=71"          = "sg.ResolutionQuality=100"
    "sg.ViewDistanceQuality=1"         = "sg.ViewDistanceQuality=3"
    "sg.AntiAliasingQuality=1"         = "sg.AntiAliasingQuality=0"
    "sg.ShadowQuality=1"               = "sg.ShadowQuality=0"
    "sg.GlobalIlluminationQuality=1"   = "sg.GlobalIlluminationQuality=0"
    "sg.ReflectionQuality=1"           = "sg.ReflectionQuality=0"
    "sg.PostProcessQuality=1"          = "sg.PostProcessQuality=0"
    "sg.TextureQuality=1"              = "sg.TextureQuality=4"
    "sg.EffectsQuality=1"              = "sg.EffectsQuality=0"
    "sg.FoliageQuality=1"              = "sg.FoliageQuality=0"
    "DLSSMode=Performance"             = "DLSSMode=Balanced"
    "DLSSModel=CNN"                    = "DLSSModel=Transformer"
    "MotionBlurScale=100.000000"       = "MotionBlurScale=0.000000"
    "LensDistortionEnabled=True"       = "LensDistortionEnabled=False"
    "RTXGIResolutionQuality=1"         = "RTXGIResolutionQuality=0"
    "FullscreenMode=1"                 = "FullscreenMode=0"
    "LastConfirmedFullscreenMode=1"    = "LastConfirmedFullscreenMode=0"
    "PreferredFullscreenMode=1"        = "PreferredFullscreenMode=0"
    "FrameRateLimit=165.000000"        = "FrameRateLimit=0.000000"
    "LastUsedSwapchainHookFeature=FSRG"= "LastUsedSwapchainHookFeature=DLSS"
    "NvReflexMode=On"                  = "NvReflexMode=Boost"
    "NvReflexMode=Off"                 = "NvReflexMode=Boost"
    "PerformanceOverlayMode=Detailed"  = "PerformanceOverlayMode=FPS"
    "SecondaryResolutionScalePercentage=98.000000" = "SecondaryResolutionScalePercentage=100.000000"
  }
  foreach ($pair in $swaps.GetEnumerator()) {
    if ($c -match [regex]::Escape($pair.Key)) { $c = $c -replace [regex]::Escape($pair.Key), $pair.Value }
  }
  if ($c -ne $o) {
    Set-Content -Path $cfg -Value $c -NoNewline -Encoding UTF8
    $r += "GameUserSettings.ini updated (22 settings)"
  } else { $r += "Already optimized" }
  attrib +R $cfg 2>$null; $r += "Read-only applied"

  Set-Content -Path $Paths.Engine -Value $EngineContent -Encoding UTF8
  attrib +R $Paths.Engine 2>$null
  $r += "Engine.ini created (motion blur, DoF, bloom, fog, SSR disabled)"

  return $r
}

function Restore-Opt {
  $r = @()
  if (Test-Path $Paths.Engine) { attrib -R $Paths.Engine 2>$null; Remove-Item $Paths.Engine -Force; $r += "Engine.ini removed" }
  $cfg = Get-CfgDir
  if ($cfg) { attrib -R $cfg 2>$null; $r += "Read-only removed" }
  return $r
}

# ═══════════════════════════════════════════════════════════════
# UI BUILDERS
# ═══════════════════════════════════════════════════════════════

function New-Button($t,$bg,$w=160,$h=38) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $t; $b.Size = New-Object Drawing.Size($w,$h)
  $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0
  $b.BackColor = Hex $bg; $b.ForeColor = Hex "#FFFFFF"
  $b.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
  $b.Cursor = "Hand"; $b.FlatAppearance.MouseOverBackColor = Hex "#1E3A5F"
  return $b
}

function New-Card($title) {
  $p = New-Object Windows.Forms.Panel
  $p.Size = New-Object Drawing.Size(172,62)
  $p.BackColor = Hex $C.inner; $p.BorderStyle = "None"

  $l = New-Object Windows.Forms.Label
  $l.Text = $title.ToUpper(); $l.Font = New-Object Drawing.Font("Segoe UI",7.5,[Drawing.FontStyle]::Bold)
  $l.ForeColor = Hex $C.dim; $l.Size = New-Object Drawing.Size(160,14)
  $l.Location = New-Object Drawing.Point(10,6)

  $v = New-Object Windows.Forms.Label
  $v.Name = "cv_$($title -replace ' ')"; $v.Text = "---"
  $v.Font = New-Object Drawing.Font("Segoe UI",11,[Drawing.FontStyle]::Bold)
  $v.ForeColor = Hex $C.text; $v.Size = New-Object Drawing.Size(160,22)
  $v.Location = New-Object Drawing.Point(10,26)
  $v.Tag = ""

  # Status dot
  $dot = New-Object Windows.Forms.Label
  $dot.Name = "cd_$($title -replace ' ')"; $dot.Text = ""
  $dot.Size = New-Object Drawing.Size(8,8)
  $dot.Location = New-Object Drawing.Point(154,10)
  $dot.BackColor = Hex $C.dim

  $p.Controls.Add($l); $p.Controls.Add($v); $p.Controls.Add($dot)
  return $p, $v, $dot
}

function New-RecCard($title,$body,$fix) {
  $p = New-Object Windows.Forms.Panel
  $p.Size = New-Object Drawing.Size(740,72)
  $p.BackColor = Hex $C.inner

  $t = New-Object Windows.Forms.Label
  $t.Text = $title; $t.Font = New-Object Drawing.Font("Segoe UI",9.5,[Drawing.FontStyle]::Bold)
  $t.ForeColor = Hex $C.yellow; $t.Size = New-Object Drawing.Size(720,20)
  $t.Location = New-Object Drawing.Point(12,8)

  $b = New-Object Windows.Forms.Label
  $b.Text = $body; $b.Font = New-Object Drawing.Font("Segoe UI",9)
  $b.ForeColor = Hex $C.sec; $b.Size = New-Object Drawing.Size(720,18)
  $b.Location = New-Object Drawing.Point(12,30)
  $b.AutoSize = $true

  $p.Controls.Add($t); $p.Controls.Add($b)

  if ($fix) {
    $f = New-Object Windows.Forms.Label
    $f.Text = $fix; $f.Font = New-Object Drawing.Font("Consolas",9)
    $f.ForeColor = Hex $C.accent; $f.Size = New-Object Drawing.Size(720,18)
    $f.Location = New-Object Drawing.Point(12, $b.Bottom + 4)
    $f.AutoSize = $true; $p.Controls.Add($f); $p.Height = $b.Bottom + 28
  }
  return $p
}

# ═══════════════════════════════════════════════════════════════
# FORM
# ═══════════════════════════════════════════════════════════════

$form = New-Object Windows.Forms.Form
$form.Text = "Arc Optimizer v$Script:Version  |  Arc Raiders Competitive Config Tool"
$form.Size = New-Object Drawing.Size(1020,740)
$form.MinimumSize = New-Object Drawing.Size(900,660)
$form.StartPosition = "CenterScreen"
$form.BackColor = Hex $C.bg
$form.Icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $pid).MainModule.FileName)

# ── CUSTOM TITLE BAR ──
$titleBar = New-Object Windows.Forms.Panel
$titleBar.Size = New-Object Drawing.Size(1020,56)
$titleBar.BackColor = Hex "#080B12"
$titleBar.Dock = "Top"

# Arc Raiders styled logo
$logo = New-Object Windows.Forms.Label
$logo.Text = "ARC  OPTIMIZER"
$logo.Font = New-Object Drawing.Font("Segoe UI",18,[Drawing.FontStyle]::Bold)
$logo.ForeColor = Hex $C.accent
$logo.Size = New-Object Drawing.Size(320,40)
$logo.Location = New-Object Drawing.Point(20,10)

$ver = New-Object Windows.Forms.Label
$ver.Text = "v1.0"
$ver.Font = New-Object Drawing.Font("Segoe UI",7.5)
$ver.ForeColor = Hex $C.dim
$ver.Size = New-Object Drawing.Size(40,14)
$ver.Location = New-Object Drawing.Point(180,32)

# Status indicator with animated dot
$statDot = New-Object Windows.Forms.Label
$statDot.Name = "statDot"
$statDot.Text = ""
$statDot.Size = New-Object Drawing.Size(10,10)
$statDot.Location = New-Object Drawing.Point(760,24)
$statDot.BackColor = Hex $C.yellow
# Make it circular via paint

$statDot.Add_Paint({
  $g = $_.CreateGraphics()
  $b = New-Object Drawing.SolidBrush($_.BackColor)
  $g.FillEllipse($b, 0, 0, $_.Width-1, $_.Height-1)
  $b.Dispose(); $g.Dispose()
})

$statText = New-Object Windows.Forms.Label
$statText.Name = "statText"
$statText.Text = "INITIALIZING"
$statText.Font = New-Object Drawing.Font("Segoe UI",8.5)
$statText.ForeColor = Hex $C.yellow
$statText.Size = New-Object Drawing.Size(160,20)
$statText.Location = New-Object Drawing.Point(780,20)

$badge = New-Object Windows.Forms.Label
$badge.Text = "OPEN SOURCE"
$badge.Font = New-Object Drawing.Font("Segoe UI",6.5,[Drawing.FontStyle]::Bold)
$badge.ForeColor = Hex $C.dim
$badge.BackColor = Hex "#131A24"
$badge.Size = New-Object Drawing.Size(80,18)
$badge.Location = New-Object Drawing.Point(300,28)
$badge.TextAlign = "MiddleCenter"

# Privacy indicator
$privacyLabel = New-Object Windows.Forms.Label
$privacyLabel.Text = "🔒 NO DATA COLLECTED"
$privacyLabel.Font = New-Object Drawing.Font("Segoe UI",6.5,[Drawing.FontStyle]::Bold)
$privacyLabel.ForeColor = Hex $C.green
$privacyLabel.BackColor = Hex "#0A1A10"
$privacyLabel.Size = New-Object Drawing.Size(120,18)
$privacyLabel.Location = New-Object Drawing.Point(390,28)
$privacyLabel.TextAlign = "MiddleCenter"

$titleBar.Controls.Add($logo); $titleBar.Controls.Add($ver)
$titleBar.Controls.Add($statDot); $titleBar.Controls.Add($statText); $titleBar.Controls.Add($badge)
$titleBar.Controls.Add($privacyLabel)

# ── TAB CONTROL ──
$tab = New-Object Windows.Forms.TabControl
$tab.Size = New-Object Drawing.Size(980,590)
$tab.Location = New-Object Drawing.Point(20,68)
$tab.Font = New-Object Drawing.Font("Segoe UI",9.5)
$tab.Appearance = "Normal"; $tab.Padding = New-Object Drawing.Point(14,6)
$tab.BackColor = Hex $C.bg; $tab.ForeColor = Hex $C.text
$tab.DrawMode = "OwnerDrawFixed"

$tab.Add_DrawItem({
  $g = $_.Graphics; $bg = if ($_.State -band [Windows.Forms.DrawItemState]::Selected) {Hex $C.card}else{Hex $C.bg}
  $fg = if ($_.State -band [Windows.Forms.DrawItemState]::Selected) {Hex $C.accent}else{Hex $C.dim}
  $br = New-Object Drawing.SolidBrush($bg)
  $g.FillRectangle($br, $_.Bounds); $br.Dispose()
  $s = $tab.TabPages[$_.Index].Text
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
  $bf = New-Object Drawing.SolidBrush($fg)
  $r = New-Object Drawing.RectangleF($_.Bounds.X, $_.Bounds.Y, $_.Bounds.Width, $_.Bounds.Height-2)
  $g.DrawString($s, $tab.Font, $bf, $r, $sf)
  # Active tab underline
  if ($_.State -band [Windows.Forms.DrawItemState]::Selected) {
    $p2 = New-Object Drawing.Pen(Hex $C.accent, 2)
    $g.DrawLine($p2, $_.Bounds.X+10, $_.Bounds.Bottom-2, $_.Bounds.Right-10, $_.Bounds.Bottom-2)
    $p2.Dispose()
  }
  $bf.Dispose(); $sf.Dispose()
})

# ═══════════════════════════════════════════════════════════════
# TAB 1: DASHBOARD
# ═══════════════════════════════════════════════════════════════

$tDash = New-Object Windows.Forms.TabPage; $tDash.Text = "  DASHBOARD  "
$tDash.BackColor = Hex $C.bg

$dashP = New-Object Windows.Forms.FlowLayoutPanel
$dashP.Size = New-Object Drawing.Size(960,560); $dashP.AutoScroll = $true
$dashP.BackColor = Hex $C.bg; $dashP.Padding = New-Object Windows.Forms.Padding(14)
$dashP.FlowDirection = "TopDown"; $dashP.WrapContents = $false

# ── HERO OPTIMIZE PANEL ──
$hero = New-Object Windows.Forms.Panel
$hero.Size = New-Object Drawing.Size(920,150)
$hero.BackColor = Hex $C.card

$heroGrad = New-Object Windows.Forms.Panel
$heroGrad.Size = New-Object Drawing.Size(4,150)
$heroGrad.BackColor = Hex $C.accent

$heroTitle = New-Object Windows.Forms.Label
$heroTitle.Text = "Optimize Arc Raiders for Competitive Play"
$heroTitle.Font = New-Object Drawing.Font("Segoe UI",16,[Drawing.FontStyle]::Bold)
$heroTitle.ForeColor = Hex "#FFFFFF"
$heroTitle.Size = New-Object Drawing.Size(600,32); $heroTitle.Location = New-Object Drawing.Point(28,16)

$heroSub = New-Object Windows.Forms.Label
$heroSub.Text = "Applies 22 proven settings. All changes include automatic backups."
$heroSub.Font = New-Object Drawing.Font("Segoe UI",9.5)
$heroSub.ForeColor = Hex $C.sec; $heroSub.Size = New-Object Drawing.Size(600,20)
$heroSub.Location = New-Object Drawing.Point(28,50)

$btnOpt = New-Button "  RUN OPTIMIZATION  " $C.accent 280 48
$btnOpt.Name = "btnOpt"
$btnOpt.Location = New-Object Drawing.Point(28,82)
$btnOpt.Font = New-Object Drawing.Font("Segoe UI",12,[Drawing.FontStyle]::Bold)

$btnRest = New-Button " RESTORE " $C.card 120 36
$btnRest.Name = "btnRest"
$btnRest.Location = New-Object Drawing.Point(324,88)
$btnRest.Font = New-Object Drawing.Font("Segoe UI",9)
$btnRest.ForeColor = Hex $C.sec

$btnTest = New-Button " TEST CONFIG " $C.card 130 36
$btnTest.Name = "btnTest"
$btnTest.Location = New-Object Drawing.Point(456,88)
$btnTest.Font = New-Object Drawing.Font("Segoe UI",9)
$btnTest.ForeColor = Hex $C.sec

$hero.Controls.Add($heroGrad); $hero.Controls.Add($heroTitle)
$hero.Controls.Add($heroSub); $hero.Controls.Add($btnOpt)
$hero.Controls.Add($btnRest); $hero.Controls.Add($btnTest)

# ── STATUS CARDS ROW ──
$statRow = New-Object Windows.Forms.FlowLayoutPanel
$statRow.Size = New-Object Drawing.Size(920,80)
$statRow.BackColor = Hex $C.bg; $statRow.WrapContents = $true

$cardDefs = @("GPU","Driver","VRAM","Reflex","Game","Config","Power","Audio")
$cards = @{}
foreach ($n in $cardDefs) {
  $cp, $cv, $cd = New-Card $n
  $cp.Margin = New-Object Windows.Forms.Padding(3,4,3,4)
  $statRow.Controls.Add($cp); $cards[$n] = @{val=$cv; dot=$cd}
}

# ── RESULTS LOG ──
$log = New-Object Windows.Forms.TextBox
$log.Name = "logBox"
$log.Multiline = $true; $log.ReadOnly = $true
$log.Font = New-Object Drawing.Font("Consolas",9)
$log.ForeColor = Hex $C.text; $log.BackColor = Hex $C.inner
$log.Size = New-Object Drawing.Size(920,120)
$log.BorderStyle = "None"; $log.ScrollBars = "Vertical"
$log.Margin = New-Object Windows.Forms.Padding(0,8,0,0)
$log.Visible = $false

$dashP.Controls.Add($hero); $dashP.Controls.Add($statRow); $dashP.Controls.Add($log)
$tDash.Controls.Add($dashP)

# ═══════════════════════════════════════════════════════════════
# TAB 2: SETTINGS
# ═══════════════════════════════════════════════════════════════

$tSet = New-Object Windows.Forms.TabPage; $tSet.Text = "  SETTINGS  "
$tSet.BackColor = Hex $C.bg

$setP = New-Object Windows.Forms.Panel
$setP.Size = New-Object Drawing.Size(960,560); $setP.AutoScroll = $true
$setP.BackColor = Hex $C.bg

$setH = New-Object Windows.Forms.Label
$setH.Text = "GameUserSettings.ini — 22 Optimized Values"
$setH.Font = New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold)
$setH.ForeColor = Hex $C.text; $setH.Size = New-Object Drawing.Size(500,26)
$setH.Location = New-Object Drawing.Point(16,14)

$setGrid = New-Object Windows.Forms.DataGridView
$setGrid.Size = New-Object Drawing.Size(900,440)
$setGrid.Location = New-Object Drawing.Point(16,50)
$setGrid.BackgroundColor = Hex $C.inner; $setGrid.BorderStyle = "None"
$setGrid.RowHeadersVisible = $false; $setGrid.AllowUserToAddRows = $false
$setGrid.AllowUserToDeleteRows = $false; $setGrid.AllowUserToResizeRows = $false
$setGrid.ReadOnly = $true; $setGrid.CellBorderStyle = "SingleHorizontal"
$setGrid.GridColor = Hex $C.border
$setGrid.ColumnHeadersHeightSizeMode = "AutoSize"
$setGrid.EnableHeadersVisualStyles = $false

$setGrid.ColumnHeadersDefaultCellStyle.BackColor = Hex $C.card
$setGrid.ColumnHeadersDefaultCellStyle.ForeColor = Hex $C.sec
$setGrid.ColumnHeadersDefaultCellStyle.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$setGrid.ColumnHeadersDefaultCellStyle.Alignment = "MiddleLeft"
$setGrid.RowsDefaultCellStyle.BackColor = Hex $C.inner
$setGrid.RowsDefaultCellStyle.ForeColor = Hex $C.text
$setGrid.RowsDefaultCellStyle.SelectionBackColor = Hex $C.card
$setGrid.RowsDefaultCellStyle.SelectionForeColor = Hex $C.text
$setGrid.RowsDefaultCellStyle.Font = New-Object Drawing.Font("Consolas",9)
$setGrid.AlternatingRowsDefaultCellStyle.BackColor = Hex "#141E2C"
$setGrid.Columns.Add("setting","Setting"); $setGrid.Columns.Add("cur","Current")
$setGrid.Columns.Add("opt","Optimized"); $setGrid.Columns.Add("why","Why")
$setGrid.Columns.Add("impact","Impact")
$setGrid.Columns[0].Width = 200; $setGrid.Columns[1].Width = 100
$setGrid.Columns[2].Width = 120; $setGrid.Columns[3].Width = 360
$setGrid.Columns[4].Width = 80

$setBtn = New-Button " Apply Settings " $C.accent 140 34
$setBtn.Name = "setBtn"
$setBtn.Location = New-Object Drawing.Point(16,498)
$setBtn.Font = New-Object Drawing.Font("Segoe UI",9.5)

$setP.Controls.Add($setH); $setP.Controls.Add($setGrid); $setP.Controls.Add($setBtn)
$tSet.Controls.Add($setP)

# ═══════════════════════════════════════════════════════════════
# TAB 3: VISUAL TWEAKS (Engine.ini)
# ═══════════════════════════════════════════════════════════════

$tVis = New-Object Windows.Forms.TabPage; $tVis.Text = "  VISUAL  "
$tVis.BackColor = Hex $C.bg

$visP = New-Object Windows.Forms.Panel
$visP.Size = New-Object Drawing.Size(960,560); $visP.AutoScroll = $true
$visP.BackColor = Hex $C.bg

$visH = New-Object Windows.Forms.Label
$visH.Text = "Engine.ini — UE5 Visual Disables"
$visH.Font = New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold)
$visH.ForeColor = Hex $C.text; $visH.Size = New-Object Drawing.Size(500,26)
$visH.Location = New-Object Drawing.Point(16,14)

$visInfo = New-Object Windows.Forms.Label
$visInfo.Text = "Engine.ini disables UE5 graphical features that hurt visibility and cost FPS. These are safe competitive tweaks used by pros across The Finals and Arc Raiders."
$visInfo.Font = New-Object Drawing.Font("Segoe UI",9)
$visInfo.ForeColor = Hex $C.sec; $visInfo.Size = New-Object Drawing.Size(900,36)
$visInfo.Location = New-Object Drawing.Point(16,44)

$visGrid = New-Object Windows.Forms.DataGridView
$visGrid.Size = New-Object Drawing.Size(900,380)
$visGrid.Location = New-Object Drawing.Point(16,84)
$visGrid.BackgroundColor = Hex $C.inner; $visGrid.BorderStyle = "None"
$visGrid.RowHeadersVisible = $false; $visGrid.AllowUserToAddRows = $false
$visGrid.AllowUserToDeleteRows = $false; $visGrid.AllowUserToResizeRows = $false
$visGrid.ReadOnly = $true; $visGrid.CellBorderStyle = "SingleHorizontal"
$visGrid.GridColor = Hex $C.border
$visGrid.ColumnHeadersHeightSizeMode = "AutoSize"
$visGrid.EnableHeadersVisualStyles = $false
$visGrid.ColumnHeadersDefaultCellStyle.BackColor = Hex $C.card
$visGrid.ColumnHeadersDefaultCellStyle.ForeColor = Hex $C.sec
$visGrid.ColumnHeadersDefaultCellStyle.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$visGrid.RowsDefaultCellStyle.BackColor = Hex $C.inner
$visGrid.RowsDefaultCellStyle.ForeColor = Hex $C.text
$visGrid.RowsDefaultCellStyle.SelectionBackColor = Hex $C.card
$visGrid.RowsDefaultCellStyle.Font = New-Object Drawing.Font("Consolas",9)
$visGrid.AlternatingRowsDefaultCellStyle.BackColor = Hex "#141E2C"

$visGrid.Columns.Add("tweak","Tweak"); $visGrid.Columns.Add("effect","Effect on Gameplay")
$visGrid.Columns.Add("fps","FPS Gain"); $visGrid.Columns.Add("impact","Impact")
$visGrid.Columns[0].Width = 220; $visGrid.Columns[1].Width = 360
$visGrid.Columns[2].Width = 120; $visGrid.Columns[3].Width = 100

$visData = @(
  @("Motion Blur", "Eliminates blur when turning — spot enemies while moving", "+2-5%", "MEDIUM"),
  @("Depth of Field", "Removes background blur — see enemies at any range", "+1-3%", "MEDIUM"),
  @("Bloom / Lens Flare", "Cleaner image, less eye strain during bright scenes", "+1-2%", "LOW"),
  @("Volumetric Fog", "Better long-range visibility — critical for PvP", "+3-8%", "HIGH"),
  @("Ambient Occlusion", "Minor FPS gain with no competitive gameplay loss", "+2-4%", "LOW"),
  @("Screen Space Reflections", "FPS gain with no impact on enemy visibility", "+3-6%", "MEDIUM"),
  @("Shadow Resolution (512)", "Sharper game feel, enemies easier to spot", "+5-10%", "HIGH"),
  @("Sharpen +0.5", "Crisper image without DLSS softening", "0%", "INFO"),
  @("Texture Pool 4GB", "Optimized streaming for 12GB VRAM, reduces stutter", "VARIES", "MEDIUM"),
)
foreach ($row in $visData) { $visGrid.Rows.Add($row[0],$row[1],$row[2],$row[3]) | Out-Null }

$visP.Controls.Add($visH); $visP.Controls.Add($visInfo); $visP.Controls.Add($visGrid)
$tVis.Controls.Add($visP)

# ═══════════════════════════════════════════════════════════════
# TAB 4: NVIDIA
# ═══════════════════════════════════════════════════════════════

$tNV = New-Object Windows.Forms.TabPage; $tNV.Text = "  NVIDIA  "
$tNV.BackColor = Hex $C.bg

$nvP = New-Object Windows.Forms.Panel
$nvP.Size = New-Object Drawing.Size(960,560); $nvP.AutoScroll = $true
$nvP.BackColor = Hex $C.bg

$nvRecs = @(
  (New-RecCard "Low Latency Mode: Ultra" "Reduces render queue to 1 frame. Combined with NVIDIA Reflex in-game, this gives the absolute minimum input latency for competitive play." "NVIDIA Control Panel -> Manage 3D Settings -> Low Latency Mode -> Ultra"),
  (New-RecCard "Power Management: Prefer Maximum Performance" "Prevents GPU clock speed drops during combat. Ensures consistent frame timing when it matters most." "NVIDIA Control Panel -> Power Management -> Prefer Maximum Performance"),
  (New-RecCard "Shader Cache Size: Unlimited (10GB)" "Arc Raiders is built on UE5 which compiles shaders on-the-fly. Unlimited cache eliminates stutter after driver/game updates." "NVIDIA Control Panel -> Shader Cache Size -> 10GB (Unlimited)"),
  (New-RecCard "Texture Filtering: High Performance" "Minor visual tradeoff (barely noticeable at 1080p) for a measurable FPS gain across all scenes." "NVIDIA Control Panel -> Texture Filtering -> High Performance"),
  (New-RecCard "Threaded Optimization: On" "Leverages all CPU cores/threads. Your Ryzen 7 3700X benefits significantly from this setting." "NVIDIA Control Panel -> Threaded Optimization -> On"),
  (New-RecCard "DLSS Override via NVIDIA App" "Forces DLSS 4.5 Transformer model for superior image quality at Balanced setting. Less ghosting and sharper than the old CNN model." "NVIDIA App -> Graphics -> ARC Raiders -> DLSS Override -> Model Presets: Recommended"),
)
$nvy = 10
foreach ($r in $nvRecs) { $r.Location = New-Object Drawing.Point(16,$nvy); $nvP.Controls.Add($r); $nvy += $r.Height + 6 }
$tNV.Controls.Add($nvP)

# ═══════════════════════════════════════════════════════════════
# TAB 5: AUDIO
# ═══════════════════════════════════════════════════════════════

$tAud = New-Object Windows.Forms.TabPage; $tAud.Text = "  AUDIO  "
$tAud.BackColor = Hex $C.bg

$audP = New-Object Windows.Forms.Panel
$audP.Size = New-Object Drawing.Size(960,560); $audP.AutoScroll = $true
$audP.BackColor = Hex $C.bg

$audRecs = @()
$audRecs += New-RecCard "Windows Sonic for Headphones" "3D spatial audio transforms stereo headphones into positional audio. You hear exactly where footsteps, gunfire, and ARC enemies are." "Right-click speaker tray -> Spatial Sound -> Windows Sonic for Headphones"
$audRecs += New-RecCard "Audio Format: 24-bit 48000Hz" "Best quality-to-performance ratio. Avoid 192kHz — it causes audio stutter in UE5 games with no audible benefit." "Sound -> Headphones -> Properties -> Advanced -> 24-bit 48000Hz (Studio Quality)"
$audRecs += New-RecCard "EarTrumpet Volume Management" "Arc Raiders at 100%, Discord at 70-80%, browser at 30%. Hear footsteps clearly without being deafened by teammates." "Right-click EarTrumpet tray icon to adjust per-app volumes"
$audRecs += New-RecCard "Night Mode (In-Game Setting)" "Compresses loud sounds (explosions) and amplifies quiet sounds (footsteps, reloads, healing). Must-have for competitive." "Arc Raiders Settings -> Audio -> Night Mode: ON"
$audRecs += New-RecCard "SupremeFX S1220A — Realtek Driver" "Your motherboard has a SupremeFX audio chip but runs on generic Microsoft drivers. The Realtek driver enables EQ, surround virtualization, and better clarity." "Search 'Realtek 6.0.9977.1' on catalog.update.microsoft.com -> Download .cab -> Extract -> Device Manager -> Update Driver"

$auy = 10
foreach ($r in $audRecs) { $r.Location = New-Object Drawing.Point(16,$auy); $audP.Controls.Add($r); $auy += $r.Height + 6 }
$tAud.Controls.Add($audP)

# ═══════════════════════════════════════════════════════════════
# TAB 6: WINDOWS
# ═══════════════════════════════════════════════════════════════

$tWin = New-Object Windows.Forms.TabPage; $tWin.Text = "  WINDOWS  "
$tWin.BackColor = Hex $C.bg

$winP = New-Object Windows.Forms.Panel
$winP.Size = New-Object Drawing.Size(960,560); $winP.AutoScroll = $true
$winP.BackColor = Hex $C.bg

$winRecs = @()
$winRecs += New-RecCard "Hardware-Accelerated GPU Scheduling (HAGS)" "Reduces GPU driver overhead by letting the GPU manage its own memory. Lowers frame latency by 1-3ms in UE5 games." "Settings -> Display -> Graphics -> Default graphics settings -> Turn ON 'Hardware-accelerated GPU scheduling'"
$winRecs += New-RecCard "Game Mode" "Windows prioritizes game processes for CPU and GPU resources. Prevents background tasks from causing micro-stutters." "Settings -> Gaming -> Game Mode -> ON"
$winRecs += New-RecCard "Disable Fullscreen Optimizations" "Prevents Windows from interfering with the game's exclusive fullscreen mode. Stops weird frame pacing and alt-tab issues." "Right-click start_protected_game.exe -> Properties -> Compatibility -> Check 'Disable fullscreen optimizations'"
$winRecs += New-RecCard "Power Plan: AMD Ryzen High Performance" "Prevents CPU from downclocking during gameplay. Ensures consistent FPS in CPU-intensive scenes." "Control Panel -> Power Options -> Select 'AMD Ryzen High Performance'"

$wy = 10
foreach ($r in $winRecs) { $r.Location = New-Object Drawing.Point(16,$wy); $winP.Controls.Add($r); $wy += $r.Height + 6 }
$tWin.Controls.Add($winP)

# ═══════════════════════════════════════════════════════════════
# TAB 7: BACKUPS
# ═══════════════════════════════════════════════════════════════

$tBak = New-Object Windows.Forms.TabPage; $tBak.Text = "  BACKUPS  "
$tBak.BackColor = Hex $C.bg

$bakP = New-Object Windows.Forms.Panel
$bakP.Size = New-Object Drawing.Size(960,560); $bakP.AutoScroll = $true
$bakP.BackColor = Hex $C.bg

$bakH = New-Object Windows.Forms.Label
$bakH.Text = "Configuration Backups"
$bakH.Font = New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold)
$bakH.ForeColor = Hex $C.text; $bakH.Size = New-Object Drawing.Size(400,26)
$bakH.Location = New-Object Drawing.Point(16,14)

$bakDesc = New-Object Windows.Forms.Label
$bakDesc.Text = "Every optimization creates a timestamped backup of your original GameUserSettings.ini. Restore anytime."
$bakDesc.Font = New-Object Drawing.Font("Segoe UI",9)
$bakDesc.ForeColor = Hex $C.sec; $bakDesc.Size = New-Object Drawing.Size(700,18)
$bakDesc.Location = New-Object Drawing.Point(16,42)

$bakList = New-Object Windows.Forms.ListBox
$bakList.Size = New-Object Drawing.Size(900,440)
$bakList.Location = New-Object Drawing.Point(16,68)
$bakList.BackColor = Hex $C.inner; $bakList.ForeColor = Hex $C.text
$bakList.BorderStyle = "None"; $bakList.Font = New-Object Drawing.Font("Consolas",10)
$bakList.IntegralHeight = $false; $bakList.HorizontalScrollbar = $true

$bakP.Controls.Add($bakH); $bakP.Controls.Add($bakDesc); $bakP.Controls.Add($bakList)
$tBak.Controls.Add($bakP)

# ═══════════════════════════════════════════════════════════════
# ASSEMBLE TABS
# ═══════════════════════════════════════════════════════════════

$tab.TabPages.Add($tDash); $tab.TabPages.Add($tSet)
$tab.TabPages.Add($tVis); $tab.TabPages.Add($tNV)
$tab.TabPages.Add($tAud); $tab.TabPages.Add($tWin); $tab.TabPages.Add($tBak)

# ── STATUS BAR ──
$status = New-Object Windows.Forms.StatusStrip
$status.BackColor = Hex "#080B12"
$status.ForeColor = Hex $C.dim
$status.Font = New-Object Drawing.Font("Segoe UI",8.5)
$status.Items.Add((New-Object Windows.Forms.ToolStripStatusLabel("  v$Script:Version  |  GPU: 596.36  |  Win 11 25H2  |  MIT  |  No data collected"))) | Out-Null

# ═══════════════════════════════════════════════════════════════
# EVENTS
# ═══════════════════════════════════════════════════════════════

function Update-All {
  $form.Cursor = "WaitCursor"
  $statDot.BackColor = Hex $C.yellow
  $statText.Text = "SCANNING..."; $statText.ForeColor = Hex $C.yellow
  $form.Refresh()

  $gpu = Get-GPU
  if ($gpu) {
    $cards.GPU.val.Text = $gpu.Name; $cards.GPU.dot.BackColor = Hex $C.green
    $cards.GPU.val.ForeColor = Hex $C.green
    $cards.Driver.val.Text = $gpu.Driver; $cards.Driver.dot.BackColor = Hex $C.green
    $cards.Driver.val.ForeColor = Hex $C.green
    $cards.VRAM.val.Text = $gpu.VRAM; $cards.VRAM.dot.BackColor = Hex $C.green
    $cards.VRAM.val.ForeColor = Hex $C.green
  } else {
    $cards.GPU.val.Text = "Not detected"; $cards.GPU.dot.BackColor = Hex $C.red
    $cards.Driver.val.Text = "N/A"; $cards.Driver.dot.BackColor = Hex $C.red
    $cards.VRAM.val.Text = "N/A"; $cards.VRAM.dot.BackColor = Hex $C.red
  }

  $rtx = Get-RTX
  $cards.Reflex.val.Text = $rtx
  if ($rtx -eq "On + Boost") { $cards.Reflex.dot.BackColor = Hex $C.green; $cards.Reflex.val.ForeColor = Hex $C.green }
  elseif ($rtx -eq "On") { $cards.Reflex.dot.BackColor = Hex $C.yellow; $cards.Reflex.val.ForeColor = Hex $C.yellow }
  else { $cards.Reflex.dot.BackColor = Hex $C.red; $cards.Reflex.val.ForeColor = Hex $C.red }

  if (Test-Path $Paths.Steam) {
    $cards.Game.val.Text = "Installed"; $cards.Game.dot.BackColor = Hex $C.green
    $cards.Game.val.ForeColor = Hex $C.green
  } else {
    $cards.Game.val.Text = "Not found"; $cards.Game.dot.BackColor = Hex $C.red
    $cards.Game.val.ForeColor = Hex $C.red
  }

  $cf = Get-CfgDir
  if ($cf) {
    $cards.Config.val.Text = "Found"; $cards.Config.dot.BackColor = Hex $C.green
    $cards.Config.val.ForeColor = Hex $C.green
  } else {
    $cards.Config.val.Text = "Missing"; $cards.Config.dot.BackColor = Hex $C.red
    $cards.Config.val.ForeColor = Hex $C.red
  }

  $pp, $ppOk = Get-Power
  $cards.Power.val.Text = $pp
  if ($ppOk) { $cards.Power.dot.BackColor = Hex $C.green; $cards.Power.val.ForeColor = Hex $C.green }
  else { $cards.Power.dot.BackColor = Hex $C.yellow; $cards.Power.val.ForeColor = Hex $C.yellow }

  $ac = Get-AudioCount
  $cards.Audio.val.Text = "$ac device(s)"
  if ($ac -gt 0) { $cards.Audio.dot.BackColor = Hex $C.green; $cards.Audio.val.ForeColor = Hex $C.green }
  else { $cards.Audio.dot.BackColor = Hex $C.yellow; $cards.Audio.val.ForeColor = Hex $C.yellow }

  # Settings grid
  $setGrid.Rows.Clear()
  try { $cur = Read-Settings } catch { $cur = @{} }
  foreach ($k in $SettingMap.Keys) {
    $cv = if ($cur.ContainsKey($k)) {$cur[$k]} else {"-"}
    $s = $SettingMap[$k]
    $matched = ($cv -eq $s.val) -or ($cv -eq $s.label)
    $impact = $s.impact
    $impLabel = switch ($impact) {"high"{"HIGH"} "med"{"MEDIUM"} default{"LOW"}}
    $idx = $setGrid.Rows.Add($k, $cv, "$($s.val) ($($s.label))", $s.why, $impLabel)
    $row = $setGrid.Rows[$idx]
    if ($matched) { $row.DefaultCellStyle.ForeColor = Hex $C.green }
    elseif ($cv -ne "-") { $row.DefaultCellStyle.ForeColor = Hex $C.orange }
    else { $row.DefaultCellStyle.ForeColor = Hex $C.dim }
  }

  # Backups
  $bakList.Items.Clear()
  $bks = Get-Backups
  if ($bks.Count -eq 0) {
    $bakList.Items.Add("  No backups yet. Click 'RUN OPTIMIZATION' on the Dashboard to create one.")
  } else {
    foreach ($b in $bks) {
      $parts = $b -split "\.",3
      $pretty = if ($parts[1] -match "^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$") {
        "$($matches[3])/$($matches[2])/$($matches[1]) $($matches[4]):$($matches[5])"
      } else { $parts[1] }
      $bakList.Items.Add("  $($parts[0]).ini  --  $pretty")
    }
  }

  $statDot.BackColor = Hex $C.green
  $statText.Text = "READY"; $statText.ForeColor = Hex $C.green
  $form.Cursor = "Default"
}

# Button events
$btnOpt.Add_Click({
  $btnOpt.Enabled = $false; $btnOpt.Text = "  RUNNING...  "
  $log.Visible = $true; $log.Text = ""; $log.ForeColor = Hex $C.yellow
  $form.Refresh()
  try {
    $results = Apply-Opt
    $log.Text = $results -join "`r`n"
    $log.ForeColor = Hex $C.green
  } catch {
    $log.Text = "ERROR: $($_.Exception.Message)"
    $log.ForeColor = Hex $C.red
  }
  Update-All
  $btnOpt.Enabled = $true; $btnOpt.Text = "  RUN OPTIMIZATION  "
})

$btnRest.Add_Click({
  $r = [Windows.Forms.MessageBox]::Show("Remove Engine.ini and unlock GameUserSettings.ini?`n`nThis reverts all competitive tweaks.", "Restore Defaults", "YesNo", "Question")
  if ($r -eq "Yes") {
    try {
      $results = Restore-Opt
      $log.Visible = $true; $log.Text = $results -join "`r`n"; $log.ForeColor = Hex $C.accent
    } catch {
      $log.Visible = $true; $log.Text = "ERROR: $($_.Exception.Message)"; $log.ForeColor = Hex $C.red
    }
    Update-All
  }
})

$btnTest.Add_Click({
  try {
    $cf = Get-CfgDir
    if (-not $cf) { [Windows.Forms.MessageBox]::Show("Config not found. Launch ARC Raiders once first.","Error","OK","Error"); return }
    $cur = Read-Settings
    $ok = 0; $total = $SettingMap.Count
    foreach ($k in $SettingMap.Keys) {
      $cv = if ($cur.ContainsKey($k)) {$cur[$k]} else {""}
      $s = $SettingMap[$k]
      if ($cv -eq $s.val -or $cv -eq $s.label) { $ok++ }
    }
    $hasEngine = Test-Path $Paths.Engine
    $msg = "Settings Check: $ok of $total optimized ($([Math]::Round($ok/$total*100))%)`nEngine.ini: $(if($hasEngine){'Present'}else{'Missing'})`n`n$(if($ok -eq $total -and $hasEngine){'Your configuration is fully optimized.'}else{'Some settings need updating - run Optimization.'})"
    [Windows.Forms.MessageBox]::Show($msg, "Configuration Health Check", "OK", "Information")
  } catch {
    [Windows.Forms.MessageBox]::Show("Health check error: $($_.Exception.Message)", "Error", "OK", "Error")
  }
})

$setBtn.Add_Click({
  try {
    $results = Apply-Opt
    $log.Visible = $true; $log.Text = $results -join "`r`n"; $log.ForeColor = Hex $C.green
    Update-All
    [Windows.Forms.MessageBox]::Show("Settings applied! Check the Dashboard log for details.", "Applied", "OK", "Information")
  } catch {
    $log.Visible = $true; $log.Text = "ERROR: $($_.Exception.Message)"; $log.ForeColor = Hex $C.red
  }
})

# ═══════════════════════════════════════════════════════════════
# BUILD FORM
# ═══════════════════════════════════════════════════════════════

$form.Controls.Add($titleBar)
$form.Controls.Add($tab)
$form.Controls.Add($status)

$form.Add_Shown({
  $form.Activate()
  try { Update-All }
  catch {
    $log.Visible = $true
    $log.Text = "Initialization error: $($_.Exception.Message)"
    $log.ForeColor = Hex $C.red
    $statDot.BackColor = Hex $C.red
    $statText.Text = "ERROR"
  }
})
try { [Windows.Forms.Application]::Run($form) }
catch {
  $msg = "Arc Optimizer encountered an unexpected error.`n`n$($_.Exception.Message)"
  [Windows.Forms.MessageBox]::Show($msg, "Unexpected Error", "OK", "Error")
}
