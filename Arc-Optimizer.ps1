Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management

# ---- CONFIG ----
$ConfigPath = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\GameUserSettings.ini"
$EnginePath = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\Engine.ini"
$BackupDir  = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\ArcOptimizer_Backups"
$SteamExe   = "D:\SteamLibrary\steamapps\common\ARC Raiders\start_protected_game.exe"

# ---- COLORS ----
$DarkBg    = "#0f1117"
$DarkCard  = "#1a1c25"
$DarkInner = "#22242e"
$Border    = "#2e3140"
$TextPri   = "#e4e6ef"
$TextSec   = "#8b8fa3"
$TextDim   = "#5a5e72"
$Accent    = "#5E81AC"
$AccentHov = "#6d93c0"
$Green     = "#7ec8a3"
$Yellow    = "#e8c96a"
$Red       = "#bf616a"

function HexColor($hex) { return [System.Drawing.Color]::FromArgb(255, [Int32]::Parse($hex.Substring(1,2), "HexNumber"), [Int32]::Parse($hex.Substring(3,2), "HexNumber"), [Int32]::Parse($hex.Substring(5,2), "HexNumber")) }

# ---- SYSTEM FUNCTIONS ----
function Get-GpuInfo {
    try { $s = & "nvidia-smi" "--query-gpu=name,driver_version,memory.total,temperature.gpu" "--format=csv,noheader" 2>$null
        if ($LASTEXITCODE -eq 0 -and $s) { $p = $s.Trim() -split ", "; return @{Name=$p[0]; Driver=$p[1]; VRAM=$p[2]; Temp=$p[3]} } } catch {}
    return $null
}

function Get-PowerPlan {
    $p = powercfg /getactivescheme 2>$null
    if ($p -match "AMD Ryzen High Performance") { return "AMD Ryzen High Perf", $true }
    if ($p -match "High Performance") { return "High Performance", $true }
    return "Balanced", $false
}

function Get-ReflexStatus {
    if (-not (Test-Path $ConfigPath)) { return "N/A" }
    $c = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
    if ($c -match "NvReflexMode=Boost") { return "On + Boost" }
    if ($c -match "NvReflexMode=On") { return "On" }
    return "Off"
}

function Get-AudioCount {
    try { return @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'Headphone|Speaker|Realtek|27G2' -and $_.PNPClass -eq 'AudioEndpoint' } | Select-Object -ExpandProperty Name).Count } catch { return 0 }
}

function Detect-Realtek {
    try { return ($null -ne (Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match 'VEN_10EC' -and $_.Name -match 'High Definition Audio' })) } catch { return $false }
}

function New-Backup {
    if (-not (Test-Path $ConfigPath)) { return $null }
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $ConfigPath "$BackupDir\GameUserSettings.ini.$ts.bak" -Force
    return $ts
}

function Get-BackupList {
    if (-not (Test-Path $BackupDir)) { return @() }
    return @(Get-ChildItem "$BackupDir\*.bak" | Sort-Object LastWriteTime -Descending | ForEach-Object { $_.Name })
}

# ---- UI BUILDERS ----
function RoundedButton($text, $bg, $fg, $w, $h) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size($w, $h)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = HexColor $bg
    $btn.ForeColor = HexColor $fg
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = "Hand"
    $btn.FlatAppearance.MouseOverBackColor = HexColor $AccentHov
    return $btn
}

function MiniCard($title) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Size = New-Object System.Drawing.Size(180, 64)
    $p.BackColor = HexColor $DarkInner

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $title.ToUpper()
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = HexColor $TextDim
    $lbl.Size = New-Object System.Drawing.Size(170, 16)
    $lbl.Location = New-Object System.Drawing.Point(8, 6)

    $val = New-Object System.Windows.Forms.Label
    $val.Name = "val_" + $title -replace " ", ""
    $val.Text = "---"
    $val.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $val.ForeColor = HexColor $TextPri
    $val.Size = New-Object System.Drawing.Size(170, 24)
    $val.Location = New-Object System.Drawing.Point(8, 26)

    $p.Controls.Add($lbl)
    $p.Controls.Add($val)
    return $p, $val
}

