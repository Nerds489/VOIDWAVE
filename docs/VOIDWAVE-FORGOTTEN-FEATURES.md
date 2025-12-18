# VOIDWAVE — Complete Forgotten Features Specification

> **Document Purpose:** Comprehensive specification for every feature that was planned, partially implemented, or forgotten during development.

> **Current State:** 292KB monolithic `bin/voidwave` script with `lib/` and `modules/` folders that exist but are NOT sourced or used.

> **Total Features:** 67 across 17 categories

---


# TABLE OF CONTENTS

1. [Architecture Refactor](#1-architecture-refactor)
   - 1.1 [Modular File Structure](#11-modular-file-structure)
   - 1.2 [lib/core.sh — Core Functions](#12-libcoresh--core-functions)
   - 1.3 [lib/ui.sh — User Interface](#13-libuish--user-interface)
   - 1.4 [lib/safety.sh — Validation & Safety](#14-libsafetysh--validation--safety)
   - 1.5 [lib/detection.sh — System Detection](#15-libdetectionsh--system-detection)
   - 1.6 [lib/utils.sh — Utilities](#16-libutilssh--utilities)
   - 1.7 [Module System](#17-module-system)
   - 1.8 [Thin Dispatcher Main Script](#18-thin-dispatcher-main-script)

2. [Wireless & Monitor Mode](#2-wireless--monitor-mode)
   - 2.1 [is_wireless_interface()](#21-is_wireless_interface)
   - 2.2 [get_wireless_interfaces()](#22-get_wireless_interfaces)
   - 2.3 [check_monitor_mode()](#23-check_monitor_mode)
   - 2.4 [enable_monitor_mode()](#24-enable_monitor_mode)
   - 2.5 [disable_monitor_mode()](#25-disable_monitor_mode)
   - 2.6 [validate_wireless_interface()](#26-validate_wireless_interface)

3. [Installer Improvements](#3-installer-improvements)
   - 3.1 [verify_tool_installed()](#31-verify_tool_installed)
   - 3.2 [create_manual_fix_guide()](#32-create_manual_fix_guide)
   - 3.3 [show_install_summary()](#33-show_install_summary)
   - 3.4 [Uninstall Menu Option](#34-uninstall-menu-option)
   - 3.5 [Missing Tools Addition](#35-missing-tools-addition)
   - 3.6 [Graceful Failure Handling](#36-graceful-failure-handling)

4. [Stress Testing Fixes](#4-stress-testing-fixes)
   - 4.1 [run_hping_attack() — Fixed](#41-run_hping_attack--fixed)
   - 4.2 [run_netem() — Fixed](#42-run_netem--fixed)
   - 4.3 [stress_prescan()](#43-stress_prescan)

5. [Smart Sudo & Privileges](#5-smart-sudo--privileges)
   - 5.1 [is_root()](#51-is_root)
   - 5.2 [require_root()](#52-require_root)
   - 5.3 [run_with_sudo()](#53-run_with_sudo)
   - 5.4 [elevate_if_needed()](#54-elevate_if_needed)

6. [Tool Management](#6-tool-management)
   - 6.1 [check_tool()](#61-check_tool)
   - 6.2 [auto_install_tool()](#62-auto_install_tool)
   - 6.3 [check_tool_version()](#63-check_tool_version)
   - 6.4 [Tool Dependency Management](#64-tool-dependency-management)

7. [Wizards](#7-wizards)
   - 7.1 [first_run_wizard()](#71-first_run_wizard)
   - 7.2 [scan_wizard()](#72-scan_wizard)
   - 7.3 [wifi_wizard()](#73-wifi_wizard)

8. [Logging System](#8-logging-system)
   - 8.1 [Log Levels](#81-log-levels)
   - 8.2 [log_debug()](#82-log_debug)
   - 8.3 [log_info()](#83-log_info)
   - 8.4 [log_success()](#84-log_success)
   - 8.5 [log_warning()](#85-log_warning)
   - 8.6 [log_error()](#86-log_error)
   - 8.7 [log_fatal()](#87-log_fatal)
   - 8.8 [log_audit()](#88-log_audit)
   - 8.9 [File Logging](#89-file-logging)

9. [Progress & Feedback](#9-progress--feedback)
   - 9.1 [show_spinner()](#91-show_spinner)
   - 9.2 [show_progress_bar()](#92-show_progress_bar)
   - 9.3 [start_timer() / stop_timer()](#93-start_timer--stop_timer)

10. [Confirmation Prompts](#10-confirmation-prompts)
    - 10.1 [confirm()](#101-confirm)
    - 10.2 [confirm_dangerous()](#102-confirm_dangerous)
    - 10.3 [select_option()](#103-select_option)
    - 10.4 [prompt_input()](#104-prompt_input)

11. [Target Validation & Safety](#11-target-validation--safety)
    - 11.1 [is_private_ip()](#111-is_private_ip)
    - 11.2 [is_valid_ip()](#112-is_valid_ip)
    - 11.3 [is_valid_cidr()](#113-is_valid_cidr)
    - 11.4 [validate_target()](#114-validate_target)
    - 11.5 [VW_UNSAFE_MODE](#115-nr_unsafe_mode)

12. [Wordlist Management](#12-wordlist-management)
    - 12.1 [check_wordlists()](#121-check_wordlists)
    - 12.2 [ensure_rockyou()](#122-ensure_rockyou)

13. [WHOIS Improvements](#13-whois-improvements)
    - 13.1 [run_whois() — Fixed](#131-run_whois--fixed)

14. [CLI Improvements](#14-cli-improvements)
    - 14.1 [--dry-run Flag](#141---dry-run-flag)
    - 14.2 [--json Output](#142---json-output)
    - 14.3 [--quiet Flag](#143---quiet-flag)
    - 14.4 [--verbose Flag](#144---verbose-flag)

15. [Configuration System](#15-configuration-system)
    - 15.1 [config_get()](#151-config_get)
    - 15.2 [config_set()](#152-config_set)
    - 15.3 [config_edit()](#153-config_edit)
    - 15.4 [Default Configuration](#154-default-configuration)

16. [Session Management](#16-session-management)
    - 16.1 [session_start()](#161-session_start)
    - 16.2 [session_save()](#162-session_save)
    - 16.3 [session_resume()](#163-session_resume)

17. [Testing Infrastructure](#17-testing-infrastructure)
    - 17.1 [Unit Tests with bats](#171-unit-tests-with-bats)
    - 17.2 [Integration Tests](#172-integration-tests)
    - 17.3 [CI Pipeline](#173-ci-pipeline)

---

# 1. ARCHITECTURE REFACTOR

## 1.1 Modular File Structure

### What It Does
Transforms the 292KB monolithic `bin/voidwave` into a clean, maintainable structure where:
- Shared code lives in `lib/`
- Feature-specific code lives in `modules/`
- Main script is a thin dispatcher (~100-150 lines)

### Why It Matters
- **Testability**: Individual functions can be unit tested
- **Maintainability**: Changes to one module don't risk breaking others
- **Contributions**: Contributors can work on specific modules
- **Readability**: Finding and understanding code is easy
- **Debugging**: Errors trace to specific files

### Target Structure
```
VOIDWAVE/
├── bin/
│   ├── voidwave              # Thin dispatcher (~150 lines)
│   └── voidwave-install      # Installer
├── lib/
│   ├── core.sh                # Colors, logging, output helpers
│   ├── ui.sh                  # Menus, prompts, input handling
│   ├── safety.sh              # Target validation, authorization
│   ├── detection.sh           # Distro, interface, tool detection
│   └── utils.sh               # Filesystem, network utilities
├── modules/
│   ├── recon.sh               # Reconnaissance functions
│   ├── wireless.sh            # WiFi attack functions
│   ├── scanning.sh            # Port scanning functions
│   ├── exploit.sh             # Exploitation functions
│   ├── credentials.sh         # Credential attack functions
│   ├── traffic.sh             # Traffic analysis functions
│   ├── osint.sh               # OSINT functions
│   └── stress.sh              # Stress testing functions
├── tests/
│   ├── lib/                   # Unit tests for lib/
│   ├── modules/               # Unit tests for modules/
│   └── integration/           # End-to-end tests
└── ...
```

---

## 1.2 lib/core.sh — Core Functions

### What It Does
Contains fundamental functions used everywhere: colors, basic logging, output formatting.

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE Core Library
# Copyright 2025 Nerds489

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_CORE_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_CORE_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════════════════

# Check if colors are supported
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    declare -r C_RESET='\033[0m'
    declare -r C_BOLD='\033[1m'
    declare -r C_DIM='\033[2m'
    
    # Standard colors
    declare -r C_RED='\033[38;5;196m'
    declare -r C_GREEN='\033[38;5;46m'
    declare -r C_YELLOW='\033[38;5;226m'
    declare -r C_BLUE='\033[38;5;39m'
    declare -r C_CYAN='\033[38;5;51m'
    declare -r C_MAGENTA='\033[38;5;201m'
    declare -r C_WHITE='\033[38;5;255m'
    declare -r C_GRAY='\033[38;5;244m'
    
    # Semantic colors
    declare -r C_SUCCESS="$C_GREEN"
    declare -r C_ERROR="$C_RED"
    declare -r C_WARNING="$C_YELLOW"
    declare -r C_INFO="$C_CYAN"
    declare -r C_DEBUG="$C_GRAY"
    declare -r C_PROMPT="$C_MAGENTA"
    
    # Brand colors
    declare -r C_FIRE='\033[38;5;202m'
    declare -r C_SKULL='\033[38;5;231m'
else
    # No colors
    declare -r C_RESET="" C_BOLD="" C_DIM=""
    declare -r C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
    declare -r C_CYAN="" C_MAGENTA="" C_WHITE="" C_GRAY=""
    declare -r C_SUCCESS="" C_ERROR="" C_WARNING="" C_INFO=""
    declare -r C_DEBUG="" C_PROMPT="" C_FIRE="" C_SKULL=""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════════════════

declare -r VOIDWAVE_HOME="${VOIDWAVE_HOME:-$HOME/.voidwave}"
declare -r VOIDWAVE_CONFIG_DIR="$VOIDWAVE_HOME/config"
declare -r VOIDWAVE_LOG_DIR="$VOIDWAVE_HOME/logs"
declare -r VOIDWAVE_OUTPUT_DIR="$VOIDWAVE_HOME/output"
declare -r VOIDWAVE_SESSION_DIR="$VOIDWAVE_HOME/sessions"
declare -r VOIDWAVE_LOOT_DIR="$VOIDWAVE_HOME/loot"

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING - BASIC OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

# Print with prefix
_print() {
    local prefix="$1" color="$2"
    shift 2
    echo -e "    ${color}${prefix}${C_RESET} $*"
}

# Basic output functions
print_info()    { _print "[*]" "$C_INFO" "$@"; }
print_success() { _print "[✓]" "$C_SUCCESS" "$@"; }
print_warning() { _print "[!]" "$C_WARNING" "$@"; }
print_error()   { _print "[✗]" "$C_ERROR" "$@"; }
print_debug()   { [[ "${DEBUG:-0}" == "1" ]] && _print "[D]" "$C_DEBUG" "$@"; }

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

# Timestamp for logs
timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

# Timestamp for display
timestamp_display() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Press enter to continue
press_enter() {
    echo -ne "    ${C_PROMPT}Press Enter to continue...${C_RESET}"
    read -r
}

# Clear screen with banner preservation option
clear_screen() {
    if [[ "${PRESERVE_BANNER:-0}" == "1" ]]; then
        tput cup 0 0
        tput ed
    else
        clear
    fi
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Initialize VOIDWAVE directories
init_directories() {
    ensure_dir "$VOIDWAVE_HOME"
    ensure_dir "$VOIDWAVE_CONFIG_DIR"
    ensure_dir "$VOIDWAVE_LOG_DIR"
    ensure_dir "$VOIDWAVE_OUTPUT_DIR"
    ensure_dir "$VOIDWAVE_SESSION_DIR"
    ensure_dir "$VOIDWAVE_LOOT_DIR"
}
```

### Where It Goes
`lib/core.sh`

### How It Gets Used
```bash
# At top of main voidwave script:
source "$SCRIPT_DIR/lib/core.sh"

# Then use anywhere:
print_success "Scan complete"
print_error "Target unreachable"
```

---

## 1.3 lib/ui.sh — User Interface

### What It Does
All menu drawing, user input handling, banners, and visual elements.

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE UI Library

[[ -n "${_VOIDWAVE_UI_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_UI_LOADED=1

# Depends on: lib/core.sh

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    local version="${1:-}"
    
    echo -e "${C_FIRE}"
    cat << 'EOF'
    ███╗   ██╗███████╗████████╗██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗
    ████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
    ██╔██╗ ██║█████╗     ██║   ██████╔╝█████╗  ███████║██████╔╝█████╗  ██████╔╝
    ██║╚██╗██║██╔══╝     ██║   ██╔══██╗██╔══╝  ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗
    ██║ ╚████║███████╗   ██║   ██║  ██║███████╗██║  ██║██║     ███████╗██║  ██║
    ╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${C_RESET}"
    
    if [[ -n "$version" ]]; then
        echo -e "    ${C_GRAY}v${version} — Phantom Protocol${C_RESET}"
    fi
    echo
}

# ═══════════════════════════════════════════════════════════════════════════════
# BOXES & LINES
# ═══════════════════════════════════════════════════════════════════════════════

# Draw a horizontal line
draw_line() {
    local char="${1:-─}" width="${2:-70}" color="${3:-$C_GRAY}"
    printf "    ${color}"
    printf '%*s' "$width" | tr ' ' "$char"
    printf "${C_RESET}\n"
}

# Draw a header box
draw_header() {
    local title="$1" color="${2:-$C_FIRE}"
    local width=70
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo -e "    ${color}╔$(printf '═%.0s' $(seq 1 $width))╗${C_RESET}"
    echo -e "    ${color}║$(printf ' %.0s' $(seq 1 $padding))${C_BOLD}${title}${C_RESET}${color}$(printf ' %.0s' $(seq 1 $((width - padding - ${#title}))))║${C_RESET}"
    echo -e "    ${color}╚$(printf '═%.0s' $(seq 1 $width))╝${C_RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MENUS
# ═══════════════════════════════════════════════════════════════════════════════

# Show a menu and get selection
# Usage: show_menu "Title" "Option 1" "Option 2" "Option 3"
# Returns: Selected index (1-based) or 0 for quit
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selection
    
    clear_screen
    show_banner "$VERSION"
    draw_header "$title"
    echo
    
    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${C_CYAN}[$i]${C_RESET} $opt"
        ((i++))
    done
    echo
    echo -e "    ${C_GRAY}[Q] Quit${C_RESET}"
    echo
    
    echo -ne "    ${C_PROMPT}Select: ${C_RESET}"
    read -r selection
    
    case "${selection,,}" in
        q|quit|exit) return 0 ;;
        *[!0-9]*) return 255 ;;  # Invalid
        *)
            if [[ "$selection" -ge 1 && "$selection" -le "${#options[@]}" ]]; then
                return "$selection"
            fi
            return 255
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

# Get input with optional default
# Usage: result=$(get_input "Enter target" "192.168.1.1")
get_input() {
    local prompt="$1" default="${2:-}"
    local input
    
    if [[ -n "$default" ]]; then
        echo -ne "    ${C_PROMPT}${prompt} [${default}]: ${C_RESET}"
    else
        echo -ne "    ${C_PROMPT}${prompt}: ${C_RESET}"
    fi
    
    read -r input
    echo "${input:-$default}"
}

# Get password (hidden input)
get_password() {
    local prompt="$1"
    local password
    
    echo -ne "    ${C_PROMPT}${prompt}: ${C_RESET}"
    read -rs password
    echo
    echo "$password"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

# Show tool status grid
show_tool_status() {
    local -n tools_ref=$1  # nameref to associative array
    local category="$2"
    local cols=5
    local count=0
    
    echo -e "    ${C_BOLD}${category}:${C_RESET}"
    
    for tool in "${!tools_ref[@]}"; do
        if command -v "$tool" &>/dev/null; then
            printf "    ${C_GREEN}✓${C_RESET}%-14s" "$tool"
        else
            printf "    ${C_RED}✗${C_RESET}%-14s" "$tool"
        fi
        ((count++))
        [[ $((count % cols)) -eq 0 ]] && echo
    done
    [[ $((count % cols)) -ne 0 ]] && echo
}
```

### Where It Goes
`lib/ui.sh`

---

## 1.4 lib/safety.sh — Validation & Safety

### What It Does
All target validation, authorization checks, and safety confirmations.

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE Safety Library

[[ -n "${_VOIDWAVE_SAFETY_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_SAFETY_LOADED=1

# Depends on: lib/core.sh

# ═══════════════════════════════════════════════════════════════════════════════
# AUTHORIZATION
# ═══════════════════════════════════════════════════════════════════════════════

declare -r AUTH_FILE="$VOIDWAVE_CONFIG_DIR/authorized"
declare -r LEGAL_FILE="$VOIDWAVE_CONFIG_DIR/legal_accepted"

# Check if user has accepted legal terms
check_legal() {
    # Skip in non-interactive mode
    if is_non_interactive; then
        ensure_dir "$(dirname "$LEGAL_FILE")"
        [[ -f "$LEGAL_FILE" ]] || echo "$(date -Iseconds) | auto-accepted (non-interactive)" > "$LEGAL_FILE"
        return 0
    fi
    
    [[ -f "$LEGAL_FILE" ]] && return 0
    
    # Show legal disclaimer and require acceptance
    clear_screen
    echo -e "${C_RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                        ⚠️  LEGAL DISCLAIMER                           ║
    ╠═══════════════════════════════════════════════════════════════════════╣
    ║                                                                       ║
    ║  VOIDWAVE is a penetration testing tool intended for                ║
    ║  AUTHORIZED SECURITY TESTING ONLY.                                   ║
    ║                                                                       ║
    ║  By using this tool, you agree to:                                   ║
    ║  • Only test systems you have WRITTEN AUTHORIZATION to test          ║
    ║  • Accept FULL LEGAL RESPONSIBILITY for your actions                 ║
    ║  • Understand that UNAUTHORIZED ACCESS IS A CRIMINAL OFFENSE         ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
    
    echo -ne "    ${C_PROMPT}Type 'I ACCEPT' to continue: ${C_RESET}"
    read -r response
    
    if [[ "$response" != "I ACCEPT" ]]; then
        print_error "You must accept the terms to use VOIDWAVE"
        exit 1
    fi
    
    ensure_dir "$(dirname "$LEGAL_FILE")"
    echo "$(date -Iseconds) | $(whoami)@$(hostname) | Accepted" > "$LEGAL_FILE"
    print_success "Terms accepted"
}

# Check authorization for engagement
check_authorization() {
    [[ -f "$AUTH_FILE" ]] && return 0
    
    if is_non_interactive; then
        return 0  # Skip in CI/automated mode
    fi
    
    print_warning "First run detected - authorization required"
    echo
    
    local engagement
    engagement=$(get_input "Enter engagement/client name")
    
    if [[ -z "$engagement" ]]; then
        print_error "Engagement name required"
        return 1
    fi
    
    ensure_dir "$(dirname "$AUTH_FILE")"
    {
        echo "Engagement: $engagement"
        echo "Authorized: $(date -Iseconds)"
        echo "User: $(whoami)@$(hostname)"
    } > "$AUTH_FILE"
    
    log_audit "AUTH" "Engagement authorized: $engagement"
    print_success "Authorization recorded"
}

# ═══════════════════════════════════════════════════════════════════════════════
# IP VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if IP is in private range
is_private_ip() {
    local ip="$1"
    
    # Remove CIDR notation if present
    ip="${ip%%/*}"
    
    # Check private ranges
    case "$ip" in
        10.*) return 0 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 0 ;;
        192.168.*) return 0 ;;
        127.*) return 0 ;;
        169.254.*) return 0 ;;  # Link-local
        *) return 1 ;;
    esac
}

# Validate IP address format
is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$ip" =~ $regex ]]; then
        return 1
    fi
    
    # Check each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

# Validate CIDR notation
is_valid_cidr() {
    local cidr="$1"
    local ip prefix
    
    if [[ "$cidr" != */* ]]; then
        return 1
    fi
    
    ip="${cidr%/*}"
    prefix="${cidr#*/}"
    
    is_valid_ip "$ip" || return 1
    
    if [[ ! "$prefix" =~ ^[0-9]+$ ]] || [[ "$prefix" -lt 0 || "$prefix" -gt 32 ]]; then
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# TARGET VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

# Validate target before operations
validate_target() {
    local target="$1"
    local allow_public="${2:-false}"
    
    # Block entire internet
    if [[ "$target" == "0.0.0.0/0" ]]; then
        print_error "BLOCKED: Cannot target entire internet (0.0.0.0/0)"
        return 1
    fi
    
    # Block broadcast
    if [[ "$target" == "255.255.255.255" ]]; then
        print_error "BLOCKED: Cannot target broadcast address"
        return 1
    fi
    
    # Extract IP from CIDR if needed
    local ip="${target%%/*}"
    
    # Validate format
    if ! is_valid_ip "$ip"; then
        # Might be a hostname - allow it
        if [[ "$target" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            return 0
        fi
        print_error "Invalid target format: $target"
        return 1
    fi
    
    # Check public IP
    if ! is_private_ip "$ip"; then
        if [[ "${VW_UNSAFE_MODE:-false}" != "true" && "$allow_public" != "true" ]]; then
            print_warning "Target appears to be a PUBLIC IP: $target"
            print_info "Public IP targeting requires explicit confirmation"
            
            if ! confirm_dangerous "Target public IP $target?"; then
                print_info "Operation cancelled"
                return 1
            fi
            
            log_audit "TARGET" "Public IP confirmed: $target"
        fi
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIRMATION PROMPTS
# ═══════════════════════════════════════════════════════════════════════════════

# Simple yes/no confirmation
# Usage: confirm "Continue?" "y"  # default yes
confirm() {
    local prompt="$1" default="${2:-n}"
    local response
    
    if is_non_interactive; then
        [[ "${default,,}" == "y" ]] && return 0 || return 1
    fi
    
    if [[ "${default,,}" == "y" ]]; then
        echo -ne "    ${C_PROMPT}${prompt} [Y/n]: ${C_RESET}"
    else
        echo -ne "    ${C_PROMPT}${prompt} [y/N]: ${C_RESET}"
    fi
    
    read -r response
    response="${response:-$default}"
    
    [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]
}

# Dangerous operation - requires typing YES
confirm_dangerous() {
    local prompt="$1"
    local response
    
    if is_non_interactive; then
        return 1  # Never auto-confirm dangerous in non-interactive
    fi
    
    echo -e "    ${C_RED}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_YELLOW}⚠️  DANGEROUS OPERATION${C_RESET}                                     ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  $prompt"
    echo -e "    ${C_RED}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo
    echo -ne "    ${C_RED}Type 'YES' to confirm: ${C_RESET}"
    read -r response
    
    [[ "$response" == "YES" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if running non-interactively (CI, scripts, no TTY)
is_non_interactive() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" || ! -t 0 ]]
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}
```

### Where It Goes
`lib/safety.sh`

---

## 1.5 lib/detection.sh — System Detection

### What It Does
Detects distro, package manager, wireless interfaces, installed tools.

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE Detection Library

[[ -n "${_VOIDWAVE_DETECTION_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_DETECTION_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# DISTRO DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Detect Linux distribution
detect_distro() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro="${ID:-unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        source /etc/lsb-release
        distro="${DISTRIB_ID,,}"
    elif command -v lsb_release &>/dev/null; then
        distro="$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    fi
    
    echo "${distro:-unknown}"
}

# Detect distribution family
detect_distro_family() {
    local distro
    distro=$(detect_distro)
    
    case "$distro" in
        ubuntu|debian|kali|parrot|linuxmint|pop|elementary|zorin)
            echo "debian"
            ;;
        fedora|rhel|centos|rocky|alma|oracle)
            echo "redhat"
            ;;
        arch|manjaro|endeavouros|garuda|artix)
            echo "arch"
            ;;
        opensuse*|suse*)
            echo "suse"
            ;;
        alpine)
            echo "alpine"
            ;;
        void)
            echo "void"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# PACKAGE MANAGER
# ═══════════════════════════════════════════════════════════════════════════════

# Detect and configure package manager
detect_package_manager() {
    local family
    family=$(detect_distro_family)
    
    case "$family" in
        debian)
            echo "apt"
            ;;
        redhat)
            if command -v dnf &>/dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        arch)
            echo "pacman"
            ;;
        suse)
            echo "zypper"
            ;;
        alpine)
            echo "apk"
            ;;
        void)
            echo "xbps"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Set up package manager commands
setup_package_manager() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        apt)
            PKG_MANAGER="apt-get"
            PKG_INSTALL="apt-get install -y"
            PKG_UPDATE="apt-get update"
            PKG_SEARCH="apt-cache search"
            ;;
        dnf)
            PKG_MANAGER="dnf"
            PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update"
            PKG_SEARCH="dnf search"
            ;;
        yum)
            PKG_MANAGER="yum"
            PKG_INSTALL="yum install -y"
            PKG_UPDATE="yum check-update"
            PKG_SEARCH="yum search"
            ;;
        pacman)
            PKG_MANAGER="pacman"
            PKG_INSTALL="pacman -S --noconfirm"
            PKG_UPDATE="pacman -Sy"
            PKG_SEARCH="pacman -Ss"
            ;;
        zypper)
            PKG_MANAGER="zypper"
            PKG_INSTALL="zypper install -y"
            PKG_UPDATE="zypper refresh"
            PKG_SEARCH="zypper search"
            ;;
        apk)
            PKG_MANAGER="apk"
            PKG_INSTALL="apk add"
            PKG_UPDATE="apk update"
            PKG_SEARCH="apk search"
            ;;
        *)
            PKG_MANAGER="unknown"
            PKG_INSTALL=""
            PKG_UPDATE=""
            PKG_SEARCH=""
            ;;
    esac
    
    export PKG_MANAGER PKG_INSTALL PKG_UPDATE PKG_SEARCH
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOOL DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if a tool is installed
check_tool() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# Get full path of a tool
get_tool_path() {
    local tool="$1"
    command -v "$tool" 2>/dev/null
}

# Get tool version (best effort)
get_tool_version() {
    local tool="$1"
    local version=""
    
    if ! check_tool "$tool"; then
        echo "not installed"
        return 1
    fi
    
    # Try common version flags
    for flag in --version -version -v -V; do
        version=$("$tool" "$flag" 2>/dev/null | head -1)
        if [[ -n "$version" ]]; then
            # Extract version number
            version=$(echo "$version" | grep -oP '\d+\.\d+(\.\d+)?' | head -1)
            if [[ -n "$version" ]]; then
                echo "$version"
                return 0
            fi
        fi
    done
    
    echo "unknown"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERFACE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if interface exists
check_interface() {
    local iface="$1"
    [[ -n "$iface" && -d "/sys/class/net/$iface" ]]
}

# Check if interface is wireless
is_wireless_interface() {
    local iface="$1"
    [[ -d "/sys/class/net/$iface/wireless" ]] || \
    iw dev "$iface" info &>/dev/null 2>&1
}

# Get all wireless interfaces
get_wireless_interfaces() {
    local interfaces=()
    local iface
    
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        if is_wireless_interface "$iface"; then
            interfaces+=("$iface")
        fi
    done
    
    echo "${interfaces[@]}"
}

# Get default network interface
get_default_interface() {
    ip route | awk '/default/ {print $5; exit}'
}

# Get interface state (up/down)
get_interface_state() {
    local iface="$1"
    cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "unknown"
}

# Get interface MAC address
get_interface_mac() {
    local iface="$1"
    cat "/sys/class/net/$iface/address" 2>/dev/null || echo "unknown"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM INFO
# ═══════════════════════════════════════════════════════════════════════════════

# Detect complete system info
detect_system() {
    export SYS_DISTRO=$(detect_distro)
    export SYS_DISTRO_FAMILY=$(detect_distro_family)
    export SYS_PKG_MANAGER=$(detect_package_manager)
    export SYS_KERNEL=$(uname -r)
    export SYS_ARCH=$(uname -m)
    export SYS_HOSTNAME=$(hostname)
    export SYS_USER=$(whoami)
    
    setup_package_manager
}
```

### Where It Goes
`lib/detection.sh`

---

## 1.6 lib/utils.sh — Utilities

### What It Does
Miscellaneous utility functions: file handling, network helpers, wordlists.

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE Utilities Library

[[ -n "${_VOIDWAVE_UTILS_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_UTILS_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# FILE UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

# Create timestamped output file
create_output_file() {
    local prefix="$1" extension="${2:-txt}"
    local filename="${prefix}_$(timestamp).${extension}"
    local filepath="$VOIDWAVE_OUTPUT_DIR/$filename"
    
    touch "$filepath"
    echo "$filepath"
}

# Backup a file before modification
backup_file() {
    local file="$1"
    local backup="${file}.backup.$(timestamp)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        echo "$backup"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# WORDLISTS
# ═══════════════════════════════════════════════════════════════════════════════

# Common wordlist locations
declare -a WORDLIST_PATHS=(
    "/usr/share/wordlists"
    "/usr/share/seclists"
    "/opt/wordlists"
    "$HOME/wordlists"
)

# Check if wordlists directory exists
check_wordlists() {
    for path in "${WORDLIST_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Ensure rockyou.txt is available and decompressed
ensure_rockyou() {
    local rockyou_locations=(
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt"
    )
    local rockyou_gz=(
        "/usr/share/wordlists/rockyou.txt.gz"
    )
    
    # Check if already available
    for loc in "${rockyou_locations[@]}"; do
        if [[ -f "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done
    
    # Check for compressed version
    for gz in "${rockyou_gz[@]}"; do
        if [[ -f "$gz" ]]; then
            print_info "Found compressed rockyou.txt, decompressing..."
            if confirm "Decompress rockyou.txt.gz?" "y"; then
                sudo gunzip -k "$gz" 2>/dev/null || gunzip -k "$gz"
                local decompressed="${gz%.gz}"
                if [[ -f "$decompressed" ]]; then
                    print_success "Decompressed to $decompressed"
                    echo "$decompressed"
                    return 0
                fi
            fi
        fi
    done
    
    print_warning "rockyou.txt not found"
    print_info "Install with: sudo apt install wordlists"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# NETWORK UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

# Quick ping check
is_host_alive() {
    local host="$1" timeout="${2:-2}"
    ping -c 1 -W "$timeout" "$host" &>/dev/null
}

# Get external IP
get_external_ip() {
    local services=(
        "https://ifconfig.me"
        "https://ipinfo.io/ip"
        "https://api.ipify.org"
    )
    
    for service in "${services[@]}"; do
        local ip
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null)
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    return 1
}

# Resolve hostname to IP
resolve_hostname() {
    local hostname="$1"
    
    # Try getent first
    if command -v getent &>/dev/null; then
        getent hosts "$hostname" 2>/dev/null | awk '{print $1; exit}'
        return
    fi
    
    # Fall back to dig
    if command -v dig &>/dev/null; then
        dig +short "$hostname" 2>/dev/null | head -1
        return
    fi
    
    # Fall back to host
    if command -v host &>/dev/null; then
        host "$hostname" 2>/dev/null | awk '/has address/ {print $4; exit}'
        return
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STRING UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

# Trim whitespace
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Check if string is empty or whitespace
is_empty() {
    local var
    var=$(trim "$1")
    [[ -z "$var" ]]
}

# Generate random string
random_string() {
    local length="${1:-16}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}
```

### Where It Goes
`lib/utils.sh`

---

## 1.7 Module System

### What It Does
Each module is a self-contained file with:
- Module metadata (name, description, required tools)
- Tool wrapper functions
- Module-specific menu

### Implementation — modules/recon.sh Example

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE Recon Module

[[ -n "${_VOIDWAVE_MODULE_RECON_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_MODULE_RECON_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE METADATA
# ═══════════════════════════════════════════════════════════════════════════════

MODULE_RECON_NAME="recon"
MODULE_RECON_DESC="Reconnaissance & Scanning"
MODULE_RECON_TOOLS=(nmap masscan rustscan netdiscover dnsenum sslscan enum4linux)

# Register module (called by main script)
register_module_recon() {
    MODULES["recon"]="$MODULE_RECON_DESC"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NMAP FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

run_nmap_quick() {
    local target="$1"
    
    require_root || return 1
    check_tool nmap || return 1
    validate_target "$target" || return 1
    
    local output_file
    output_file=$(create_output_file "nmap_quick_${target//\//_}")
    
    log_info "Running quick nmap scan on $target"
    log_command_preview "nmap -T4 -F $target"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: nmap -T4 -F $target"
        return 0
    fi
    
    start_timer
    nmap -T4 -F "$target" -oN "$output_file" 2>&1 | tee -a "$VOIDWAVE_LOG_DIR/nmap.log"
    local exit_code=$?
    stop_timer
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Scan complete in $(get_elapsed_time)"
        log_info "Output saved to: $output_file"
        log_audit "SCAN" "nmap quick $target" "SUCCESS"
    else
        log_error "Scan failed with exit code $exit_code"
        log_audit "SCAN" "nmap quick $target" "FAILED"
    fi
    
    return $exit_code
}

run_nmap_full() {
    local target="$1"
    
    require_root || return 1
    check_tool nmap || return 1
    validate_target "$target" || return 1
    
    local output_file
    output_file=$(create_output_file "nmap_full_${target//\//_}")
    
    log_info "Running full nmap scan on $target (this may take a while)"
    log_command_preview "nmap -sS -sV -sC -O -p- $target"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: nmap -sS -sV -sC -O -p- $target"
        return 0
    fi
    
    start_timer
    nmap -sS -sV -sC -O -p- "$target" -oN "$output_file" 2>&1 | tee -a "$VOIDWAVE_LOG_DIR/nmap.log"
    local exit_code=$?
    stop_timer
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Full scan complete in $(get_elapsed_time)"
        log_info "Output saved to: $output_file"
    else
        log_error "Scan failed"
    fi
    
    return $exit_code
}

run_nmap_vuln() {
    local target="$1"
    
    require_root || return 1
    check_tool nmap || return 1
    validate_target "$target" || return 1
    
    log_info "Running vulnerability scan on $target"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: nmap --script vuln $target"
        return 0
    fi
    
    nmap --script vuln "$target"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MASSCAN FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

run_masscan() {
    local target="$1" ports="${2:-1-65535}" rate="${3:-10000}"
    
    require_root || return 1
    check_tool masscan || return 1
    validate_target "$target" || return 1
    
    log_info "Running masscan on $target (ports: $ports, rate: $rate)"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: masscan $target -p$ports --rate $rate"
        return 0
    fi
    
    masscan "$target" -p"$ports" --rate "$rate"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE MENU
# ═══════════════════════════════════════════════════════════════════════════════

recon_menu() {
    while true; do
        clear_screen
        show_banner "$VERSION"
        draw_header "RECONNAISSANCE"
        echo
        echo -e "    ${C_CYAN}[1]${C_RESET} Quick Scan (nmap -T4 -F)"
        echo -e "    ${C_CYAN}[2]${C_RESET} Full Scan (nmap full + scripts)"
        echo -e "    ${C_CYAN}[3]${C_RESET} Vulnerability Scan"
        echo -e "    ${C_CYAN}[4]${C_RESET} Fast Port Scan (masscan)"
        echo -e "    ${C_CYAN}[5]${C_RESET} Network Discovery"
        echo -e "    ${C_CYAN}[6]${C_RESET} DNS Enumeration"
        echo -e "    ${C_CYAN}[7]${C_RESET} SSL/TLS Scan"
        echo
        echo -e "    ${C_GRAY}[B] Back${C_RESET}"
        echo
        
        local choice target
        echo -ne "    ${C_PROMPT}Select: ${C_RESET}"
        read -r choice
        
        case "$choice" in
            1)
                target=$(get_input "Enter target (IP/CIDR/hostname)")
                [[ -n "$target" ]] && run_nmap_quick "$target"
                press_enter
                ;;
            2)
                target=$(get_input "Enter target")
                [[ -n "$target" ]] && run_nmap_full "$target"
                press_enter
                ;;
            3)
                target=$(get_input "Enter target")
                [[ -n "$target" ]] && run_nmap_vuln "$target"
                press_enter
                ;;
            4)
                target=$(get_input "Enter target")
                [[ -n "$target" ]] && run_masscan "$target"
                press_enter
                ;;
            [bB]) return ;;
            *) print_error "Invalid option" ;;
        esac
    done
}
```

### Module Template

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# VOIDWAVE [MODULE_NAME] Module

[[ -n "${_VOIDWAVE_MODULE_[NAME]_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_MODULE_[NAME]_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE METADATA
# ═══════════════════════════════════════════════════════════════════════════════

MODULE_[NAME]_NAME="[name]"
MODULE_[NAME]_DESC="[Description]"
MODULE_[NAME]_TOOLS=([tool1] [tool2] [tool3])

# Register module
register_module_[name]() {
    MODULES["[name]"]="$MODULE_[NAME]_DESC"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOOL FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

run_[tool]() {
    local target="$1"
    
    # Pre-checks
    require_root || return 1      # If needed
    check_tool [tool] || return 1
    validate_target "$target" || return 1
    
    # Logging
    log_info "Running [tool] on $target"
    log_command_preview "[tool command]"
    
    # Dry-run support
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: [command]"
        return 0
    fi
    
    # Execute
    [tool command]
    
    # Audit
    log_audit "[CATEGORY]" "[tool] $target" "SUCCESS"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE MENU
# ═══════════════════════════════════════════════════════════════════════════════

[name]_menu() {
    while true; do
        clear_screen
        show_banner "$VERSION"
        draw_header "[MODULE NAME]"
        echo
        # Menu options
        echo -e "    ${C_CYAN}[1]${C_RESET} Option 1"
        echo -e "    ${C_CYAN}[2]${C_RESET} Option 2"
        echo
        echo -e "    ${C_GRAY}[B] Back${C_RESET}"
        echo
        
        local choice
        echo -ne "    ${C_PROMPT}Select: ${C_RESET}"
        read -r choice
        
        case "$choice" in
            1) run_[tool1] ;;
            2) run_[tool2] ;;
            [bB]) return ;;
            *) print_error "Invalid option" ;;
        esac
    done
}
```

---

## 1.8 Thin Dispatcher Main Script

### What It Does
The main `voidwave` script becomes a thin dispatcher that:
- Sources all libraries
- Sources all modules
- Parses arguments
- Dispatches to appropriate functions

### Implementation

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# ═══════════════════════════════════════════════════════════════════════════════
#
#    VOIDWAVE — Unified Offensive Security Framework
#    Copyright 2025
#
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# VERSION & PATHS
# ═══════════════════════════════════════════════════════════════════════════════

readonly VERSION="7.0.0"
readonly CODENAME="Modular"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ═══════════════════════════════════════════════════════════════════════════════
# SOURCE LIBRARIES
# ═══════════════════════════════════════════════════════════════════════════════

source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/detection.sh"
source "$SCRIPT_DIR/lib/safety.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# SOURCE MODULES
# ═══════════════════════════════════════════════════════════════════════════════

declare -A MODULES

for module in "$SCRIPT_DIR/modules/"*.sh; do
    if [[ -f "$module" ]]; then
        # shellcheck disable=SC1090
        source "$module"
        
        # Call registration function if it exists
        local module_name
        module_name=$(basename "$module" .sh)
        if declare -f "register_module_${module_name}" &>/dev/null; then
            "register_module_${module_name}"
        fi
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════

main_menu() {
    while true; do
        clear_screen
        show_banner "$VERSION"
        draw_header "MAIN MENU"
        echo
        echo -e "    ${C_CYAN}[1]${C_RESET} 🔍 Recon          ${C_CYAN}[2]${C_RESET} 📡 Wireless"
        echo -e "    ${C_CYAN}[3]${C_RESET} 🎯 Scanning       ${C_CYAN}[4]${C_RESET} 💀 Exploit"
        echo -e "    ${C_CYAN}[5]${C_RESET} 🔑 Credentials    ${C_CYAN}[6]${C_RESET} 📊 Traffic"
        echo -e "    ${C_CYAN}[7]${C_RESET} 🌐 OSINT          ${C_CYAN}[8]${C_RESET} 🔥 Stress"
        echo
        echo -e "    ${C_GRAY}[S] Status    [C] Config    [W] Wizard    [H] Help${C_RESET}"
        echo -e "    ${C_GRAY}[Q] Quit${C_RESET}"
        echo
        
        local choice
        echo -ne "    ${C_PROMPT}Select: ${C_RESET}"
        read -r choice
        
        case "$choice" in
            1) recon_menu ;;
            2) wireless_menu ;;
            3) scanning_menu ;;
            4) exploit_menu ;;
            5) credentials_menu ;;
            6) traffic_menu ;;
            7) osint_menu ;;
            8) stress_menu ;;
            [sS]) show_status ;;
            [cC]) config_menu ;;
            [wW]) wizard_menu ;;
            [hH]) show_help ;;
            [qQ]) exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI PARSING
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat << EOF
VOIDWAVE v${VERSION} — Unified Offensive Security Framework

Usage: voidwave [options] [command] [arguments]

Commands:
    menu                    Launch interactive menu (default)
    scan <target>           Quick network scan
    wifi <subcommand>       Wireless operations
    status                  Show tool status
    wizard <type>           Launch guided wizard (scan, wifi)
    config <subcommand>     Configuration management
    help                    Show this help

Options:
    -v, --verbose           Verbose output
    -q, --quiet             Quiet mode (minimal output)
    --dry-run               Preview commands without executing
    --json                  JSON output format
    --no-color              Disable colored output
    --debug                 Debug mode
    --version               Show version

Examples:
    voidwave                           # Interactive menu
    voidwave scan 192.168.1.0/24       # Quick scan
    voidwave wifi monitor wlan0        # Enable monitor mode
    voidwave wizard scan               # Guided scan wizard
    voidwave --dry-run scan 10.0.0.1   # Preview scan command

Documentation: See docs/ directory
EOF
}

show_version() {
    echo "voidwave v${VERSION} (${CODENAME})"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                export VERBOSE=1
                shift
                ;;
            -q|--quiet)
                export QUIET=1
                shift
                ;;
            --dry-run)
                export DRY_RUN=1
                shift
                ;;
            --json)
                export JSON_OUTPUT=1
                shift
                ;;
            --no-color)
                export NO_COLOR=1
                shift
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            --version|-V)
                show_version
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            menu|"")
                main_menu
                exit 0
                ;;
            scan)
                shift
                run_nmap_quick "$@"
                exit $?
                ;;
            wifi)
                shift
                wifi_cli "$@"
                exit $?
                ;;
            status)
                show_status
                exit 0
                ;;
            wizard)
                shift
                case "${1:-}" in
                    scan) scan_wizard ;;
                    wifi) wifi_wizard ;;
                    *) wizard_menu ;;
                esac
                exit 0
                ;;
            config)
                shift
                config_cli "$@"
                exit $?
                ;;
            help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown command: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default: interactive menu
    main_menu
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Initialize
    init_directories
    detect_system
    
    # First-run checks
    check_legal
    check_authorization
    
    # Parse arguments and dispatch
    parse_args "$@"
}

main "$@"
```

### Line Count
**~150 lines** vs current 292KB monolith

---

# 2. WIRELESS & MONITOR MODE

## 2.1 is_wireless_interface()

### What It Does
Checks if a given network interface is a wireless adapter (not ethernet, not loopback).

### Why It Matters
Prevents users from trying to run aircrack-ng on `eth0` or `lo` and wondering why it fails.

### Implementation

```bash
is_wireless_interface() {
    local iface="$1"
    
    # Check if interface exists
    [[ -z "$iface" ]] && return 1
    [[ ! -d "/sys/class/net/$iface" ]] && return 1
    
    # Method 1: Check for wireless directory
    [[ -d "/sys/class/net/$iface/wireless" ]] && return 0
    
    # Method 2: Use iw
    if command -v iw &>/dev/null; then
        iw dev "$iface" info &>/dev/null && return 0
    fi
    
    # Method 3: Check phy directory
    [[ -d "/sys/class/net/$iface/phy80211" ]] && return 0
    
    return 1
}
```

---

## 2.2 get_wireless_interfaces()

### What It Does
Returns a list of all wireless interfaces on the system.

### Implementation

```bash
get_wireless_interfaces() {
    local interfaces=()
    local iface
    
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        [[ "$iface" == "lo" ]] && continue
        
        if is_wireless_interface "$iface"; then
            interfaces+=("$iface")
        fi
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        return 1
    fi
    
    echo "${interfaces[@]}"
}
```

---

## 2.3 check_monitor_mode()

### What It Does
Checks if a wireless interface is currently in monitor mode, with clear visual feedback.

### Why It Matters
You requested "clear ENABLED/DISABLED verification" - this shows exactly what mode the interface is in.

### Implementation

```bash
check_monitor_mode() {
    local iface="$1"
    local mode
    
    # Validate interface
    if ! is_wireless_interface "$iface"; then
        print_error "$iface is not a wireless interface"
        return 2
    fi
    
    # Get current mode
    if command -v iw &>/dev/null; then
        mode=$(iw dev "$iface" info 2>/dev/null | grep -oP 'type \K\w+')
    fi
    
    # Fallback to iwconfig
    if [[ -z "$mode" ]] && command -v iwconfig &>/dev/null; then
        mode=$(iwconfig "$iface" 2>/dev/null | grep -oP 'Mode:\K\w+')
    fi
    
    case "${mode,,}" in
        monitor)
            echo -e "    ${C_GREEN}╔═══════════════════════════════════════╗${C_RESET}"
            echo -e "    ${C_GREEN}║${C_RESET}  ${C_BOLD}$iface${C_RESET} — ${C_GREEN}MONITOR MODE ENABLED${C_RESET}    ${C_GREEN}║${C_RESET}"
            echo -e "    ${C_GREEN}╚═══════════════════════════════════════╝${C_RESET}"
            return 0
            ;;
        managed|*)
            echo -e "    ${C_YELLOW}╔═══════════════════════════════════════╗${C_RESET}"
            echo -e "    ${C_YELLOW}║${C_RESET}  ${C_BOLD}$iface${C_RESET} — ${C_YELLOW}MANAGED MODE${C_RESET}              ${C_YELLOW}║${C_RESET}"
            echo -e "    ${C_YELLOW}╚═══════════════════════════════════════╝${C_RESET}"
            return 1
            ;;
    esac
}
```

---

## 2.4 enable_monitor_mode()

### What It Does
Enables monitor mode on a wireless interface with proper verification.

### Implementation

```bash
enable_monitor_mode() {
    local iface="$1"
    local new_iface
    
    # Validate
    if ! is_wireless_interface "$iface"; then
        print_error "$iface is not a wireless interface"
        echo -e "    ${C_INFO}Available wireless interfaces:${C_RESET}"
        for w in $(get_wireless_interfaces); do
            echo -e "      • $w"
        done
        return 1
    fi
    
    # Check if already in monitor mode
    if check_monitor_mode "$iface" &>/dev/null; then
        print_info "$iface is already in monitor mode"
        return 0
    fi
    
    print_info "Enabling monitor mode on $iface..."
    
    # Kill interfering processes
    print_info "Killing interfering processes..."
    airmon-ng check kill &>/dev/null
    
    # Enable monitor mode
    if airmon-ng start "$iface" &>/dev/null; then
        # Wait for interface to come up
        sleep 2
        
        # Check for new interface name (wlan0mon or wlan0)
        if [[ -d "/sys/class/net/${iface}mon" ]]; then
            new_iface="${iface}mon"
        else
            new_iface="$iface"
        fi
        
        # Verify
        if check_monitor_mode "$new_iface"; then
            MONITOR_IFACE="$new_iface"
            export MONITOR_IFACE
            log_audit "WIRELESS" "Monitor mode enabled on $new_iface"
            return 0
        fi
    fi
    
    print_error "Failed to enable monitor mode on $iface"
    return 1
}
```

---

## 2.5 disable_monitor_mode()

### What It Does
Disables monitor mode and returns interface to managed mode.

### Implementation

```bash
disable_monitor_mode() {
    local iface="$1"
    local base_iface
    
    # Handle both wlan0 and wlan0mon naming
    base_iface="${iface%mon}"
    
    print_info "Disabling monitor mode on $iface..."
    
    if airmon-ng stop "$iface" &>/dev/null; then
        sleep 2
        
        # Verify
        if ! check_monitor_mode "$base_iface" &>/dev/null; then
            print_success "Monitor mode disabled, $base_iface is in managed mode"
            
            # Restart network manager
            print_info "Restarting NetworkManager..."
            systemctl restart NetworkManager 2>/dev/null || \
            service network-manager restart 2>/dev/null || \
            service networking restart 2>/dev/null
            
            unset MONITOR_IFACE
            log_audit "WIRELESS" "Monitor mode disabled on $base_iface"
            return 0
        fi
    fi
    
    print_error "Failed to disable monitor mode"
    return 1
}
```

---

## 2.6 validate_wireless_interface()

### What It Does
Master validation function that checks:
1. Interface exists
2. Interface is wireless
3. Optionally checks/enables monitor mode

### Why It Matters
Call this BEFORE any WiFi operation to prevent cryptic errors.

### Implementation

```bash
validate_wireless_interface() {
    local iface="$1"
    local require_monitor="${2:-false}"
    
    # Check interface exists
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        print_error "Interface '$iface' does not exist"
        
        local available
        available=$(get_wireless_interfaces)
        if [[ -n "$available" ]]; then
            echo -e "    ${C_INFO}Available wireless interfaces:${C_RESET}"
            for w in $available; do
                echo -e "      • $w"
            done
        else
            print_warning "No wireless interfaces found"
            print_info "Is your WiFi adapter connected and recognized?"
        fi
        return 1
    fi
    
    # Check interface is wireless
    if ! is_wireless_interface "$iface"; then
        print_error "'$iface' is not a wireless interface"
        print_info "You may have selected an ethernet or virtual interface"
        
        local available
        available=$(get_wireless_interfaces)
        if [[ -n "$available" ]]; then
            echo -e "    ${C_INFO}Available wireless interfaces:${C_RESET}"
            for w in $available; do
                echo -e "      • $w"
            done
        fi
        return 1
    fi
    
    # Check monitor mode if required
    if [[ "$require_monitor" == "true" ]]; then
        if ! check_monitor_mode "$iface" &>/dev/null; then
            print_warning "$iface is not in monitor mode"
            
            if confirm "Enable monitor mode now?" "y"; then
                enable_monitor_mode "$iface" || return 1
            else
                print_info "Operation requires monitor mode. Cancelled."
                return 1
            fi
        fi
    fi
    
    return 0
}
```

### Integration Example

```bash
# BEFORE (old code that fails silently):
airodump-ng "$interface"

# AFTER (validates first):
run_airodump() {
    local iface="$1"
    
    # This handles ALL validation and user prompts
    validate_wireless_interface "$iface" true || return 1
    
    # Now safe to run
    airodump-ng "${MONITOR_IFACE:-$iface}"
}
```

---

# 3. INSTALLER IMPROVEMENTS

## 3.1 verify_tool_installed()

### What It Does
Verifies a tool is actually installed by checking if the binary exists, NOT just the exit code of the install command.

### Why It Matters
Many tools report success even when installation fails. This actually checks if the binary is usable.

### Implementation

```bash
verify_tool_installed() {
    local tool="$1"
    local binary="${2:-$tool}"  # Binary name might differ from package name
    
    # Method 1: Check command exists
    if command -v "$binary" &>/dev/null; then
        return 0
    fi
    
    # Method 2: Check common binary locations
    local paths=(
        "/usr/bin/$binary"
        "/usr/local/bin/$binary"
        "/usr/sbin/$binary"
        "/opt/$binary/bin/$binary"
        "$HOME/.local/bin/$binary"
        "/snap/bin/$binary"
    )
    
    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            return 0
        fi
    done
    
    # Method 3: For Python tools, check pip
    if pip3 show "$tool" &>/dev/null; then
        return 0
    fi
    
    # Method 4: For Ruby tools, check gem
    if gem list -i "^${tool}$" &>/dev/null; then
        return 0
    fi
    
    return 1
}
```

---

## 3.2 create_manual_fix_guide()

### What It Does
When tools fail to install, creates a markdown file with manual installation instructions.

### Implementation

```bash
create_manual_fix_guide() {
    local failed_tools=("$@")
    local guide_file="$VOIDWAVE_HOME/MANUAL_INSTALL.md"
    
    cat > "$guide_file" << 'HEADER'
# VOIDWAVE — Manual Installation Guide

Some tools failed automatic installation. Follow these instructions to install manually.

---

HEADER

    for tool in "${failed_tools[@]}"; do
        cat >> "$guide_file" << EOF
## $tool

EOF
        
        case "$tool" in
            wpscan)
                cat >> "$guide_file" << 'EOF'
```bash
# Install Ruby and dependencies
sudo apt install ruby ruby-dev libcurl4-openssl-dev make zlib1g-dev -y

# Install wpscan via gem
sudo gem install wpscan

# Verify
wpscan --version
```
EOF
                ;;
            crackmapexec|cme)
                cat >> "$guide_file" << 'EOF'
```bash
# Install via pipx (recommended)
python3 -m pip install pipx
pipx install crackmapexec

# Or install from source
git clone https://github.com/byt3bl33d3r/CrackMapExec
cd CrackMapExec
pip3 install .

# Verify
crackmapexec --version
```
EOF
                ;;
            rustscan)
                cat >> "$guide_file" << 'EOF'
```bash
# Download latest release
wget https://github.com/RustScan/RustScan/releases/latest/download/rustscan_2.1.1_amd64.deb

# Install
sudo dpkg -i rustscan_*.deb

# Or via cargo
cargo install rustscan

# Verify
rustscan --version
```
EOF
                ;;
            metasploit|metasploit-framework)
                cat >> "$guide_file" << 'EOF'
```bash
# Official installer
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod +x msfinstall
./msfinstall

# Verify
msfconsole --version
```
EOF
                ;;
            *)
                cat >> "$guide_file" << EOF
\`\`\`bash
# Try these methods:

# Method 1: apt
sudo apt install $tool -y

# Method 2: pip
pip3 install $tool --break-system-packages

# Method 3: Search for package
apt search $tool
\`\`\`
EOF
                ;;
        esac
        
        echo "" >> "$guide_file"
    done
    
    cat >> "$guide_file" << EOF
---

## General Troubleshooting

1. **Update package lists first:**
   \`\`\`bash
   sudo apt update
   \`\`\`

2. **Check if tool is available in repos:**
   \`\`\`bash
   apt-cache search <tool-name>
   \`\`\`

3. **Try Kali repos if on Debian/Ubuntu:**
   \`\`\`bash
   echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" | sudo tee /etc/apt/sources.list.d/kali.list
   sudo apt update
   \`\`\`

4. **Install from GitHub releases:**
   Many tools publish pre-built binaries on their GitHub releases page.

---

*Generated by VOIDWAVE Installer*
EOF

    print_info "Manual installation guide saved to: $guide_file"
    
    if confirm "Open guide now?" "y"; then
        if command -v xdg-open &>/dev/null; then
            xdg-open "$guide_file" 2>/dev/null &
        elif command -v less &>/dev/null; then
            less "$guide_file"
        else
            cat "$guide_file"
        fi
    fi
}
```

---

## 3.3 show_install_summary()

### What It Does
Shows a clear summary after installation with success/failure counts and next steps.

### Implementation

```bash
show_install_summary() {
    local -n success_ref=$1
    local -n failed_ref=$2
    local -n skipped_ref=$3
    
    local success_count=${#success_ref[@]}
    local fail_count=${#failed_ref[@]}
    local skip_count=${#skipped_ref[@]}
    local total=$((success_count + fail_count + skip_count))
    
    echo
    draw_header "INSTALLATION SUMMARY"
    echo
    echo -e "    ${C_GREEN}✓ Successful:${C_RESET}  $success_count"
    echo -e "    ${C_RED}✗ Failed:${C_RESET}      $fail_count"
    echo -e "    ${C_YELLOW}○ Skipped:${C_RESET}     $skip_count"
    echo -e "    ${C_GRAY}─────────────────${C_RESET}"
    echo -e "    ${C_BOLD}Total:${C_RESET}         $total"
    echo
    
    if [[ $fail_count -gt 0 ]]; then
        echo -e "    ${C_RED}Failed tools:${C_RESET}"
        for tool in "${failed_ref[@]}"; do
            echo -e "      • $tool"
        done
        echo
        
        if confirm "Generate manual installation guide?" "y"; then
            create_manual_fix_guide "${failed_ref[@]}"
        fi
    fi
    
    if [[ $success_count -gt 0 ]]; then
        echo
        print_success "Installation complete!"
        echo
        echo -e "    ${C_INFO}Next steps:${C_RESET}"
        echo -e "      1. Run ${C_BOLD}voidwave status${C_RESET} to see installed tools"
        echo -e "      2. Run ${C_BOLD}voidwave${C_RESET} to launch the menu"
        echo -e "      3. Run ${C_BOLD}voidwave wizard scan${C_RESET} for guided scanning"
    fi
}
```

---

## 3.4 Uninstall Menu Option

### What It Does
Adds `[U] Uninstall` option to the installer menu to remove tools.

### Implementation

```bash
uninstall_tool() {
    local tool="$1"
    
    print_info "Uninstalling $tool..."
    
    # Try apt first
    if dpkg -l | grep -q "^ii  $tool"; then
        sudo apt remove -y "$tool" && return 0
    fi
    
    # Try pip
    if pip3 show "$tool" &>/dev/null; then
        pip3 uninstall -y "$tool" && return 0
    fi
    
    # Try gem
    if gem list -i "^${tool}$" &>/dev/null; then
        sudo gem uninstall "$tool" -x && return 0
    fi
    
    # Try snap
    if snap list "$tool" &>/dev/null 2>&1; then
        sudo snap remove "$tool" && return 0
    fi
    
    print_warning "$tool not found or couldn't be uninstalled"
    return 1
}

uninstall_menu() {
    local installed_tools=()
    
    # Get list of installed tools
    for tool in "${ALL_TOOLS[@]}"; do
        if verify_tool_installed "$tool"; then
            installed_tools+=("$tool")
        fi
    done
    
    if [[ ${#installed_tools[@]} -eq 0 ]]; then
        print_warning "No VOIDWAVE tools are installed"
        return
    fi
    
    echo
    draw_header "UNINSTALL TOOLS"
    echo
    
    local i=1
    for tool in "${installed_tools[@]}"; do
        echo -e "    ${C_CYAN}[$i]${C_RESET} $tool"
        ((i++))
    done
    echo
    echo -e "    ${C_RED}[A] Uninstall ALL${C_RESET}"
    echo -e "    ${C_GRAY}[B] Back${C_RESET}"
    echo
    
    local choice
    echo -ne "    ${C_PROMPT}Select tool to uninstall: ${C_RESET}"
    read -r choice
    
    case "$choice" in
        [aA])
            if confirm_dangerous "Uninstall ALL ${#installed_tools[@]} tools?"; then
                for tool in "${installed_tools[@]}"; do
                    uninstall_tool "$tool"
                done
            fi
            ;;
        [bB]) return ;;
        *[0-9]*)
            if [[ "$choice" -ge 1 && "$choice" -le "${#installed_tools[@]}" ]]; then
                local tool="${installed_tools[$((choice-1))]}"
                if confirm "Uninstall $tool?" "n"; then
                    uninstall_tool "$tool"
                fi
            fi
            ;;
    esac
}
```

---

## 3.5 Missing Tools Addition

### What It Does
Adds tools that were missing from the installer arrays.

### Implementation

```bash
# Add to appropriate arrays in voidwave-install:

# Wireless tools - ADD:
WIRELESS_TOOLS+=(
    "hcxdumptool"    # WPA handshake capture
    "hcxtools"       # Handshake conversion
)

# Stress tools - ADD/CREATE:
STRESS_TOOLS=(
    "hping3"         # Packet crafting
    "iperf3"         # Bandwidth testing
    "stress-ng"      # System stress
)

# Post-exploitation - ADD:
POST_TOOLS+=(
    "empire"         # PowerShell post-exploitation
)

# Package name mappings (some tools have different package names):
declare -A PACKAGE_MAP=(
    ["hcxdumptool"]="hcxdumptool"
    ["hcxtools"]="hcxtools"
    ["iperf3"]="iperf3"
    ["empire"]="powershell-empire"
)
```

---

## 3.6 Graceful Failure Handling

### What It Does
Prevents the installer from crashing when one tool fails - it continues with the next tool.

### Implementation

```bash
install_tool() {
    local tool="$1"
    local category="$2"
    
    # Check if already installed
    if verify_tool_installed "$tool"; then
        echo -e "    ${C_GREEN}✓${C_RESET} $tool (already installed)"
        SUCCESS_TOOLS+=("$tool")
        return 0
    fi
    
    echo -ne "    ${C_CYAN}○${C_RESET} Installing $tool..."
    
    # Try installation methods (with error suppression)
    local installed=false
    
    # Method 1: apt
    if ! $installed && [[ -n "$PKG_INSTALL" ]]; then
        if $PKG_INSTALL "$tool" &>/dev/null; then
            installed=true
        fi
    fi
    
    # Method 2: pip
    if ! $installed; then
        if pip3 install "$tool" --break-system-packages &>/dev/null; then
            installed=true
        fi
    fi
    
    # Method 3: pipx
    if ! $installed && command -v pipx &>/dev/null; then
        if pipx install "$tool" &>/dev/null; then
            installed=true
        fi
    fi
    
    # Method 4: gem (for Ruby tools)
    if ! $installed && [[ "$tool" =~ ^(wpscan|ruby-).*$ ]]; then
        if sudo gem install "$tool" &>/dev/null; then
            installed=true
        fi
    fi
    
    # Method 5: GitHub releases (for specific tools)
    if ! $installed; then
        install_from_github "$tool" &>/dev/null && installed=true
    fi
    
    # Clear the "Installing..." line and show result
    echo -ne "\r"
    
    # Verify installation actually worked
    if verify_tool_installed "$tool"; then
        echo -e "    ${C_GREEN}✓${C_RESET} $tool"
        SUCCESS_TOOLS+=("$tool")
        return 0
    else
        echo -e "    ${C_RED}✗${C_RESET} $tool (all methods failed)"
        FAILED_TOOLS+=("$tool")
        return 1  # Return failure but DON'T exit
    fi
}

# Main installation loop - continues even on failure
install_category() {
    local category="$1"
    local -n tools_ref=$2
    
    echo
    echo -e "    ${C_BOLD}━━━ Installing $category tools ━━━${C_RESET}"
    
    for tool in "${tools_ref[@]}"; do
        install_tool "$tool" "$category" || true  # Continue even on failure
    done
}
```

---

# 4. STRESS TESTING FIXES

## 4.1 run_hping_attack() — Fixed

### What It Does
Fixed hping3 stress testing with proper parameters, rate limiting, and live output.

### Why It Was Broken
The original function didn't show output, had wrong parameters, and didn't have rate limiting.

### Implementation

```bash
run_hping_attack() {
    local target="$1"
    local attack_type="${2:-syn}"  # syn, udp, icmp
    local port="${3:-80}"
    local count="${4:-1000}"
    local rate="${5:-100}"  # packets per second
    
    require_root || return 1
    check_tool hping3 || return 1
    validate_target "$target" || return 1
    
    # Warn about impact
    print_warning "This will send $count packets to $target"
    print_warning "This may trigger IDS/IPS alerts and could impact network performance"
    
    if ! confirm_dangerous "Proceed with stress test on $target?"; then
        return 1
    fi
    
    local flags=""
    case "$attack_type" in
        syn)
            flags="-S -p $port"
            print_info "Attack type: SYN flood on port $port"
            ;;
        udp)
            flags="--udp -p $port"
            print_info "Attack type: UDP flood on port $port"
            ;;
        icmp)
            flags="-1"  # ICMP mode
            print_info "Attack type: ICMP flood"
            ;;
        *)
            print_error "Unknown attack type: $attack_type"
            return 1
            ;;
    esac
    
    log_command_preview "hping3 $flags -c $count -i u$((1000000/rate)) $target"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute hping3 stress test"
        return 0
    fi
    
    print_info "Starting stress test... (Ctrl+C to stop)"
    echo
    
    # Run with live output
    # -i u10000 = 10000 microseconds between packets = 100 pps
    local interval=$((1000000 / rate))
    
    hping3 $flags \
        -c "$count" \
        -i "u${interval}" \
        --faster \
        "$target" 2>&1 | while read -r line; do
            echo "    $line"
        done
    
    local exit_code=${PIPESTATUS[0]}
    
    echo
    if [[ $exit_code -eq 0 ]]; then
        print_success "Stress test complete: $count packets sent"
        log_audit "STRESS" "hping3 $attack_type $target" "SUCCESS"
    else
        print_warning "Stress test ended with code $exit_code"
    fi
    
    return $exit_code
}
```

---

## 4.2 run_netem() — Fixed

### What It Does
Network emulation/impairment testing with proper verification.

### Why It Was Broken
Original didn't verify interface existed, didn't clean up, and had no connection verification.

### Implementation

```bash
run_netem() {
    local iface="$1"
    local impairment_type="$2"  # delay, loss, duplicate, corrupt
    local value="$3"
    local duration="${4:-30}"
    
    require_root || return 1
    check_tool tc || return 1
    
    # Verify interface exists
    if ! check_interface "$iface"; then
        print_error "Interface $iface does not exist"
        return 1
    fi
    
    # Get baseline connectivity
    print_info "Testing baseline connectivity..."
    local test_host="8.8.8.8"
    local baseline_ping
    baseline_ping=$(ping -c 3 -W 2 "$test_host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -z "$baseline_ping" ]]; then
        print_warning "No baseline connectivity - test may be inaccurate"
    else
        print_info "Baseline latency: ${baseline_ping}ms"
    fi
    
    # Build tc command
    local tc_params=""
    case "$impairment_type" in
        delay)
            tc_params="delay ${value}ms"
            print_info "Adding ${value}ms delay to $iface"
            ;;
        loss)
            tc_params="loss ${value}%"
            print_info "Adding ${value}% packet loss to $iface"
            ;;
        duplicate)
            tc_params="duplicate ${value}%"
            print_info "Adding ${value}% packet duplication to $iface"
            ;;
        corrupt)
            tc_params="corrupt ${value}%"
            print_info "Adding ${value}% packet corruption to $iface"
            ;;
        *)
            print_error "Unknown impairment type: $impairment_type"
            return 1
            ;;
    esac
    
    log_command_preview "tc qdisc add dev $iface root netem $tc_params"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would apply network impairment"
        return 0
    fi
    
    # Apply impairment
    print_info "Applying impairment for ${duration} seconds..."
    
    # Remove existing qdisc first
    tc qdisc del dev "$iface" root 2>/dev/null
    
    # Add new qdisc
    if ! tc qdisc add dev "$iface" root netem $tc_params; then
        print_error "Failed to apply impairment"
        return 1
    fi
    
    print_success "Impairment applied"
    
    # Test impaired connectivity
    print_info "Testing impaired connectivity..."
    local impaired_ping
    impaired_ping=$(ping -c 3 -W 5 "$test_host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -n "$impaired_ping" ]]; then
        print_info "Impaired latency: ${impaired_ping}ms"
    fi
    
    # Wait
    print_info "Impairment active. Waiting ${duration} seconds..."
    sleep "$duration"
    
    # Remove impairment
    print_info "Removing impairment..."
    tc qdisc del dev "$iface" root 2>/dev/null
    
    # Verify restoration
    print_info "Verifying connectivity restored..."
    local restored_ping
    restored_ping=$(ping -c 3 -W 2 "$test_host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -n "$restored_ping" ]]; then
        print_success "Connectivity restored: ${restored_ping}ms"
    else
        print_warning "Connectivity may still be impaired"
    fi
    
    log_audit "STRESS" "netem $impairment_type $value on $iface" "COMPLETE"
    return 0
}
```

---

## 4.3 stress_prescan()

### What It Does
Scans target before stress testing to verify it's alive and gather info.

### Implementation

```bash
stress_prescan() {
    local target="$1"
    
    print_info "Pre-scan: Checking target $target..."
    echo
    
    # Ping check
    echo -ne "    Ping test... "
    if ping -c 1 -W 2 "$target" &>/dev/null; then
        echo -e "${C_GREEN}ALIVE${C_RESET}"
    else
        echo -e "${C_YELLOW}NO RESPONSE${C_RESET}"
        print_warning "Target may be blocking ICMP"
    fi
    
    # Port check (common ports)
    local open_ports=()
    echo -ne "    Port scan... "
    
    for port in 22 80 443 8080; do
        if timeout 2 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null; then
            open_ports+=("$port")
        fi
    done
    
    if [[ ${#open_ports[@]} -gt 0 ]]; then
        echo -e "${C_GREEN}Open: ${open_ports[*]}${C_RESET}"
    else
        echo -e "${C_YELLOW}No common ports open${C_RESET}"
    fi
    
    # Latency measurement
    echo -ne "    Latency... "
    local latency
    latency=$(ping -c 3 -W 2 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    
    if [[ -n "$latency" ]]; then
        echo -e "${C_GREEN}${latency}ms${C_RESET}"
    else
        echo -e "${C_YELLOW}Could not measure${C_RESET}"
    fi
    
    echo
    
    if confirm "Proceed with stress test?" "n"; then
        return 0
    else
        return 1
    fi
}
```

---

# 5. SMART SUDO & PRIVILEGES

## 5.1 is_root()

```bash
is_root() {
    [[ $EUID -eq 0 ]]
}
```

## 5.2 require_root()

### What It Does
Checks if running as root and offers to elevate if not.

```bash
require_root() {
    if is_root; then
        return 0
    fi
    
    print_error "This operation requires root privileges"
    
    if is_non_interactive; then
        return 1
    fi
    
    if confirm "Elevate to root?" "y"; then
        return 2  # Signal to re-run with sudo
    fi
    
    return 1
}
```

## 5.3 run_with_sudo()

### What It Does
Runs a command with sudo, prompting for password if needed.

```bash
run_with_sudo() {
    local cmd="$1"
    shift
    
    if is_root; then
        "$cmd" "$@"
    else
        sudo "$cmd" "$@"
    fi
}
```

## 5.4 elevate_if_needed()

### What It Does
Re-executes the entire script with sudo if not already root.

```bash
elevate_if_needed() {
    if ! is_root; then
        print_warning "Some features require root privileges"
        
        if confirm "Restart with sudo?" "y"; then
            exec sudo "$0" "$@"
        fi
    fi
}
```

---

# 6. TOOL MANAGEMENT

## 6.1 check_tool()

```bash
check_tool() {
    local tool="$1"
    
    if ! command -v "$tool" &>/dev/null; then
        print_error "$tool is not installed"
        print_info "Install with: sudo voidwave-install"
        return 1
    fi
    
    return 0
}
```

## 6.2 auto_install_tool()

### What It Does
Automatically installs a missing tool when detected.

```bash
auto_install_tool() {
    local tool="$1"
    
    print_warning "$tool is not installed"
    
    if confirm "Install $tool now?" "y"; then
        print_info "Installing $tool..."
        
        if $PKG_INSTALL "$tool" 2>/dev/null; then
            print_success "$tool installed"
            return 0
        else
            print_error "Failed to install $tool"
            return 1
        fi
    fi
    
    return 1
}

# Usage in tool functions:
run_nmap() {
    check_tool nmap || auto_install_tool nmap || return 1
    # ... rest of function
}
```

## 6.3 check_tool_version()

```bash
check_tool_version() {
    local tool="$1"
    local min_version="$2"
    
    local current_version
    current_version=$(get_tool_version "$tool")
    
    if [[ "$current_version" == "not installed" ]]; then
        return 1
    fi
    
    # Compare versions
    if [[ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -1)" == "$min_version" ]]; then
        return 0
    else
        print_warning "$tool version $current_version is below required $min_version"
        return 1
    fi
}
```

## 6.4 Tool Dependency Management

```bash
# Define tool dependencies
declare -A TOOL_DEPS=(
    ["aircrack-ng"]="wireless-tools iw"
    ["wifite"]="aircrack-ng reaver bully pixiewps"
    ["metasploit"]="postgresql ruby"
    ["hashcat"]="opencl-headers"
)

check_dependencies() {
    local tool="$1"
    local deps="${TOOL_DEPS[$tool]:-}"
    
    if [[ -z "$deps" ]]; then
        return 0
    fi
    
    local missing=()
    for dep in $deps; do
        if ! check_tool "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "$tool requires: ${missing[*]}"
        
        if confirm "Install dependencies?" "y"; then
            for dep in "${missing[@]}"; do
                auto_install_tool "$dep"
            done
        else
            return 1
        fi
    fi
    
    return 0
}
```

---

# 7. WIZARDS

## 7.1 first_run_wizard()

### What It Does
Guides new users through initial setup on first run.

```bash
first_run_wizard() {
    # Skip in non-interactive mode
    if is_non_interactive; then
        check_legal
        config_set FIRST_RUN_COMPLETE true
        return 0
    fi
    
    clear_screen
    show_banner "$VERSION"
    
    echo -e "    ${C_FIRE}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_FIRE}║${C_RESET}  ${C_SKULL}☠${C_RESET}  Welcome to VOIDWAVE                                   ${C_FIRE}║${C_RESET}"
    echo -e "    ${C_FIRE}║${C_RESET}                                                               ${C_FIRE}║${C_RESET}"
    echo -e "    ${C_FIRE}║${C_RESET}  ${C_GRAY}\"Some tools scan. Some tools attack. I do both.\"${C_RESET}          ${C_FIRE}║${C_RESET}"
    echo -e "    ${C_FIRE}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo
    
    sleep 1
    
    print_info "This appears to be your first time running VOIDWAVE."
    print_info "Let me help you get set up."
    echo
    
    # Legal acceptance
    check_legal || return 1
    
    echo
    print_info "━━━ Configuration ━━━"
    echo
    
    # Verbose mode preference
    if confirm "Enable verbose output by default?" "n"; then
        config_set VERBOSE true
        print_info "Verbose mode enabled"
    fi
    
    # Auto-update check
    if confirm "Check for updates on startup?" "y"; then
        config_set AUTO_UPDATE_CHECK true
    fi
    
    # Install essential tools
    echo
    if confirm "Install essential tools now? (recommended)" "y"; then
        print_info "Launching installer..."
        voidwave-install essentials
    fi
    
    # Mark first run complete
    config_set FIRST_RUN_COMPLETE true
    
    echo
    print_success "Setup complete!"
    echo
    echo -e "    ${C_INFO}Quick start:${C_RESET}"
    echo -e "      • ${C_BOLD}voidwave${C_RESET}              - Launch interactive menu"
    echo -e "      • ${C_BOLD}voidwave wizard scan${C_RESET}  - Guided scanning"
    echo -e "      • ${C_BOLD}voidwave status${C_RESET}       - Check installed tools"
    echo
    
    press_enter
}
```

## 7.2 scan_wizard()

### What It Does
Guides user through a network scan step by step.

```bash
scan_wizard() {
    clear_screen
    show_banner "$VERSION"
    draw_header "SCAN WIZARD"
    
    echo
    print_info "This wizard will guide you through scanning a target."
    echo
    
    # Step 1: Get target
    local target
    target=$(get_input "Enter target (IP, CIDR, or hostname)")
    
    if [[ -z "$target" ]]; then
        print_error "No target specified"
        return 1
    fi
    
    # Validate target
    if ! validate_target "$target"; then
        return 1
    fi
    
    echo
    
    # Step 2: Select scan type
    print_info "Select scan type:"
    echo
    echo -e "    ${C_CYAN}[1]${C_RESET} Quick     - Fast scan of common ports (~30 sec)"
    echo -e "    ${C_CYAN}[2]${C_RESET} Standard  - Full port scan (~5 min)"
    echo -e "    ${C_CYAN}[3]${C_RESET} Deep      - Full scan + scripts + vuln check (~15 min)"
    echo -e "    ${C_CYAN}[4]${C_RESET} Stealth   - Slow and quiet to avoid detection (~10 min)"
    echo
    
    local scan_type
    echo -ne "    ${C_PROMPT}Select [1-4]: ${C_RESET}"
    read -r scan_type
    
    # Step 3: Confirm
    echo
    print_info "Summary:"
    echo -e "    Target:    $target"
    case "$scan_type" in
        1) echo -e "    Scan type: Quick" ;;
        2) echo -e "    Scan type: Standard" ;;
        3) echo -e "    Scan type: Deep" ;;
        4) echo -e "    Scan type: Stealth" ;;
    esac
    echo
    
    if ! confirm "Proceed with scan?" "y"; then
        print_info "Scan cancelled"
        return 0
    fi
    
    # Step 4: Execute
    echo
    case "$scan_type" in
        1) run_nmap_quick "$target" ;;
        2) run_nmap_standard "$target" ;;
        3) run_nmap_deep "$target" ;;
        4) run_nmap_stealth "$target" ;;
        *) run_nmap_quick "$target" ;;
    esac
    
    echo
    press_enter
}
```

## 7.3 wifi_wizard()

### What It Does
Guides user through WiFi attacks step by step.

```bash
wifi_wizard() {
    clear_screen
    show_banner "$VERSION"
    draw_header "WIFI WIZARD"
    
    # Check for wireless interfaces
    local interfaces
    interfaces=$(get_wireless_interfaces)
    
    if [[ -z "$interfaces" ]]; then
        print_error "No wireless interfaces found"
        print_info "Make sure your WiFi adapter is connected"
        return 1
    fi
    
    echo
    print_info "This wizard will guide you through WiFi reconnaissance."
    echo
    
    # Step 1: Select interface
    print_info "Available wireless interfaces:"
    local iface_array=($interfaces)
    local i=1
    for iface in "${iface_array[@]}"; do
        local mac=$(get_interface_mac "$iface")
        echo -e "    ${C_CYAN}[$i]${C_RESET} $iface ($mac)"
        ((i++))
    done
    echo
    
    local choice
    echo -ne "    ${C_PROMPT}Select interface: ${C_RESET}"
    read -r choice
    
    local selected_iface="${iface_array[$((choice-1))]}"
    
    if [[ -z "$selected_iface" ]]; then
        print_error "Invalid selection"
        return 1
    fi
    
    echo
    
    # Step 2: Enable monitor mode
    print_info "Enabling monitor mode on $selected_iface..."
    
    if ! enable_monitor_mode "$selected_iface"; then
        print_error "Failed to enable monitor mode"
        return 1
    fi
    
    local monitor_iface="${MONITOR_IFACE:-$selected_iface}"
    
    # Step 3: Scan for networks
    echo
    print_info "Starting network scan (15 seconds)..."
    print_info "Press Ctrl+C to stop early"
    echo
    
    timeout 15 airodump-ng "$monitor_iface" 2>/dev/null
    
    echo
    
    # Step 4: Ask what to do next
    print_info "What would you like to do?"
    echo
    echo -e "    ${C_CYAN}[1]${C_RESET} Continue scanning"
    echo -e "    ${C_CYAN}[2]${C_RESET} Target specific network"
    echo -e "    ${C_CYAN}[3]${C_RESET} Disable monitor mode and exit"
    echo
    
    echo -ne "    ${C_PROMPT}Select: ${C_RESET}"
    read -r next_choice
    
    case "$next_choice" in
        1)
            airodump-ng "$monitor_iface"
            ;;
        2)
            local bssid
            bssid=$(get_input "Enter target BSSID (MAC address)")
            local channel
            channel=$(get_input "Enter channel")
            
            airodump-ng -c "$channel" --bssid "$bssid" -w capture "$monitor_iface"
            ;;
        3)
            disable_monitor_mode "$monitor_iface"
            ;;
    esac
}
```

---

# 8. LOGGING SYSTEM

## 8.1 Log Levels

```bash
# Log level constants
declare -r LOG_DEBUG=0
declare -r LOG_INFO=1
declare -r LOG_SUCCESS=2
declare -r LOG_WARNING=3
declare -r LOG_ERROR=4
declare -r LOG_FATAL=5

# Current log level (configurable)
LOG_LEVEL="${LOG_LEVEL:-$LOG_INFO}"
```

## 8.2 log_debug()

```bash
log_debug() {
    [[ $LOG_LEVEL -le $LOG_DEBUG ]] || return 0
    _log "DEBUG" "$C_DEBUG" "$@"
}
```

## 8.3 log_info()

```bash
log_info() {
    [[ $LOG_LEVEL -le $LOG_INFO ]] || return 0
    _log "INFO" "$C_INFO" "$@"
    print_info "$@"
}
```

## 8.4 log_success()

```bash
log_success() {
    _log "SUCCESS" "$C_SUCCESS" "$@"
    print_success "$@"
}
```

## 8.5 log_warning()

```bash
log_warning() {
    [[ $LOG_LEVEL -le $LOG_WARNING ]] || return 0
    _log "WARNING" "$C_WARNING" "$@"
    print_warning "$@"
}
```

## 8.6 log_error()

```bash
log_error() {
    _log "ERROR" "$C_ERROR" "$@"
    print_error "$@"
}
```

## 8.7 log_fatal()

```bash
log_fatal() {
    _log "FATAL" "$C_ERROR" "$@"
    print_error "FATAL: $*"
    exit 1
}
```

## 8.8 log_audit()

### What It Does
Creates compliance audit trail with structured logging.

```bash
log_audit() {
    local category="$1"
    local action="$2"
    local result="${3:-INFO}"
    local details="${4:-}"
    
    local audit_file="$VOIDWAVE_LOG_DIR/audit.log"
    local timestamp=$(date -Iseconds)
    local user=$(whoami)
    local host=$(hostname)
    
    # Structured audit entry
    local entry="$timestamp | $user@$host | $category | $action | $result"
    [[ -n "$details" ]] && entry="$entry | $details"
    
    echo "$entry" >> "$audit_file"
    
    # Also log to daily log
    _log "AUDIT" "$C_GRAY" "[$category] $action - $result"
}
```

## 8.9 File Logging

```bash
# Internal log function
_log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$VOIDWAVE_LOG_DIR/voidwave_$(date '+%Y%m%d').log"
    
    # Write to file (no colors)
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# Log command being executed
log_command_preview() {
    local cmd="$*"
    
    if [[ "${VERBOSE:-0}" == "1" || "${DRY_RUN:-0}" == "1" ]]; then
        echo -e "    ${C_GRAY}$ $cmd${C_RESET}"
    fi
    
    _log "CMD" "" "$cmd"
}
```

---

# 9. PROGRESS & FEEDBACK

## 9.1 show_spinner()

```bash
show_spinner() {
    local pid="$1"
    local message="${2:-Working...}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    tput civis  # Hide cursor
    
    while kill -0 "$pid" 2>/dev/null; do
        local c=${spinstr:i++%${#spinstr}:1}
        echo -ne "\r    ${C_CYAN}${c}${C_RESET} $message"
        sleep 0.1
    done
    
    echo -ne "\r    ${C_GREEN}✓${C_RESET} $message\n"
    tput cnorm  # Show cursor
}

# Usage:
# long_running_command &
# show_spinner $! "Processing..."
```

## 9.2 show_progress_bar()

```bash
show_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local label="${4:-Progress}"
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r    ${label}: ["
    printf "${C_GREEN}%${filled}s${C_RESET}" | tr ' ' '█'
    printf "${C_GRAY}%${empty}s${C_RESET}" | tr ' ' '░'
    printf "] %3d%%" "$percent"
    
    [[ $current -eq $total ]] && echo
}

# Usage:
# for i in {1..100}; do
#     show_progress_bar $i 100
#     sleep 0.05
# done
```

## 9.3 start_timer() / stop_timer()

```bash
declare _TIMER_START=0

start_timer() {
    _TIMER_START=$(date +%s.%N)
}

stop_timer() {
    local end=$(date +%s.%N)
    ELAPSED_TIME=$(echo "$end - $_TIMER_START" | bc)
}

get_elapsed_time() {
    local seconds=${ELAPSED_TIME%.*}
    local ms=${ELAPSED_TIME#*.}
    ms=${ms:0:3}
    
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}.${ms}s"
    elif [[ $seconds -lt 3600 ]]; then
        local min=$((seconds / 60))
        local sec=$((seconds % 60))
        echo "${min}m ${sec}s"
    else
        local hours=$((seconds / 3600))
        local min=$(((seconds % 3600) / 60))
        echo "${hours}h ${min}m"
    fi
}

# Usage:
# start_timer
# some_long_operation
# stop_timer
# print_success "Completed in $(get_elapsed_time)"
```

---

# 10. CONFIRMATION PROMPTS

## 10.1 confirm()

*(Already shown in lib/safety.sh - Section 1.4)*

## 10.2 confirm_dangerous()

*(Already shown in lib/safety.sh - Section 1.4)*

## 10.3 select_option()

```bash
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo -e "    ${C_PROMPT}${prompt}${C_RESET}"
    echo
    
    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${C_CYAN}[$i]${C_RESET} $opt"
        ((i++))
    done
    echo
    
    local choice
    echo -ne "    ${C_PROMPT}Select [1-${#options[@]}]: ${C_RESET}"
    read -r choice
    
    if [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
        echo "${options[$((choice-1))]}"
        return 0
    fi
    
    return 1
}

# Usage:
# scan_type=$(select_option "Choose scan type:" "Quick" "Full" "Stealth")
```

## 10.4 prompt_input()

```bash
prompt_input() {
    local prompt="$1"
    local validator="${2:-}"
    local default="${3:-}"
    local input
    
    while true; do
        input=$(get_input "$prompt" "$default")
        
        # If no validator, accept any input
        if [[ -z "$validator" ]]; then
            echo "$input"
            return 0
        fi
        
        # Run validator function
        if "$validator" "$input"; then
            echo "$input"
            return 0
        fi
        
        print_error "Invalid input, please try again"
    done
}

# Validators
validate_ip_input() {
    is_valid_ip "$1" || is_valid_cidr "$1"
}

validate_port_input() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]
}

# Usage:
# target=$(prompt_input "Enter target IP" "validate_ip_input")
# port=$(prompt_input "Enter port" "validate_port_input" "80")
```

---

# 11. TARGET VALIDATION & SAFETY

*(Most functions already shown in lib/safety.sh - Section 1.4)*

## 11.5 VW_UNSAFE_MODE

### What It Does
Environment variable that allows targeting public IPs without confirmation.

### Implementation

```bash
# Usage: VW_UNSAFE_MODE=true voidwave scan 8.8.8.8

# In validate_target():
if ! is_private_ip "$ip"; then
    if [[ "${VW_UNSAFE_MODE:-false}" == "true" ]]; then
        log_warning "Public IP targeting - VW_UNSAFE_MODE is enabled"
        log_audit "SAFETY" "Public IP $ip - unsafe mode" "ALLOWED"
        return 0
    fi
    # ... normal confirmation flow
fi
```

### Documentation
Add to help output:
```
Environment Variables:
    VW_UNSAFE_MODE=true     Allow targeting public IPs without confirmation
    VW_NON_INTERACTIVE=1    Skip all interactive prompts (for scripting/CI)
    DEBUG=1                 Enable debug output
```

---

# 12. WORDLIST MANAGEMENT

## 12.1 check_wordlists()

*(Shown in lib/utils.sh - Section 1.6)*

## 12.2 ensure_rockyou()

*(Shown in lib/utils.sh - Section 1.6)*

---

# 13. WHOIS IMPROVEMENTS

## 13.1 run_whois() — Fixed

### What It Does
Runs WHOIS lookup with private IP detection and better error handling.

### Implementation

```bash
run_whois() {
    local target="$1"
    
    check_tool whois || return 1
    
    # Remove CIDR notation
    target="${target%%/*}"
    
    # Check if private IP
    if is_private_ip "$target"; then
        print_warning "$target is a private IP address"
        print_info "WHOIS lookups only work for public IPs"
        print_info "Private ranges: 10.x.x.x, 172.16-31.x.x, 192.168.x.x"
        
        if ! confirm "Try WHOIS anyway? (will likely fail)" "n"; then
            return 1
        fi
    fi
    
    print_info "Running WHOIS lookup for $target..."
    
    local output_file
    output_file=$(create_output_file "whois_${target}")
    
    if whois "$target" 2>&1 | tee "$output_file"; then
        print_success "WHOIS complete"
        print_info "Output saved to: $output_file"
        log_audit "OSINT" "whois $target" "SUCCESS"
    else
        print_error "WHOIS lookup failed"
        log_audit "OSINT" "whois $target" "FAILED"
        return 1
    fi
}
```

---

# 14. CLI IMPROVEMENTS

## 14.1 --dry-run Flag

### What It Does
Shows what commands would run without executing them.

### Implementation

```bash
# Global flag
DRY_RUN="${DRY_RUN:-0}"

# In CLI parsing:
--dry-run)
    export DRY_RUN=1
    print_info "Dry-run mode: commands will be shown but not executed"
    shift
    ;;

# In each tool function:
run_nmap_quick() {
    # ... validation ...
    
    log_command_preview "nmap -T4 -F $target"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_info "[DRY-RUN] Would execute: nmap -T4 -F $target"
        return 0
    fi
    
    # Actually run the command
    nmap -T4 -F "$target"
}
```

## 14.2 --json Output

### What It Does
Outputs results in JSON format for scripting/integration.

### Implementation

```bash
# Global flag
JSON_OUTPUT="${JSON_OUTPUT:-0}"

# JSON output helper
json_output() {
    local -n data_ref=$1
    
    if [[ "${JSON_OUTPUT:-0}" == "1" ]]; then
        # Convert associative array to JSON
        echo "{"
        local first=true
        for key in "${!data_ref[@]}"; do
            $first || echo ","
            first=false
            echo -n "  \"$key\": \"${data_ref[$key]}\""
        done
        echo
        echo "}"
    fi
}

# Usage example:
show_status() {
    # ... gather data ...
    
    if [[ "${JSON_OUTPUT:-0}" == "1" ]]; then
        echo "{"
        echo "  \"installed\": $installed_count,"
        echo "  \"missing\": $missing_count,"
        echo "  \"tools\": ["
        # ... list tools as JSON array ...
        echo "  ]"
        echo "}"
    else
        # Normal human-readable output
        show_tool_status_grid
    fi
}
```

## 14.3 --quiet Flag

### What It Does
Suppresses non-essential output for scripting.

```bash
QUIET="${QUIET:-0}"

# Modified print functions
print_info() {
    [[ "${QUIET:-0}" == "1" ]] && return
    _print "[*]" "$C_INFO" "$@"
}

# Errors and success should still show in quiet mode
print_error() {
    _print "[✗]" "$C_ERROR" "$@"
}
```

## 14.4 --verbose Flag

### What It Does
Shows additional detail including commands being executed.

```bash
VERBOSE="${VERBOSE:-0}"

# In tool functions:
run_nmap() {
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        print_info "Target: $target"
        print_info "Output: $output_file"
        log_command_preview "nmap $flags $target"
    fi
    
    # ... execute ...
}
```

---

# 15. CONFIGURATION SYSTEM

## 15.1 config_get()

```bash
CONFIG_FILE="$VOIDWAVE_CONFIG_DIR/voidwave.conf"

config_get() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}
```

## 15.2 config_set()

```bash
config_set() {
    local key="$1"
    local value="$2"
    
    ensure_dir "$(dirname "$CONFIG_FILE")"
    
    if [[ -f "$CONFIG_FILE" ]] && grep -q "^${key}=" "$CONFIG_FILE"; then
        # Update existing
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    else
        # Add new
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
}
```

## 15.3 config_edit()

```bash
config_edit() {
    local editor="${EDITOR:-nano}"
    
    ensure_dir "$(dirname "$CONFIG_FILE")"
    
    # Create default config if doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# VOIDWAVE Configuration
# Edit settings below

# Logging
VERBOSE=false
DEBUG=false
LOG_LEVEL=INFO

# Safety
VW_UNSAFE_MODE=false

# UI
NO_COLOR=false

# Updates
AUTO_UPDATE_CHECK=true
EOF
    fi
    
    "$editor" "$CONFIG_FILE"
}
```

## 15.4 Default Configuration

```bash
# Default config values (used if not in config file)
declare -A DEFAULT_CONFIG=(
    ["VERBOSE"]="false"
    ["DEBUG"]="false"
    ["LOG_LEVEL"]="INFO"
    ["VW_UNSAFE_MODE"]="false"
    ["NO_COLOR"]="false"
    ["AUTO_UPDATE_CHECK"]="true"
    ["FIRST_RUN_COMPLETE"]="false"
)

# Load config on startup
load_config() {
    for key in "${!DEFAULT_CONFIG[@]}"; do
        local value
        value=$(config_get "$key" "${DEFAULT_CONFIG[$key]}")
        export "$key=$value"
    done
}
```

---

# 16. SESSION MANAGEMENT

## 16.1 session_start()

```bash
SESSION_ID=""
SESSION_FILE=""

session_start() {
    local name="${1:-}"
    
    SESSION_ID="$(date +%Y%m%d_%H%M%S)_$(random_string 8)"
    
    if [[ -n "$name" ]]; then
        SESSION_FILE="$VOIDWAVE_SESSION_DIR/${name}_${SESSION_ID}.session"
    else
        SESSION_FILE="$VOIDWAVE_SESSION_DIR/${SESSION_ID}.session"
    fi
    
    ensure_dir "$VOIDWAVE_SESSION_DIR"
    
    # Initialize session file
    cat > "$SESSION_FILE" << EOF
# VOIDWAVE Session
SESSION_ID=$SESSION_ID
STARTED=$(date -Iseconds)
USER=$(whoami)
HOST=$(hostname)
EOF
    
    print_info "Session started: $SESSION_ID"
    export SESSION_ID SESSION_FILE
}
```

## 16.2 session_save()

```bash
session_save() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$SESSION_FILE" ]]; then
        return 1
    fi
    
    echo "${key}=${value}" >> "$SESSION_FILE"
}

# Save scan results to session
session_save_scan() {
    local target="$1"
    local scan_type="$2"
    local output_file="$3"
    
    session_save "SCAN_TARGET" "$target"
    session_save "SCAN_TYPE" "$scan_type"
    session_save "SCAN_OUTPUT" "$output_file"
    session_save "SCAN_TIME" "$(date -Iseconds)"
}
```

## 16.3 session_resume()

```bash
session_resume() {
    local session_file="$1"
    
    if [[ ! -f "$session_file" ]]; then
        print_error "Session file not found: $session_file"
        return 1
    fi
    
    # Load session variables
    source "$session_file"
    
    print_info "Resumed session: $SESSION_ID"
    print_info "Started: $STARTED"
    
    # Show session summary
    if [[ -n "${SCAN_TARGET:-}" ]]; then
        print_info "Last scan: $SCAN_TARGET ($SCAN_TYPE)"
    fi
}

session_list() {
    print_info "Available sessions:"
    echo
    
    for session in "$VOIDWAVE_SESSION_DIR"/*.session; do
        [[ -f "$session" ]] || continue
        
        local name=$(basename "$session" .session)
        local started=$(grep "^STARTED=" "$session" | cut -d'=' -f2)
        
        echo -e "    ${C_CYAN}•${C_RESET} $name"
        echo -e "      ${C_GRAY}Started: $started${C_RESET}"
    done
}
```

---

# 17. TESTING INFRASTRUCTURE

## 17.1 Unit Tests with bats

### What It Does
Proper unit tests for individual functions using bats (Bash Automated Testing System).

### Implementation — tests/lib/test_safety.bats

```bash
#!/usr/bin/env bats

# Load the library being tested
setup() {
    # Source libraries
    source "$BATS_TEST_DIRNAME/../../lib/core.sh"
    source "$BATS_TEST_DIRNAME/../../lib/safety.sh"
}

@test "is_private_ip returns 0 for 192.168.1.1" {
    run is_private_ip "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "is_private_ip returns 0 for 10.0.0.1" {
    run is_private_ip "10.0.0.1"
    [ "$status" -eq 0 ]
}

@test "is_private_ip returns 0 for 172.16.0.1" {
    run is_private_ip "172.16.0.1"
    [ "$status" -eq 0 ]
}

@test "is_private_ip returns 1 for 8.8.8.8" {
    run is_private_ip "8.8.8.8"
    [ "$status" -eq 1 ]
}

@test "is_valid_ip returns 0 for valid IP" {
    run is_valid_ip "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "is_valid_ip returns 1 for invalid IP" {
    run is_valid_ip "256.256.256.256"
    [ "$status" -eq 1 ]
}

@test "is_valid_ip returns 1 for non-IP string" {
    run is_valid_ip "not-an-ip"
    [ "$status" -eq 1 ]
}

@test "is_valid_cidr returns 0 for valid CIDR" {
    run is_valid_cidr "192.168.1.0/24"
    [ "$status" -eq 0 ]
}

@test "is_valid_cidr returns 1 for IP without prefix" {
    run is_valid_cidr "192.168.1.1"
    [ "$status" -eq 1 ]
}

@test "is_valid_cidr returns 1 for invalid prefix" {
    run is_valid_cidr "192.168.1.0/33"
    [ "$status" -eq 1 ]
}
```

### Implementation — tests/lib/test_detection.bats

```bash
#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../../lib/core.sh"
    source "$BATS_TEST_DIRNAME/../../lib/detection.sh"
}

@test "detect_distro returns non-empty value" {
    run detect_distro
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "detect_distro_family returns valid family" {
    run detect_distro_family
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(debian|redhat|arch|suse|alpine|void|unknown)$ ]]
}

@test "detect_package_manager returns valid manager" {
    run detect_package_manager
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(apt|dnf|yum|pacman|zypper|apk|xbps|unknown)$ ]]
}

@test "check_tool returns 0 for bash" {
    run check_tool "bash"
    [ "$status" -eq 0 ]
}

@test "check_tool returns 1 for nonexistent tool" {
    run check_tool "definitely_not_a_real_tool_12345"
    [ "$status" -eq 1 ]
}

@test "check_interface returns 0 for loopback" {
    run check_interface "lo"
    [ "$status" -eq 0 ]
}

@test "check_interface returns 1 for nonexistent interface" {
    run check_interface "eth999"
    [ "$status" -eq 1 ]
}
```

## 17.2 Integration Tests

### Implementation — tests/integration/test_cli.bats

```bash
#!/usr/bin/env bats

VOIDWAVE="$BATS_TEST_DIRNAME/../../bin/voidwave"

@test "voidwave --version shows version" {
    run "$VOIDWAVE" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^voidwave\ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "voidwave --help shows usage" {
    run "$VOIDWAVE" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "voidwave status runs without error" {
    run "$VOIDWAVE" status
    [ "$status" -eq 0 ]
}

@test "voidwave with invalid command returns error" {
    run "$VOIDWAVE" invalid_command_12345
    [ "$status" -eq 1 ]
}

@test "voidwave --dry-run scan shows command preview" {
    export VW_NON_INTERACTIVE=1
    run "$VOIDWAVE" --dry-run scan 127.0.0.1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]]
}
```

## 17.3 CI Pipeline

### Implementation — .github/workflows/test.yml

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      
      - name: Run ShellCheck
        run: |
          shellcheck bin/voidwave bin/voidwave-install
          shellcheck lib/*.sh modules/*.sh

  syntax:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Bash syntax check
        run: |
          for f in bin/* lib/*.sh modules/*.sh; do
            echo "Checking $f..."
            bash -n "$f"
          done

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      
      - name: Run unit tests
        run: bats tests/lib/*.bats

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      
      - name: Make scripts executable
        run: chmod +x bin/*
      
      - name: Run integration tests
        env:
          VW_NON_INTERACTIVE: 1
        run: bats tests/integration/*.bats
```

---

# SUMMARY

## Total Features Documented: 67

| Category | Count |
|----------|-------|
| Architecture | 8 |
| Wireless | 6 |
| Installer | 6 |
| Stress Testing | 3 |
| Sudo/Privileges | 4 |
| Tool Management | 4 |
| Wizards | 3 |
| Logging | 9 |
| Progress/Feedback | 3 |
| Confirmations | 4 |
| Target Validation | 5 |
| Wordlists | 2 |
| WHOIS | 1 |
| CLI Flags | 4 |
| Configuration | 4 |
| Sessions | 3 |
| Testing | 3 |

## Implementation Priority

1. **Architecture refactor** — Everything else depends on this
2. **Core libraries** — lib/core.sh, lib/safety.sh, lib/detection.sh
3. **Module system** — Extract functions to modules/
4. **Thin dispatcher** — Rewrite main script
5. **Wireless fixes** — High visibility feature
6. **Installer improvements** — User-facing quality of life
7. **Logging system** — Foundation for debugging
8. **Wizards** — User experience
9. **CLI improvements** — Power user features
10. **Testing** — Prevent regressions

---

*Document generated from conversation history analysis.*
*Total estimated implementation time: 40-60 hours*
