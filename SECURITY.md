# Security Policy

## Reporting a Vulnerability

Arc Optimizer is an open-source tool that modifies game configuration files. We take security seriously.

If you discover a security vulnerability, please **do not** open a public issue. Instead, email the repository owner directly or use GitHub's private vulnerability reporting feature.

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if applicable)

## What Arc Optimizer Does

Arc Optimizer:
- Reads and writes game configuration files (`GameUserSettings.ini`, `Engine.ini`)
- Reads system information via `nvidia-smi`, `powercfg`, and WMI
- Does **not** collect, transmit, or store personal information
- Does **not** modify system files outside the game's config directory
- Does **not** install additional software

## What Arc Optimizer Does NOT Do

- No telemetry or analytics
- No network connections
- No personal data collection
- No registry modifications (except reading)
- No kernel-level access
- No advertising