function RecCard($title, $body, $fix) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Size = New-Object System.Drawing.Size(700, 70)
    $p.Height = 70
    $p.BackColor = HexColor $DarkInner

    $t = New-Object System.Windows.Forms.Label
    $t.Text = $title
    $t.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $t.ForeColor = HexColor $Yellow
    $t.Size = New-Object System.Drawing.Size(680, 20)
    $t.Location = New-Object System.Drawing.Point(10, 8)

    $b = New-Object System.Windows.Forms.Label
    $b.Text = $body
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $b.ForeColor = HexColor $TextSec
    $b.Size = New-Object System.Drawing.Size(680, 20)
    $b.Location = New-Object System.Drawing.Point(10, 30)

    $p.Controls.Add($t)
    $p.Controls.Add($b)

    if ($fix) {
        $f = New-Object System.Windows.Forms.Label
        $f.Text = $fix
        $f.Font = New-Object System.Drawing.Font("Consolas", 9)
        $f.ForeColor = HexColor $Accent
        $f.Size = New-Object System.Drawing.Size(680, 20)
        $f.Location = New-Object System.Drawing.Point(10, 50)
        $p.Controls.Add($f)
        $p.Height = 90
    }

    return $p
}

# ---- BUILD FORM ----
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Arc Optimizer v1.0"
$form.Size = New-Object System.Drawing.Size(960, 720)
$form.MinimumSize = New-Object System.Drawing.Size(860, 640)
$form.StartPosition = "CenterScreen"
$form.BackColor = HexColor $DarkBg
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $pid).MainModule.FileName)

# ---- TOP BAR ----
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Size = New-Object System.Drawing.Size(960, 50)
$topBar.BackColor = HexColor $DarkCard
$topBar.Dock = "Top"

$logo = New-Object System.Windows.Forms.Label
$logo.Text = "ARC OPTIMIZER"
$logo.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$logo.ForeColor = HexColor $Accent
$logo.Size = New-Object System.Drawing.Size(280, 36)
$logo.Location = New-Object System.Drawing.Point(16, 8)

$version = New-Object System.Windows.Forms.Label
$version.Text = "v1.0"
$version.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$version.ForeColor = HexColor $TextDim
$version.Size = New-Object System.Drawing.Size(40, 16)
$version.Location = New-Object System.Drawing.Point(200, 24)

$statusIcon = New-Object System.Windows.Forms.Label
$statusIcon.Name = "statusIcon"
$statusIcon.Text = "Scanning..."
$statusIcon.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusIcon.ForeColor = HexColor $Yellow
$statusIcon.Size = New-Object System.Drawing.Size(200, 20)
$statusIcon.Location = New-Object System.Drawing.Point(720, 16)
$statusIcon.TextAlign = "MiddleRight"

$topBar.Controls.Add($logo)
$topBar.Controls.Add($version)
$topBar.Controls.Add($statusIcon)

# ---- TAB CONTROL ----
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Size = New-Object System.Drawing.Size(920, 560)
$tabControl.Location = New-Object System.Drawing.Point(20, 60)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabControl.Appearance = "Normal"
$tabControl.Padding = New-Object System.Drawing.Point(12, 6)
$tabControl.BackColor = HexColor $DarkBg
$tabControl.ForeColor = HexColor $TextPri
$tabControl.DrawMode = "OwnerDrawFixed"

$tabControl.Add_DrawItem({
    $g = $_.Graphics
    $bg = if ($_.State -band [System.Windows.Forms.DrawItemState]::Selected) { HexColor $DarkInner } else { HexColor $DarkBg }
    $fg = if ($_.State -band [System.Windows.Forms.DrawItemState]::Selected) { HexColor $Accent } else { HexColor $TextSec }
    $br = New-Object System.Drawing.SolidBrush($bg)
    $g.FillRectangle($br, $_.Bounds)
    $br.Dispose()
    $s = $tabControl.TabPages[$_.Index].Text
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
    $bf = New-Object System.Drawing.SolidBrush($fg)
    $r = New-Object System.Drawing.RectangleF($_.Bounds.X, $_.Bounds.Y, $_.Bounds.Width, $_.Bounds.Height)
    $g.DrawString($s, $tabControl.Font, $bf, $r, $sf)
    $bf.Dispose()
    $sf.Dispose()
})

