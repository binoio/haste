# Haste for Apple Silicon

Native macOS (Apple Silicon arm64) implementation and data format suite for **Haste**, reverse-engineered from the original 1999–2000 Win32 financial engine (`QW.EXE`).

---

## Legal Notice & Disclaimers

> [!IMPORTANT]
> **Independent Research Project**: Haste is an independent open-source software project created strictly for historical software preservation, reverse engineering, and computer science research.
>
> **No Affiliation**: Haste is NOT affiliated with, sponsored by, authorized by, endorsed by, or associated in any way with Intuit Inc., Quicken Inc., Aquiline Capital Partners, or any of their parent, subsidiary, or affiliate corporations.
>
> **Trademark Notice**: "Quicken", "Quicken Deluxe", and associated logos, product names, and trade dress are registered trademarks of their respective trademark holders. Reference to these names is made solely for descriptive, historical, and comparative purposes under nominative fair use.
>
> **Disclaimer of Warranty**: The software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement.

---

## Architecture & Reverse Engineering Analysis

The financial engine was distributed via 12-volume InstallShield 5 cabinet archives (`DATA1.CAB` through `DATA12.CAB`). Extraction revealed a multi-tiered financial engine:

| Module | Subsystem | Format / Specification |
| :--- | :--- | :--- |
| `QW.EXE` | Main UI & Application | Win32 MFC Desktop Application |
| `QDB.DLL` | Core Database Engine | ISAM database with 4,088-byte pages (`0xFF8`), magic `0x8FBD9EAC`, version `0x00020000` |
| Cryptography | Security Subsystem | Intuit RC5-32/16/16 cipher ($P_{32}=0xB7E15163, Q_{32}=0x9E3779B9$) with MD5 page MAC integrity |
| `QWENC.DLL` | Credential Obfuscation | 32-bit bidirectional rotating cipher (`_lrotl` / `_lrotr`) |
| `QACCES32.DLL`| Account & Transaction API | c-tree B-Tree data structures, split items, and portfolio management |
| `QSD` | Structured Data | Length-prefixed string tables holding account names, categories, and views |
| `QIF` | Quicken Interchange Format | Tagged ASCII records (`!Type:Bank`, `D`, `T`, `C`, `P`, `M`, `L`, `S`, `$`, `^`) |

---

## Features

- **Native Apple Silicon Application (`Haste.app`)**: Built natively with Swift and SwiftUI targeting `arm64-apple-macos`.
- **Sparkle Auto-Updates**: Seamless integrated update mechanism via Sparkle framework.
- **Authentic Financial Interface**: Forest Green header bar, Activity Centers (Banking, Planning, Investing, Reports), and iconic QuickTabs.
- **Interactive Checkbook Register**: Full read/write register with classic dual-line and green-bar ledger styling, inline transaction entry, instant running balance calculation, cleared status toggling (`c`, `*`, `R`), and split transaction editor.
- **Bank Account Reconciliation ("Reconcile")**: Faithful reconciliation workflow matching statement balances against cleared checks and deposits, real-time difference calculation, and auto-adjustments.
- **Classic "Write Checks" Window**: Paper check interface with date, check number, address lines, memo, category, and automatic English spelled-out dollar amount translation.
- **Scheduled Bills & Financial Reminders**: Due date tracking, recurring frequencies (monthly, weekly, biweekly, quarterly, annually), and 1-click "Record in Register" action.
- **Planning & Budgets Center**: Monthly category budget targets vs actual spending with comparison progress bars, along with Loan / Mortgage and Savings planners.
- **Account Management**: Create and manage Bank, Credit Card, Cash, Investment, Asset, and Liability accounts with custom opening balances.
- **Binary Data Inspector**: Real-time inspection of era `.QDF`, `.QSD`, and `.QEL` files with page alignment, magic numbers, and encryption metadata.
- **Batch Dataset & QIF Round-Trip**: Directly reads all historical financial datasets with full QIF and CSV import/export support.

---

## Scripts & Operations

All operations are automated using macOS zsh scripts:

- **Build Application**:
  ```zsh
  ./build.sh
  ```
- **Run Application**:
  ```zsh
  ./run.sh
  ```
- **Execute Test Suite**:
  ```zsh
  ./test.sh
  ```
- **Notarize Application**:
  ```zsh
  ./notarize.sh "Developer ID Application: Your Name (TEAM_ID)" [KEYCHAIN_PROFILE]
  ```
