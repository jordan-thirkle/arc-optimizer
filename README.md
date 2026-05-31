# Arc Optimizer — One-Click Competitive Optimization Tool for ARC Raiders

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)](https://github.com/jordan-thirkle/arc-optimizer)
[![Game: ARC Raiders](https://img.shields.io/badge/Game-ARC%20Raiders-00E5FF)](https://store.steampowered.com/app/1808500/ARC_Raiders/)
[![GitHub Stars](https://img.shields.io/github/stars/jordan-thirkle/arc-optimizer?style=social)](https://github.com/jordan-thirkle/arc-optimizer)

**Arc Optimizer** is a free, open-source Windows desktop utility that automatically optimizes ARC Raiders (Unreal Engine 5) for competitive PvP performance. With one click, it applies 22 proven settings — DLSS Balanced + Transformer, Reflex Boost, uncapped FPS, exclusive fullscreen, and Engine.ini visual tweaks — while creating automatic backups. No dependencies, no browser, no web server.

> **Built for ARC Raiders on Steam. Also compatible with The Finals (same engine/config system).**

---

## Features

| Feature | Description |
|---------|-------------|
| **One-Click Optimization** | Applies 22 settings, creates Engine.ini with UE5 visual clutter disabled, sets read-only |
| **Automatic Backups** | Every optimization creates a timestamped backup in `ArcOptimizer_Backups` |
| **Live System Dashboard** | Detects GPU, driver, VRAM, Reflex status, power plan, audio devices |
| **Color-Coded Settings Table** | Green = optimized, orange = needs update, gray = missing from config |
| **Configuration Health Check** | Tests all 22 settings, shows percentage, validates Engine.ini presence |
| **NVIDIA Optimization Guide** | Low Latency Ultra, Power Max Performance, Shader Cache, DLSS Override |
| **Windows Tuning Guide** | HAGS, Game Mode, fullscreen optimizations, power plan |
| **Audio Tuning Guide** | Windows Sonic, 24-bit 48kHz, SupremeFX driver, Night Mode |
| **Backup Manager** | View and restore from timestamped backup list with one-click restore |
| **Dark & Light Theme** | Automatically respects Windows system dark/light mode |
| **Keyboard Navigation** | Tab between controls, Ctrl+O optimize, Ctrl+R restore, Ctrl+T test |
| **Accessibility** | Screen reader support via accessible names and roles |
| **Standalone EXE** | No dependencies — single executable, no PowerShell required |

## Requirements

| Requirement | Notes |
|-------------|-------|
| **OS** | Windows 10 or Windows 11 |
| **GPU** | NVIDIA (uses `nvidia-smi` for auto-detection) |
| **Game** | ARC Raiders (Steam or WinGDK), launched at least once |
| **PowerShell** | 5.1+ (built into Windows, no installation needed) |

**Zero additional dependencies.** No Python, Node.js, .NET SDK, or web browser required.

## Quick Start

```powershell
# 1. Download the latest release
# 2. Extract to any folder
# 3. Double-click Arc-Optimizer.cmd
# 4. Click "RUN OPTIMIZATION"
```

All changes include automatic backups. Restore anytime from the Backups tab.

## Optimized Settings

### GameUserSettings.ini (22 settings)

| Setting | Optimized Value | Impact | Why |
|---------|----------------|--------|-----|
| `sg.ViewDistanceQuality` | 3 (High) | HIGH | See enemies at longer range |
| `sg.FoliageQuality` | 0 (Low) | HIGH | See through bushes — PvP advantage |
| `sg.ShadowQuality` | 0 (Low) | HIGH | Spot enemies in shadows + FPS gain |
| `NvReflexMode` | Boost | HIGH | Lowest input latency |
| `FrameRateLimit` | 0 (Uncapped) | HIGH | Reflex works best uncapped |
| `FullscreenMode` | 0 (Exclusive) | HIGH | Lowest input latency mode |
| `RTXGIQuality` | Static | HIGH | RT ray tracing kills FPS |
| `DLSSMode` | Balanced | MEDIUM | Best FPS/clarity tradeoff |
| `DLSSModel` | Transformer | MEDIUM | DLSS 4.5 — sharper, less ghosting |
| `sg.TextureQuality` | 4 (Epic) | LOW | 12GB VRAM handles it |
| `MotionBlurScale` | 0 (Off) | MEDIUM | No blur during movement |

### Engine.ini (UE5 visual disables)

| Tweak | FPS Gain | Effect |
|-------|----------|--------|
| Motion Blur disabled | +2-5% | Spot enemies while turning |
| Depth of Field disabled | +1-3% | See enemies at any range |
| Volumetric Fog disabled | +3-8% | Critical for long-range PvP |
| Screen Space Reflections disabled | +3-6% | No competitive gameplay loss |
| Shadow Resolution 512 | +5-10% | Enemies easier to spot |
| Sharpen +0.5 | 0% | Crisper image without DLSS softening |
| Texture Pool 4GB | VARIES | Optimized for 12GB VRAM, reduces stutter |

## Manual Steps (Shown In-App)

- NVIDIA App → DLSS Override → Model Presets: Recommended
- Windows Settings → Enable HAGS, Game Mode, Windows Sonic
- `start_protected_game.exe` → Properties → Disable fullscreen optimizations

## Why Arc Optimizer?

| Approach | Dependencies | GUI | Auto-Backup | Settings Applied |
|----------|-------------|-----|-------------|-----------------|
| **Arc Optimizer** | None | Native WinForms | ✅ Timestamped | 22 + Engine.ini |
| Manual editing | None | None | ❌ | User-dependent |
| Generic optimizer | Often heavy | Web/browser | ❌ | Generic |
| Engine.ini from Discord | None | None | ❌ | 1 file only |

## Architecture

Arc Optimizer is a single PowerShell script (`.ps1`) using .NET Windows Forms. It runs via a lightweight `.cmd` launcher. The entire app is one file — edit `Arc-Optimizer.ps1` to customize any setting.

```
Arc-Optimizer/
├── Arc-Optimizer.cmd        # Launcher (double-click to run)
├── Arc-Optimizer.ps1        # Full WinForms GUI app (~30 KB)
├── README.md                # This file
├── LICENSE                  # MIT License
├── .gitignore
└── screenshots/
    └── app.png              # App screenshot
```

### Detection methods

- **GPU**: `nvidia-smi` query
- **Game install**: Steam path detection
- **Config**: `%LOCALAPPDATA%\PioneerGame\Saved\Config\WindowsClient\`
- **Power plan**: `powercfg` query
- **Audio**: WMI PnP device enumeration

## Competing with The Finals

Arc Raiders and The Finals share the same engine (Unreal Engine 5), developer (Embark Studios), and config system. Engine.ini tweaks validated on The Finals work identically on Arc Raiders. Both use `start_protected_game.exe` (EasyAntiCheat) — Engine.ini modifications are safe and widely used by competitive players.

## Changelog

### v1.2.0 (May 2026)
- **Regex-based optimization**: Works with ANY current setting values (not just exact matches)
- **Dynamic game detection**: Finds ARC Raiders on any drive or Steam library
- **Backup restore**: One-click restore from Backups tab
- **UTF-8 without BOM**: Config files safe for UE5 parser
- **Access denied fix**: Replaced `attrib` with .NET File API, proper error handling
- **Audio detection fix**: Correctly counts sound devices
- **Error coloring**: Log shows red for errors, green for success
- **Dynamic status bar**: Shows actual GPU driver + Windows build (not hardcoded)
- **System theme**: Automatically respects Windows dark/light mode
- **Keyboard navigation**: Tab between controls, Ctrl+O/R/T shortcuts, Esc to close
- **Accessibility**: Screen reader support via accessible names and roles
- **Standalone EXE**: No PowerShell dependencies — single executable
- **App icon**: Custom Arc Optimizer icon on title bar and taskbar
- **UI responsiveness**: DoEvents() prevents form freezing during scans
- Fixed: Engine.ini write access denied (read-only removed before write)
- Fixed: Paint event crash (CreateGraphics → Graphics, $this.BackColor)
- Fixed: DrawItem crash (bounds check + try/catch)
- Fixed: SolidBrush constructor crash (PaintEventArgs doesn't have BackColor)
- Fixed: Version label showing "v1.0" instead of actual version
- Fixed: Orphaned backups on read failure (read before backup)

### v1.1.0 (May 2026)
- Privacy consent dialog on first launch
- Try/catch on all operations
- `-Uninstall` command-line flag for clean removal
- Privacy indicator in title bar
- SECURITY.md for vulnerability reporting

### v1.0.0 (May 2026)
- Initial release with WinForms GUI
- One-click optimization (22 settings)
- Automatic timestamped backups
- Live system dashboard (GPU, driver, Reflex, power, audio)
- Settings comparison table with color coding
- Engine.ini visual tweaks guide
- NVIDIA/Windows/Audio tuning guides

## Roadmap

- [ ] Microsoft Store submission (MSIX packaging)
- [ ] Multi-language support
- [ ] Automatic update checking
- [ ] Custom preset system
- [ ] Per-map optimization profiles

## Acknowledgments

- [JagsFPS](https://youtube.com/@jagsfps) — ARC Raiders optimization research
- [r/OptimizedGaming](https://reddit.com/r/OptimizedGaming) — Per-setting breakdowns
- [PCGamingWiki](https://pcgamingwiki.com) — Config locations and engine tweaks
- NVIDIA — DLSS 4.5 / Reflex documentation
- Embark Studios — ARC Raiders & The Finals

## License

MIT — free to use, modify, and distribute. See [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://github.com/jordan-thirkle/arc-optimizer/issues">Report Bug</a> ·
  <a href="https://github.com/jordan-thirkle/arc-optimizer/discussions">Feature Request</a> ·
  <a href="https://github.com/jordan-thirkle/arc-optimizer">GitHub</a>
</p>