# ---- TAB 1: DASHBOARD ----
$tabDash = New-Object System.Windows.Forms.TabPage
$tabDash.Text = "Dashboard"
$tabDash.BackColor = HexColor $DarkBg

$tabDashPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$tabDashPanel.Size = New-Object System.Drawing.Size(900, 530)
$tabDashPanel.Location = New-Object System.Drawing.Point(0, 0)
$tabDashPanel.BackColor = HexColor $DarkBg
$tabDashPanel.AutoScroll = $true
$tabDashPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$tabDashPanel.FlowDirection = "TopDown"
$tabDashPanel.WrapContents = $false

# Optimize section
$optPanel = New-Object System.Windows.Forms.Panel
$optPanel.Size = New-Object System.Drawing.Size(860, 130)
$optPanel.BackColor = HexColor $DarkCard

$optTitle = New-Object System.Windows.Forms.Label
$optTitle.Text = "One-Click Competitive Optimization"
$optTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$optTitle.ForeColor = HexColor $TextPri
$optTitle.Size = New-Object System.Drawing.Size(500, 30)
$optTitle.Location = New-Object System.Drawing.Point(20, 16)

$optDesc = New-Object System.Windows.Forms.Label
$optDesc.Text = "Applies proven settings for maximum FPS, lowest latency, and PvP advantage"
$optDesc.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$optDesc.ForeColor = HexColor $TextSec
$optDesc.Size = New-Object System.Drawing.Size(600, 20)
$optDesc.Location = New-Object System.Drawing.Point(20, 50)

$btnOptimize = RoundedButton "OPTIMIZE EVERYTHING" $Accent "#FFFFFF" 280 48
$btnOptimize.Location = New-Object System.Drawing.Point(20, 76)

$btnRestore = RoundedButton "Restore Defaults" $DarkInner $TextSec 160 40
$btnRestore.Location = New-Object System.Drawing.Point(320, 80)
$btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$optPanel.Controls.Add($optTitle)
$optPanel.Controls.Add($optDesc)
$optPanel.Controls.Add($btnOptimize)
$optPanel.Controls.Add($btnRestore)

# Status cards
$statusFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$statusFlow.Size = New-Object System.Drawing.Size(860, 200)
$statusFlow.BackColor = HexColor $DarkBg
$statusFlow.Padding = New-Object System.Windows.Forms.Padding(0)
$statusFlow.WrapContents = $true

$statusCards = @{}
$cardData = @("GPU","Driver","VRAM","Reflex","Game","Config","Power","Audio")
foreach ($name in $cardData) {
    $card, $val = MiniCard $name
    $card.Margin = New-Object System.Windows.Forms.Padding(4,4,4,4)
    $statusFlow.Controls.Add($card)
    $statusCards[$name] = $val
}

# Result box
$resultBox = New-Object System.Windows.Forms.TextBox
$resultBox.Name = "resultBox"
$resultBox.Text = ""
$resultBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$resultBox.ForeColor = HexColor $Green
$resultBox.BackColor = HexColor $DarkInner
$resultBox.Size = New-Object System.Drawing.Size(840, 80)
$resultBox.Margin = New-Object System.Windows.Forms.Padding(10,0,10,0)
$resultBox.Multiline = $true
$resultBox.ReadOnly = $true
$resultBox.BorderStyle = "None"
$resultBox.ScrollBars = "Vertical"
$resultBox.Visible = $false

$tabDashPanel.Controls.Add($optPanel)
$tabDashPanel.Controls.Add($statusFlow)
$tabDashPanel.Controls.Add($resultBox)

$tabDash.Controls.Add($tabDashPanel)

# ---- TAB 2: GAME SETTINGS ----
$tabGame = New-Object System.Windows.Forms.TabPage
$tabGame.Text = "Game Settings"
$tabGame.BackColor = HexColor $DarkBg

