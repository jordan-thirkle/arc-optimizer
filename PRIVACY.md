# Privacy Policy for Arc Optimizer

**Last updated: May 30, 2026**

## Overview

Arc Optimizer is a local desktop utility that optimizes ARC Raiders game configuration files. It operates entirely on your local machine and does not collect, transmit, or store any personal information.

## Data Collection

Arc Optimizer does **not** collect or transmit:
- Personal information (name, email, address, etc.)
- System information (hardware specs, etc.)
- Usage data or analytics
- Crash reports
- Game configuration data
- Files or documents

## Local System Access

Arc Optimizer accesses the following local system resources solely for optimization purposes:

| Resource | Purpose | Data Used |
|----------|---------|-----------|
| `nvidia-smi` | Detect GPU name, driver version, VRAM | Hardware identifiers (local only) |
| `powercfg` | Detect active power plan | Power scheme GUID (local only) |
| WMI | Detect audio devices | Device names (local only) |
| Game config files | Read/write optimization settings | Game settings (local only) |

All accessed data remains on your local machine. Nothing is transmitted over a network.

## Third-Party Services

Arc Optimizer does not use any third-party services, APIs, SDKs, or analytics frameworks. It makes no network connections of any kind.

## Changes to This Policy

If this privacy policy changes, the updated version will be published in this file with a new date.

## Contact

For questions about this privacy policy, open an issue on GitHub:
https://github.com/jordan-thirkle/arc-optimizer/issues