$gamePanel = New-Object System.Windows.Forms.Panel
$gamePanel.Size = New-Object System.Drawing.Size(900, 530)
$gamePanel.BackColor = HexColor $DarkBg
$gamePanel.AutoScroll = $true

$gameLabel = New-Object System.Windows.Forms.Label
$gameLabel.Text = "GameUserSettings.ini - Optimized Values"
$gameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$gameLabel.ForeColor = HexColor $TextPri
$gameLabel.Size = New-Object System.Drawing.Size(500, 24)
$gameLabel.Location = New-Object System.Drawing.Point(16, 16)

$gameGrid = New-Object System.Windows.Forms.DataGridView
$gameGrid.Size = New-Object System.Drawing.Size(860, 360)
$gameGrid.Location = New-Object System.Drawing.Point(16, 50)
$gameGrid.BackgroundColor = HexColor $DarkInner
$gameGrid.BorderStyle = "None"
$gameGrid.RowHeadersVisible = $false
$gameGrid.AutoSizeColumnsMode = "Fill"
$gameGrid.AllowUserToAddRows = $false
$gameGrid.AllowUserToDeleteRows = $false
$gameGrid.AllowUserToResizeRows = $false
$gameGrid.ReadOnly = $true
$gameGrid.Font = New-Object System.Drawing.Font("Consolas", 9)
$gameGrid.ColumnHeadersHeightSizeMode = "AutoSize"
$gameGrid.CellBorderStyle = "SingleHorizontal"
$gameGrid.GridColor = HexColor $Border
$gameGrid.ColumnHeadersDefaultCellStyle.BackColor = HexColor $DarkCard
$gameGrid.ColumnHeadersDefaultCellStyle.ForeColor = HexColor $TextSec
$gameGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$gameGrid.RowsDefaultCellStyle.BackColor = HexColor $DarkInner
$gameGrid.RowsDefaultCellStyle.ForeColor = HexColor $TextPri
$gameGrid.RowsDefaultCellStyle.SelectionBackColor = HexColor $DarkCard
$gameGrid.RowsDefaultCellStyle.SelectionForeColor = HexColor $Accent
$gameGrid.AlternatingRowsDefaultCellStyle.BackColor = HexColor "#1e202c"
$gameGrid.EnableHeadersVisualStyles = $false

$gameGrid.Columns.Add("setting","Setting")
$gameGrid.Columns.Add("current","Current")
$gameGrid.Columns.Add("optimized","Optimized")
$gameGrid.Columns.Add("why","Why It Matters")

$gameGrid.Columns[0].Width = 220
$gameGrid.Columns[1].Width = 140
$gameGrid.Columns[2].Width = 180
$gameGrid.Columns[3].Width = 320

$gameSettings = @{
    "sg.ViewDistanceQuality" = "3 (High)";     "sg.FoliageQuality" = "0 (Low)";    "sg.ShadowQuality" = "0 (Low)"
    "DLSSMode" = "Balanced";                   "DLSSModel" = "Transformer";        "NvReflexMode" = "Boost"
    "FrameRateLimit" = "0 (Uncapped)";         "FullscreenMode" = "0 (Exclusive)"; "MotionBlurScale" = "0 (Off)"
    "sg.TextureQuality" = "4 (Epic)";          "sg.EffectsQuality" = "0 (Low)";    "RTXGIQuality" = "Static"
    "LensDistortionEnabled" = "False"
}
$whyMap = @{
    "sg.ViewDistanceQuality" = "See enemies at longer range"
    "sg.FoliageQuality" = "Remove bushes enemies hide behind - PvP ADVANTAGE"
    "sg.ShadowQuality" = "Better enemy visibility + FPS boost"
    "DLSSMode" = "Best FPS/clarity tradeoff for competitive"
    "DLSSModel" = "DLSS 4.5 - sharper, less ghosting"
    "NvReflexMode" = "Lowest possible input latency"
    "FrameRateLimit" = "Reflex works best uncapped"
    "FullscreenMode" = "Lowest input latency mode"
    "MotionBlurScale" = "Eliminates blur during movement"
    "sg.TextureQuality" = "12GB VRAM handles Epic with no FPS cost"
    "sg.EffectsQuality" = "Less visual clutter in combat"
    "RTXGIQuality" = "RT ray tracing costs FPS - Static = optimal"
    "LensDistortionEnabled" = "Cleaner view without fisheye effect"
}

$gameBtn = RoundedButton "Apply Changes" $Accent "#FFFFFF" 160 36
$gameBtn.Location = New-Object System.Drawing.Point(16, 420)
$gameBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$gamePanel.Controls.Add($gameLabel)
$gamePanel.Controls.Add($gameGrid)
$gamePanel.Controls.Add($gameBtn)

$tabGame.Controls.Add($gamePanel)

# ---- TAB 3: NVIDIA ----
$tabNvidia = New-Object System.Windows.Forms.TabPage
$tabNvidia.Text = "NVIDIA"
$tabNvidia.BackColor = HexColor $DarkBg

$nvidiaPanel = New-Object System.Windows.Forms.Panel
$nvidiaPanel.Size = New-Object System.Drawing.Size(900, 530)
$nvidiaPanel.BackColor = HexColor $DarkBg
$nvidiaPanel.AutoScroll = $true

$nvidiaRecs = @()
$nvidiaRecs += RecCard "Low Latency Mode: Ultra" "Reduces render queue to 1 frame for minimum input latency." ""
$nvidiaRecs += RecCard "Power Management: Prefer Maximum Performance" "Prevents GPU clock drops during combat." ""
$nvidiaRecs += RecCard "Shader Cache: Unlimited (10GB)" "Eliminates UE5 shader compilation stutters." ""
$nvidiaRecs += RecCard "Texture Filtering: High Performance" "Minor visual tradeoff for FPS gain." ""
$nvidiaRecs += RecCard "Threaded Optimization: On" "Better multi-core utilization for Ryzen 7." ""

$nl = New-Object System.Windows.Forms.Label
$nl.Text = "DLSS Override via NVIDIA App"
$nl.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$nl.ForeColor = HexColor $Yellow
$nl.Size = New-Object System.Drawing.Size(400, 24)
$nl.Location = New-Object System.Drawing.Point(16, 290)

$ny = 320
$dlssSteps = @(
    "1. Open NVIDIA App (Start Menu)",
    "2. Go to Graphics tab",
    "3. Find ARC Raiders (or click Add)",
    "4. Set 'DLSS Override - Model Presets': Recommended",
    "5. Set 'DLSS Override - Super Resolution': Use 3D App Setting",
    "6. Set 'DLSS Override - Frame Generation': Use 3D App Setting"
)
foreach ($step in $dlssSteps) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $step
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $l.ForeColor = HexColor $TextSec
    $l.Size = New-Object System.Drawing.Size(600, 20)
    $l.Location = New-Object System.Drawing.Point(30, $ny)
    $nvidiaPanel.Controls.Add($l)
    $ny += 26
}

$nvidiaPanel.Controls.Add($nl)
$ny2 = 10
foreach ($r in $nvidiaRecs) { $r.Location = New-Object System.Drawing.Point(16, $ny2); $nvidiaPanel.Controls.Add($r); $ny2 += $r.Height + 8 }

$tabNvidia.Controls.Add($nvidiaPanel)

# ---- TAB 4: AUDIO ----
$tabAudio = New-Object System.Windows.Forms.TabPage
$tabAudio.Text = "Audio"
$tabAudio.BackColor = HexColor $DarkBg

$audioPanel = New-Object System.Windows.Forms.Panel
$audioPanel.Size = New-Object System.Drawing.Size(900, 530)
$audioPanel.BackColor = HexColor $DarkBg
$audioPanel.AutoScroll = $true

$audioRecs = @()
$audioRecs += RecCard "Windows Sonic for Headphones" "3D spatial audio - hear footsteps and gunfire direction precisely." "Right-click speaker tray -> Spatial Sound -> Windows Sonic for Headphones"
$audioRecs += RecCard "Audio Format: 24-bit 48000Hz" "Best quality-to-performance. Avoid 192kHz (causes audio stutters in games)." "Sound -> Headphones -> Properties -> Advanced -> 24-bit 48000Hz (Studio Quality)"
$audioRecs += RecCard "Per-App Volumes (EarTrumpet)" "Game 100%, Discord 70-80%, Browser 30% for clear footsteps." "Right-click EarTrumpet tray icon to adjust per-app volumes"
$audioRecs += RecCard "Night Mode (In-Game)" "Compresses loud sounds and amplifies quiet sounds like footsteps." "Arc Raiders Settings -> Audio -> Night Mode: ON"
if (-not (Detect-Realtek)) {
    $audioRecs += RecCard "SupremeFX Driver Not Installed" "Your ROG STRIX B450-F has SupremeFX S1220A but uses generic Microsoft driver." "Search 'Realtek 6.0.9977.1' on catalog.update.microsoft.com"
}

$ay = 10
foreach ($r in $audioRecs) { $r.Location = New-Object System.Drawing.Point(16, $ay); $audioPanel.Controls.Add($r); $ay += $r.Height + 8 }

$tabAudio.Controls.Add($audioPanel)

# ---- TAB 5: WINDOWS ----
$tabWindows = New-Object System.Windows.Forms.TabPage
$tabWindows.Text = "Windows"
$tabWindows.BackColor = HexColor $DarkBg

$winPanel = New-Object System.Windows.Forms.Panel
$winPanel.Size = New-Object System.Drawing.Size(900, 530)
$winPanel.BackColor = HexColor $DarkBg
$winPanel.AutoScroll = $true

$winRecs = @()
$winRecs += RecCard "Game Mode" "Windows prioritizes game processes for smoother performance." "Settings -> Gaming -> Game Mode -> On"
$winRecs += RecCard "Hardware-Accelerated GPU Scheduling (HAGS)" "Reduces GPU driver overhead and improves frame timing." "Settings -> Display -> Graphics -> Default graphics settings -> HAGS: On"
$winRecs += RecCard "Disable Fullscreen Optimizations" "Prevents frame pacing issues in fullscreen exclusive mode." "Right-click start_protected_game.exe -> Properties -> Compatibility -> Check 'Disable fullscreen optimizations'"

$wy = 10
foreach ($r in $winRecs) { $r.Location = New-Object System.Drawing.Point(16, $wy); $winPanel.Controls.Add($r); $wy += $r.Height + 8 }

$tabWindows.Controls.Add($winPanel)

# ---- TAB 6: BACKUPS ----
$tabBackup = New-Object System.Windows.Forms.TabPage
$tabBackup.Text = "Backups"
$tabBackup.BackColor = HexColor $DarkBg

$backupPanel = New-Object System.Windows.Forms.Panel
$backupPanel.Size = New-Object System.Drawing.Size(900, 530)
$backupPanel.BackColor = HexColor $DarkBg
$backupPanel.AutoScroll = $true

$backupLabel = New-Object System.Windows.Forms.Label
$backupLabel.Text = "Configuration Backups"
$backupLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$backupLabel.ForeColor = HexColor $TextPri
$backupLabel.Size = New-Object System.Drawing.Size(400, 24)
$backupLabel.Location = New-Object System.Drawing.Point(16, 16)

$backupListBox = New-Object System.Windows.Forms.ListBox
$backupListBox.Size = New-Object System.Drawing.Size(840, 400)
$backupListBox.Location = New-Object System.Drawing.Point(16, 50)
$backupListBox.BackColor = HexColor $DarkInner
$backupListBox.ForeColor = HexColor $TextPri
$backupListBox.BorderStyle = "None"
$backupListBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$backupListBox.IntegralHeight = $false
$backupListBox.HorizontalScrollbar = $true

$backupPanel.Controls.Add($backupLabel)
$backupPanel.Controls.Add($backupListBox)

$tabBackup.Controls.Add($backupPanel)

# Add all tabs
$tabControl.TabPages.Add($tabDash)
$tabControl.TabPages.Add($tabGame)
$tabControl.TabPages.Add($tabNvidia)
$tabControl.TabPages.Add($tabAudio)
$tabControl.TabPages.Add($tabWindows)
$tabControl.TabPages.Add($tabBackup)

# ---- STATUS BAR ----
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.BackColor = HexColor $DarkCard
$statusBar.ForeColor = HexColor $TextSec

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Name = "statusLabel"
$statusLabel.Text = "Ready"
$statusBar.Items.Add($statusLabel)

# ---- REFRESH ----
function Update-Dashboard {
    $form.Cursor = "WaitCursor"
    $statusIcon.Text = "Scanning..."
    $statusIcon.ForeColor = HexColor $Yellow
    $form.Refresh()

    $gpu = Get-GpuInfo

    if ($gpu) {
        $statusCards["GPU"].Text = $gpu.Name
        $statusCards["Driver"].Text = $gpu.Driver
        $statusCards["VRAM"].Text = $gpu.VRAM
        $statusCards["GPU"].ForeColor = HexColor $Green
        $statusCards["Driver"].ForeColor = HexColor $Green
        $statusCards["VRAM"].ForeColor = HexColor $Green
    } else {
        $statusCards["GPU"].Text = "Not detected"
        $statusCards["Driver"].Text = "N/A"
        $statusCards["VRAM"].Text = "N/A"
        $statusCards["GPU"].ForeColor = HexColor $Red
        $statusCards["Driver"].ForeColor = HexColor $Red
        $statusCards["VRAM"].ForeColor = HexColor $Red
    }

    $reflex = Get-ReflexStatus
    $statusCards["Reflex"].Text = $reflex
    if ($reflex -eq "On + Boost") { $statusCards["Reflex"].ForeColor = HexColor $Green }
    elseif ($reflex -eq "On") { $statusCards["Reflex"].ForeColor = HexColor $Yellow }
    else { $statusCards["Reflex"].ForeColor = HexColor $Red }

    if (Test-Path $SteamExe) {
        $statusCards["Game"].Text = "Installed OK"
        $statusCards["Game"].ForeColor = HexColor $Green
    } else {
        $statusCards["Game"].Text = "Not found"
        $statusCards["Game"].ForeColor = HexColor $Red
    }

    if (Test-Path $ConfigPath) {
        $statusCards["Config"].Text = "Found"
        $statusCards["Config"].ForeColor = HexColor $Green
    } else {
        $statusCards["Config"].Text = "Not found"
        $statusCards["Config"].ForeColor = HexColor $Red
    }

    $plan, $planOk = Get-PowerPlan
    $statusCards["Power"].Text = $plan
    $statusCards["Power"].ForeColor = if ($planOk) { HexColor $Green } else { HexColor $Yellow }

    $audioCount = Get-AudioCount
    $statusCards["Audio"].Text = "$audioCount devices"
    $statusCards["Audio"].ForeColor = if ($audioCount -gt 0) { HexColor $Green } else { HexColor $Yellow }

    # Update game settings grid
    $gameGrid.Rows.Clear()
    $curSettings = @{}
    if (Test-Path $ConfigPath) {
        $c = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
        foreach ($line in $c -split "`n") {
            if ($line -match "^(sg\.\w+|\w+)=(.+)$") { $curSettings[$matches[1]] = $matches[2].Trim() }
        }
    }
    foreach ($k in $gameSettings.Keys) {
        $cur = if ($curSettings.ContainsKey($k)) { $curSettings[$k] } else { "-" }
        $why = if ($whyMap.ContainsKey($k)) { $whyMap[$k] } else { "" }
        $gameGrid.Rows.Add($k, $cur, $gameSettings[$k], $why) | Out-Null
        $lastRow = $gameGrid.Rows[$gameGrid.Rows.Count - 1]
        if ($cur -eq $gameSettings[$k] -or $cur -eq $gameSettings[$k].Split(" ")[0]) {
            $lastRow.DefaultCellStyle.ForeColor = HexColor $Green
        }
    }

    # Update backups
    $backupListBox.Items.Clear()
    $backups = Get-BackupList
    if ($backups.Count -eq 0) {
        $backupListBox.Items.Add("  No backups yet. Click 'Optimize Everything' to create one.")
    } else {
        foreach ($b in $backups) {
            $parts = $b -split "\.", 3
            $pretty = if ($parts[1] -match "^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$") {
                "$($matches[3])/$($matches[2])/$($matches[1]) $($matches[4]):$($matches[5])"
            } else { $parts[1] }
            $backupListBox.Items.Add("  $($parts[0]).ini  [$pretty]")
        }
    }

    $statusIcon.Text = "Connected"
    $statusIcon.ForeColor = HexColor $Green
    $form.Cursor = "Default"
}

# ---- EVENTS ----
$btnOptimize.Add_Click({
    $btnOptimize.Enabled = $false
    $btnOptimize.Text = "OPTIMIZING..."
    $resultBox.Visible = $true
    $resultBox.Text = "Creating backup and applying settings..."
    $resultBox.ForeColor = HexColor $Yellow
    $form.Refresh()

    $bk = New-Backup
    $results = @()
    if ($bk) { $results += "Backup: $bk" }

    if (Test-Path $ConfigPath) {
        $content = Get-Content $ConfigPath -Raw
        $orig = $content
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
        }
        foreach ($pair in $swaps.GetEnumerator()) {
            if ($content -match [regex]::Escape($pair.Key)) {
                $content = $content -replace [regex]::Escape($pair.Key), $pair.Value
            }
        }
        if ($content -ne $orig) {
            Set-Content -Path $ConfigPath -Value $content -NoNewline -Encoding UTF8
            $results += "GameUserSettings.ini updated"
        } else {
            $results += "GameUserSettings.ini already optimized"
        }
        attrib +R $ConfigPath 2>$null
        $results += "Read-only applied"
    } else {
        $results += "Config not found. Launch game once first."
    }

    # Engine.ini
    $engine = @"
; Arc Optimizer - competitive tweaks
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
r.Streaming.PoolSize=4096
r.Streaming.MaxEffectiveScreenFraction=0.5
"@
    Set-Content -Path $EnginePath -Value $engine -Encoding UTF8
    attrib +R $EnginePath 2>$null
    $results += "Engine.ini created with competitive tweaks"

    $resultBox.Text = $results -join "`r`n"
    $resultBox.ForeColor = HexColor $Green

    Update-Dashboard

    $btnOptimize.Enabled = $true
    $btnOptimize.Text = "OPTIMIZE EVERYTHING"
})

$btnRestore.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show("Remove Engine.ini and unlock GameUserSettings.ini?", "Restore Defaults", "YesNo", "Question")
    if ($r -eq "Yes") {
        if (Test-Path $EnginePath) { attrib -R $EnginePath 2>$null; Remove-Item $EnginePath -Force }
        if (Test-Path $ConfigPath) { attrib -R $ConfigPath 2>$null }
        [System.Windows.Forms.MessageBox]::Show("Defaults restored. Engine.ini removed, GameUserSettings.ini unlocked.", "Done", "OK", "Information")
        Update-Dashboard
    }
})

$gameBtn.Add_Click({
    if (Test-Path $ConfigPath) {
        $bk = New-Backup
        $content = Get-Content $ConfigPath -Raw
        $orig = $content
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
            "FrameRateLimit=165.000000"        = "FrameRateLimit=0.000000"
        }
        foreach ($pair in $swaps.GetEnumerator()) {
            if ($content -match [regex]::Escape($pair.Key)) {
                $content = $content -replace [regex]::Escape($pair.Key), $pair.Value
            }
        }
        if ($content -ne $orig) {
            Set-Content -Path $ConfigPath -Value $content -NoNewline -Encoding UTF8
            attrib +R $ConfigPath 2>$null
            [System.Windows.Forms.MessageBox]::Show("GameUserSettings.ini updated!", "Applied", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Already optimized!", "No Changes", "OK", "Information")
        }
        Update-Dashboard
    } else {
        [System.Windows.Forms.MessageBox]::Show("Config not found. Launch game once first.", "Error", "OK", "Error")
    }
})

# ---- ASSEMBLE ----
$form.Controls.Add($topBar)
$form.Controls.Add($tabControl)
$form.Controls.Add($statusBar)

$form.Add_Shown({
    $form.Activate()
    Update-Dashboard
})

[System.Windows.Forms.Application]::Run($form)
