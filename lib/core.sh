#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# See LICENSE and NOTICE files in the project root for full details.
# ═══════════════════════════════════════════════════════════════════════════════
#
# Core library: version, colors, logging, error handling, directory setup
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_CORE_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_CORE_LOADED=1

#═══════════════════════════════════════════════════════════════════════════════
# EXIT CODE CONSTANTS
#═══════════════════════════════════════════════════════════════════════════════

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_FAILURE=1
declare -r EXIT_CODE_INVALID_ARGS=2
declare -r EXIT_CODE_PERMISSION=3
declare -r EXIT_CODE_NETWORK=4
declare -r EXIT_CODE_TARGET_INVALID=5
declare -r EXIT_CODE_TOOL_MISSING=6

#═══════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING
#═══════════════════════════════════════════════════════════════════════════════

set -o pipefail

# Global flag to prevent recursive error handling
_VOIDWAVE_IN_ERROR_HANDLER=0

# Enhanced error handler with stack trace
# Args: $1 = exit code, $2 = line number
error_handler() {
    local exit_code="${1:-1}"
    local line_no="${2:-unknown}"
    local func_name="${FUNCNAME[1]:-main}"
    local bash_source="${BASH_SOURCE[1]:-unknown}"

    # Prevent recursive error handling
    [[ $_VOIDWAVE_IN_ERROR_HANDLER -eq 1 ]] && return $exit_code
    _VOIDWAVE_IN_ERROR_HANDLER=1

    # Build stack trace
    local stack_trace=""
    local i
    for ((i=1; i<${#FUNCNAME[@]}; i++)); do
        local func="${FUNCNAME[$i]:-unknown}"
        local src="${BASH_SOURCE[$i]:-unknown}"
        local ln="${BASH_LINENO[$((i-1))]:-?}"
        stack_trace+="    at $func ($src:$ln)\n"
    done

    # Log error details
    echo -e "\033[0;31m[ERROR]\033[0m Script error in $func_name at $bash_source:$line_no (exit code: $exit_code)" >&2
    if [[ -n "$stack_trace" ]]; then
        echo -e "\033[0;90mStack trace:\033[0m" >&2
        echo -e "$stack_trace" >&2
    fi

    # Log to audit if available
    if declare -f log_audit &>/dev/null; then
        log_audit "ERROR" "$func_name at $bash_source:$line_no" "exit_code=$exit_code"
    fi

    _VOIDWAVE_IN_ERROR_HANDLER=0
    return $exit_code
}

# Legacy error handler (wrapper for backwards compatibility)
_voidwave_error_handler() {
    error_handler "$?" "${1:-unknown}"
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP REGISTRY (prevents trap overwriting between modules)
#═══════════════════════════════════════════════════════════════════════════════

# Array to hold registered cleanup functions
declare -a _CLEANUP_REGISTRY=()

# Register a cleanup function (call this instead of setting EXIT trap directly)
# Usage: register_cleanup "function_name"
register_cleanup() {
    local func="$1"
    # Avoid duplicate registrations
    local existing
    for existing in "${_CLEANUP_REGISTRY[@]}"; do
        [[ "$existing" == "$func" ]] && return 0
    done
    _CLEANUP_REGISTRY+=("$func")
}

# Unregister a cleanup function
unregister_cleanup() {
    local func="$1"
    local new_registry=()
    local existing
    for existing in "${_CLEANUP_REGISTRY[@]}"; do
        [[ "$existing" != "$func" ]] && new_registry+=("$existing")
    done
    _CLEANUP_REGISTRY=("${new_registry[@]}")
}

# Master cleanup - runs all registered cleanup functions
_voidwave_cleanup() {
    local func
    # Run cleanups in reverse order (LIFO - last registered runs first)
    for ((i=${#_CLEANUP_REGISTRY[@]}-1; i>=0; i--)); do
        func="${_CLEANUP_REGISTRY[i]}"
        if declare -F "$func" &>/dev/null; then
            "$func" 2>/dev/null || true
        fi
    done
}

# Set traps (modules should use register_cleanup instead of direct trap)
trap 'error_handler $? $LINENO' ERR
trap '_voidwave_cleanup' EXIT

#═══════════════════════════════════════════════════════════════════════════════
# VERSION INFORMATION
#═══════════════════════════════════════════════════════════════════════════════

# Source shared version helper to prevent drift between CLI output,
# VERSION file, documentation, and release workflow.
# shellcheck source=version.sh
source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
readonly CODENAME="Phantom Protocol"
readonly SCRIPT_NAME="voidwave"

#═══════════════════════════════════════════════════════════════════════════════
# COLOR DEFINITIONS
#═══════════════════════════════════════════════════════════════════════════════

# Check if colors are supported
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    # Reset
    C_RESET='\033[0m'

    # Basic colors
    C_BLACK='\033[0;30m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_PURPLE='\033[0;35m'
    C_CYAN='\033[0;36m'
    C_WHITE='\033[0;37m'
    C_GRAY='\033[0;90m'

    # Bold colors
    C_BOLD='\033[1m'
    C_BRED='\033[1;31m'
    C_BGREEN='\033[1;32m'
    C_BYELLOW='\033[1;33m'
    C_BCYAN='\033[1;36m'

    # Custom theme colors
    C_FIRE='\033[1;31m'
    C_BLOOD='\033[0;31m'
    C_GHOST='\033[0;90m'
    C_SHADOW='\033[0;90m'
    C_BORDER='\033[0;36m'
    C_PROMPT='\033[0;33m'
    C_ORANGE='\033[0;33m'

    # Semantic aliases
    C_SUCCESS="$C_GREEN"
    C_ERROR="$C_RED"
    C_WARNING="$C_YELLOW"
    C_INFO="$C_CYAN"
else
    # No colors
    C_RESET='' C_BLACK='' C_RED='' C_GREEN='' C_YELLOW=''
    C_BLUE='' C_PURPLE='' C_CYAN='' C_WHITE='' C_GRAY=''
    C_BOLD='' C_BRED='' C_BGREEN='' C_BYELLOW='' C_BCYAN=''
    C_FIRE='' C_BLOOD='' C_GHOST='' C_SHADOW='' C_BORDER=''
    C_PROMPT='' C_ORANGE='' C_SUCCESS='' C_ERROR='' C_WARNING='' C_INFO=''
fi

# Legacy aliases to preserve existing styling
readonly C_VENOM="${C_GREEN}"
readonly C_SKULL="${C_WHITE}"
readonly C_GOLD="${C_ORANGE}"

# Compatibility for legacy color references
[[ -z "${C_STEEL:-}" ]] && C_STEEL="${C_CYAN}"
[[ -z "${C_DIM:-}" ]] && C_DIM="${C_SHADOW}"

#═══════════════════════════════════════════════════════════════════════════════
# DIRECTORY & FILE SETUP
#═══════════════════════════════════════════════════════════════════════════════

VOIDWAVE_HOME="${HOME}/.voidwave"
CONFIG_DIR="${VOIDWAVE_HOME}/config"
CONFIG_FILE="${CONFIG_DIR}/voidwave.conf"
LOG_DIR="${VOIDWAVE_HOME}/logs"
OUTPUT_DIR="${VOIDWAVE_HOME}/output"
LOOT_DIR="${VOIDWAVE_HOME}/loot"
SESSION_DIR="${VOIDWAVE_HOME}/sessions"
HISTORY_FILE="${VOIDWAVE_HOME}/target_history"

# Alias for logging system compatibility
VOIDWAVE_LOG_DIR="$LOG_DIR"

# Runtime flags
VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"
QUIET="${QUIET:-false}"

# Compatibility/legacy paths
BASE_LOG_DIR="$LOG_DIR"
BASE_OUTPUT_DIR="$OUTPUT_DIR"
BASE_LOOT_DIR="$LOOT_DIR"
SESSIONS_DIR="$SESSION_DIR"
SESSION_FILE="${SESSION_DIR}/.current_session"
LEGAL_FILE="${CONFIG_DIR}/.legal_accepted"
FAVORITES_FILE="${CONFIG_DIR}/favorites"
ALIASES_FILE="${CONFIG_DIR}/aliases"
PROFILES_DIR="${CONFIG_DIR}/profiles"
TMP_DIR="/tmp/voidwave"
CURRENT_SESSION=""
SESSION_NAME=""

DEFAULT_INTERFACE=""
DEFAULT_WORDLIST="/usr/share/wordlists/rockyou.txt"
DEFAULT_THEME="default"

#═══════════════════════════════════════════════════════════════════════════════
# DIRECTORY INITIALIZATION
#═══════════════════════════════════════════════════════════════════════════════

# Create a single directory (used by logging system)
# Returns: 0 on success, 1 on failure
ensure_dir() {
    local dir="$1"
    [[ -z "$dir" ]] && return 1
    [[ -d "$dir" ]] && return 0
    mkdir -p "$dir" 2>/dev/null
    return $?
}

ensure_directories() {
    # Handle legacy config file path (previously a file at $CONFIG_DIR)
    if [[ -e "$CONFIG_DIR" && ! -d "$CONFIG_DIR" ]]; then
        local legacy_backup
        legacy_backup="${CONFIG_DIR}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$CONFIG_DIR" "$legacy_backup" 2>/dev/null || cp "$CONFIG_DIR" "$legacy_backup" 2>/dev/null
        mkdir -p "$CONFIG_DIR"
        mv "$legacy_backup" "$CONFIG_FILE" 2>/dev/null || cp "$legacy_backup" "$CONFIG_FILE" 2>/dev/null
    fi

    # Create all directories
    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$OUTPUT_DIR" "$LOOT_DIR" "$SESSION_DIR" "$PROFILES_DIR" "$TMP_DIR" 2>/dev/null
    chmod 700 "$VOIDWAVE_HOME" 2>/dev/null

    # Migrate legacy flat-file locations into new structure
    for legacy_file in "$VOIDWAVE_HOME/favorites" "$VOIDWAVE_HOME/aliases"; do
        local dest_path
        dest_path="$CONFIG_DIR/$(basename "$legacy_file")"
        if [[ -f "$legacy_file" && ! -f "$dest_path" ]]; then
            mv "$legacy_file" "$dest_path" 2>/dev/null || cp "$legacy_file" "$dest_path" 2>/dev/null
        fi
    done

    if [[ -f "$VOIDWAVE_HOME/history" && ! -f "$HISTORY_FILE" ]]; then
        mv "$VOIDWAVE_HOME/history" "$HISTORY_FILE" 2>/dev/null || cp "$VOIDWAVE_HOME/history" "$HISTORY_FILE" 2>/dev/null
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# LOGGING CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_SUCCESS=2
declare -r LOG_LEVEL_WARNING=3
declare -r LOG_LEVEL_ERROR=4
declare -r LOG_LEVEL_FATAL=5

# Current log level (default: INFO)
CURRENT_LOG_LEVEL="${VOIDWAVE_LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Log file paths (daily rotation)
VOIDWAVE_LOG_FILE="${VOIDWAVE_LOG_DIR}/voidwave_$(date +%Y%m%d).log"
VOIDWAVE_AUDIT_FILE="${VOIDWAVE_LOG_DIR}/audit_$(date +%Y%m%d).log"

# Legacy aliases for backwards compatibility
LOG_FILE="$VOIDWAVE_LOG_FILE"
AUDIT_LOG="$VOIDWAVE_AUDIT_FILE"

# Enable/disable file logging (default: enabled)
FILE_LOGGING="${VOIDWAVE_FILE_LOGGING:-1}"

# Log format: "text" (default) or "json" for structured logging
VOIDWAVE_LOG_FORMAT="${VOIDWAVE_LOG_FORMAT:-text}"

#═══════════════════════════════════════════════════════════════════════════════
# CORE LOG FUNCTION
#═══════════════════════════════════════════════════════════════════════════════

_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local symbol="$4"
    shift 4
    local message="$*"
    local timestamp timestamp_iso
    # Use printf builtin for timestamp (faster than date subshell)
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    printf -v timestamp_iso '%(%Y-%m-%dT%H:%M:%S)T' -1

    # Suppress all console/stderr output when VW_SUPPRESS_OUTPUT is set
    # File logging is also suppressed for simplicity in CI/test contexts
    [[ "${VW_SUPPRESS_OUTPUT:-0}" == "1" ]] && return 0

    # Check log level threshold
    [[ $level_num -lt $CURRENT_LOG_LEVEL ]] && return 0

    # Respect QUIET mode for non-error messages
    if [[ "$QUIET" == "true" || "$QUIET" == "1" ]] && [[ $level_num -lt $LOG_LEVEL_ERROR ]]; then
        # Still log to file, just don't print to console
        :
    else
        # Console output - format depends on VOIDWAVE_LOG_FORMAT
        if [[ "$VOIDWAVE_LOG_FORMAT" == "json" ]]; then
            # JSON format for structured logging (escape special chars in message)
            local escaped_msg="${message//\\/\\\\}"
            escaped_msg="${escaped_msg//\"/\\\"}"
            escaped_msg="${escaped_msg//$'\n'/\\n}"
            echo "{\"timestamp\":\"${timestamp_iso}\",\"level\":\"${level}\",\"message\":\"${escaped_msg}\"}" >&2
        else
            # Standard text format - ALL log messages go to stderr to preserve stdout for data
            echo -e "    ${color}[${symbol}]${C_RESET} $message" >&2
        fi
    fi

    # File logging (always text format for readability)
    if [[ "$FILE_LOGGING" == "1" && -n "$VOIDWAVE_LOG_FILE" ]]; then
        ensure_dir "$(dirname "$VOIDWAVE_LOG_FILE")"
        echo "[$timestamp] [$level] $message" >> "$VOIDWAVE_LOG_FILE" 2>/dev/null || true
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# LOGGING FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

log_debug() {
    # Also respect legacy DEBUG flag
    if [[ "$DEBUG" == "true" ]] || [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        local orig_level=$CURRENT_LOG_LEVEL
        CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
        _log "DEBUG" "$LOG_LEVEL_DEBUG" "$C_GRAY" "~" "$@"
        CURRENT_LOG_LEVEL=$orig_level
    else
        _log "DEBUG" "$LOG_LEVEL_DEBUG" "$C_GRAY" "~" "$@"
    fi
}

log_verbose() {
    # Verbose is between debug and info
    if [[ "$VERBOSE" == "true" ]]; then
        _log "VERBOSE" "$LOG_LEVEL_DEBUG" "$C_SHADOW" "*" "$@"
    fi
}

log_info()    { _log "INFO"    "$LOG_LEVEL_INFO"    "$C_CYAN"   "*" "$@"; }
log_success() { _log "SUCCESS" "$LOG_LEVEL_SUCCESS" "$C_GREEN"  "✓" "$@"; }
log_warning() { _log "WARNING" "$LOG_LEVEL_WARNING" "$C_YELLOW" "!" "$@"; }
log_error()   { _log "ERROR"   "$LOG_LEVEL_ERROR"   "$C_RED"    "✗" "$@"; }

log_fatal() {
    _log "FATAL" "$LOG_LEVEL_FATAL" "$C_BRED" "☠" "$@"
    exit 1
}

#═══════════════════════════════════════════════════════════════════════════════
# AUDIT LOGGING
#═══════════════════════════════════════════════════════════════════════════════

log_audit() {
    local action="${1:-ACTION}"
    local target="${2:-}"
    local result="${3:-}"
    local timestamp
    # Use printf builtin for timestamp (faster than date subshell)
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    local user="${USER:-unknown}"

    ensure_dir "$(dirname "$VOIDWAVE_AUDIT_FILE")"
    echo "[$timestamp] USER=$user ACTION=$action TARGET=\"$target\" RESULT=\"$result\" PID=$$" >> "$VOIDWAVE_AUDIT_FILE" 2>/dev/null || true
    log_debug "AUDIT: $action - $target - $result"
}

log_command_preview() {
    local cmd="${1:-}"

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "    ${C_SHADOW}\$ ${cmd}${C_RESET}"
    fi

    # File logging
    if [[ "$FILE_LOGGING" == "1" && -n "$VOIDWAVE_LOG_FILE" ]]; then
        ensure_dir "$(dirname "$VOIDWAVE_LOG_FILE")"
        local timestamp
        # Use printf builtin for timestamp (faster than date subshell)
        printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
        echo "[$timestamp] [EXEC] $cmd" >> "$VOIDWAVE_LOG_FILE" 2>/dev/null || true
    fi

    log_audit "EXECUTE" "${cmd:0:200}" "started"
}

#═══════════════════════════════════════════════════════════════════════════════
# BACKWARDS COMPATIBILITY (print_* functions)
#═══════════════════════════════════════════════════════════════════════════════

print_info()    { log_info "$@"; }
print_success() { log_success "$@"; }
print_warning() { log_warning "$@"; }
print_error()   { log_error "$@"; }
print_debug()   { log_debug "$@"; }

#═══════════════════════════════════════════════════════════════════════════════
# LOG UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

set_log_level() {
    case "${1^^}" in
        DEBUG)   CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        INFO)    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        SUCCESS) CURRENT_LOG_LEVEL=$LOG_LEVEL_SUCCESS ;;
        WARNING) CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING ;;
        ERROR)   CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        FATAL)   CURRENT_LOG_LEVEL=$LOG_LEVEL_FATAL ;;
        *)       log_warning "Unknown log level: $1" ;;
    esac
}

show_logs() {
    local lines="${1:-50}"
    if [[ -f "$VOIDWAVE_LOG_FILE" ]]; then
        tail -n "$lines" "$VOIDWAVE_LOG_FILE"
    else
        log_warning "No log file found at $VOIDWAVE_LOG_FILE"
    fi
}

rotate_logs() {
    local max_days="${1:-30}"
    if [[ -d "$VOIDWAVE_LOG_DIR" ]]; then
        find "$VOIDWAVE_LOG_DIR" -name "*.log" -mtime "+$max_days" -delete 2>/dev/null
        log_success "Rotated logs older than $max_days days"
    else
        log_warning "Log directory not found: $VOIDWAVE_LOG_DIR"
    fi
}

init_logging() {
    ensure_dir "$VOIDWAVE_LOG_DIR"
    touch "$VOIDWAVE_LOG_FILE" "$VOIDWAVE_AUDIT_FILE" 2>/dev/null
    chmod 600 "$VOIDWAVE_LOG_FILE" "$VOIDWAVE_AUDIT_FILE" 2>/dev/null || true
    log_debug "VOIDWAVE v${VERSION} (${CODENAME}) started at $(date '+%Y-%m-%d %H:%M:%S')"
}

# Semantic logging aliases (for attack/target/loot operations)
log_attack()  { log_warning "$@"; }
log_target()  { log_info "$@"; }
log_loot()    { log_success "$@"; }

# Legacy file logging function (now wraps new system)
log_to_file() {
    local message="$1"
    local timestamp
    [[ -z "${VOIDWAVE_LOG_FILE:-}" ]] && return 0
    [[ ! -d "${VOIDWAVE_LOG_FILE%/*}" ]] && return 0
    # Use printf builtin for timestamp (faster than date subshell)
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    echo "[$timestamp] $message" >> "$VOIDWAVE_LOG_FILE" 2>/dev/null || true
}

#═══════════════════════════════════════════════════════════════════════════════
# PRIVILEGE HANDLING
#═══════════════════════════════════════════════════════════════════════════════

# Capture original CLI arguments as seen by the main script
# Note: Dispatcher should set ORIGINAL_ARGS before sourcing; this is a fallback
# Use ${var+x} pattern to avoid "unbound variable" errors with set -u
if [[ -z "${ORIGINAL_ARGS[*]+x}" ]]; then
    declare -ga ORIGINAL_ARGS=("$@")
fi

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root for an operation, log error and hint if not
require_root() {
    local operation="${1:-This operation}"
    if ! is_root; then
        log_error "$operation requires root privileges"
        log_info "Run with: sudo $0 ${ORIGINAL_ARGS[*]:-}"
        return 1
    fi
    return 0
}

# Run a command with sudo if not already root
run_with_sudo() {
    if is_root; then
        "$@"
    else
        log_debug "Elevating command via sudo: $*"
        sudo "$@"
    fi
}

# Prompt user to elevate privileges if needed, re-exec script as root
elevate_if_needed() {
    local operation="${1:-This operation}"

    # Already root - nothing to do
    is_root && return 0

    log_warning "$operation requires root privileges"

    # Non-interactive mode - cannot safely prompt
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]]; then
        log_error "Cannot elevate in non-interactive mode"
        return 1
    fi

    # Check if we have a TTY to prompt
    if [[ ! -t 0 ]]; then
        log_error "No TTY available for privilege elevation"
        return 1
    fi

    echo -ne "    ${C_CYAN}Elevate to root? [y/N]:${C_RESET} "
    read -r response

    if [[ "${response,,}" =~ ^y ]]; then
        log_audit "ELEVATE" "$operation" "user_approved"
        exec sudo "$0" "${ORIGINAL_ARGS[@]}"
    else
        log_error "Cannot continue without root"
        log_audit "ELEVATE" "$operation" "user_denied"
        return 1
    fi
}

# Fast check if we can get root (already root, passwordless sudo, or TTY available)
can_get_root() {
    # Already root
    is_root && return 0

    # Succeeds with non-interactive sudo (passwordless or cached credentials)
    sudo -n true 2>/dev/null && return 0

    # Interactive TTY available (user can type password)
    [[ -t 0 ]] && return 0

    return 1
}

# Operations that are considered root-only at the CLI level
declare -ga ROOT_OPS=(wifi scan stress exploit traffic sniff mitm capture inject)

# Check if an operation needs root
operation_needs_root() {
    local op="$1"
    local root_op
    for root_op in "${ROOT_OPS[@]}"; do
        [[ "$op" == "$root_op" ]] && return 0
    done
    return 1
}

# Check and enforce root for a specific operation (convenience wrapper)
enforce_root_for() {
    local operation="$1"
    if operation_needs_root "$operation"; then
        require_root "$operation" || return 1
    fi
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# DRY-RUN EXECUTION WRAPPERS
#═══════════════════════════════════════════════════════════════════════════════

# Safe command execution wrapper
# Respects VW_DRY_RUN flag - prints command instead of executing
nr_run() {
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} $*" >&2
        return 0
    fi
    "$@"
}

# For commands that need shell evaluation
nr_run_eval() {
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} $*" >&2
        return 0
    fi
    eval "$@"
}

# Run with sudo, respecting dry-run mode
nr_run_sudo() {
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} sudo $*" >&2
        return 0
    fi
    run_with_sudo "$@"
}

#═══════════════════════════════════════════════════════════════════════════════
# UNIFIED ERROR HANDLING FRAMEWORK
#═══════════════════════════════════════════════════════════════════════════════

# die() - Print fatal error, log to audit, and exit
# Args: $1 = message, $2 = exit code (optional, default: 1)
die() {
    local message="${1:-Fatal error}"
    local exit_code="${2:-$EXIT_CODE_FAILURE}"

    log_error "$message"
    log_audit "FATAL" "$message" "exit_code=$exit_code"

    # Log stack trace if DEBUG enabled
    if [[ "$DEBUG" == "true" || $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        local i
        for ((i=1; i<${#FUNCNAME[@]}; i++)); do
            local func="${FUNCNAME[$i]:-unknown}"
            local src="${BASH_SOURCE[$i]:-unknown}"
            local ln="${BASH_LINENO[$((i-1))]:-?}"
            echo -e "    ${C_GRAY}at $func ($src:$ln)${C_RESET}" >&2
        done
    fi

    exit "$exit_code"
}

# assert() - Check a condition, log error and return 1 if false
# Args: $1 = condition (string to eval), $2 = message on failure
# Returns: 0 if condition true, 1 if false
assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"

    if ! eval "$condition"; then
        log_error "ASSERT: $message"
        log_audit "ASSERT_FAILED" "$message" "condition=$condition"
        return 1
    fi
    return 0
}

# try() - Run a command safely with error capture
# Captures stderr, logs on failure, returns command's exit code
# Usage: try <cmd> [args...] || die "message"
# Returns: command's exit code
try() {
    local cmd_str="$*"
    local stderr_file
    stderr_file=$(mktemp 2>/dev/null || echo "/tmp/voidwave_try_$$")
    local exit_code

    log_debug "TRY: $cmd_str"
    log_audit "TRY" "${cmd_str:0:200}" "started"

    # Execute command, capture stderr
    "$@" 2>"$stderr_file"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        local stderr_content=""
        if [[ -f "$stderr_file" ]]; then
            stderr_content=$(cat "$stderr_file" 2>/dev/null | head -5)
        fi

        log_error "Command failed (exit $exit_code): $cmd_str"
        if [[ -n "$stderr_content" ]]; then
            log_debug "stderr: $stderr_content"
        fi
        log_audit "TRY" "${cmd_str:0:200}" "failed:$exit_code"
    else
        log_audit "TRY" "${cmd_str:0:200}" "success"
    fi

    # Cleanup
    rm -f "$stderr_file" 2>/dev/null

    return $exit_code
}

# require_tool() - Check if a tool exists
# Returns EXIT_CODE_TOOL_MISSING if not found; caller must handle the error.
# This function is NOT fatal - it returns an error code rather than exiting.
#
# Args: $1 = binary name, $2 = optional package hint
# Returns: 0 if tool exists, EXIT_CODE_TOOL_MISSING (6) if not
#
# Example usage:
#   require_tool nmap || die "nmap is required for scanning"
#   require_tool hashcat || { log_warning "hashcat not found, skipping"; return 1; }
require_tool() {
    local tool="$1"
    local package_hint="${2:-$tool}"

    if ! command -v "$tool" &>/dev/null; then
        log_error "Required tool not found: $tool"
        log_info "Install with: sudo apt install $package_hint"
        log_audit "TOOL_MISSING" "$tool" "required"
        return $EXIT_CODE_TOOL_MISSING
    fi

    log_debug "Tool available: $tool"
    return 0
}

# check_tool() - Check if a tool exists (non-fatal)
# Args: $1 = binary name
# Returns: 0 if exists, 1 if not
check_tool() {
    local tool="$1"
    [[ -z "$tool" ]] && return 1
    command -v "$tool" &>/dev/null
}

# get_tool_path() - Get full path to a tool
# Args: $1 = binary name
# Returns: full path via stdout, empty if not found
get_tool_path() {
    local tool="$1"
    [[ -z "$tool" ]] && return 1
    command -v "$tool" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Core logging
export -f _log
export -f log_debug log_verbose log_info log_success log_warning log_error log_fatal
export -f log_audit log_command_preview log_to_file
export -f log_attack log_target log_loot init_logging

# Backwards compatibility
export -f print_info print_success print_warning print_error print_debug

# Log utilities
export -f set_log_level show_logs rotate_logs

# Directory functions
export -f ensure_dir ensure_directories

# Privilege handling
export -f is_root require_root run_with_sudo elevate_if_needed can_get_root
export -f operation_needs_root enforce_root_for

# Dry-run wrappers
export -f nr_run nr_run_eval nr_run_sudo

# Error handlers and cleanup registry
export -f error_handler _voidwave_error_handler _voidwave_cleanup
export -f register_cleanup unregister_cleanup

# Unified error handling framework
export -f die assert try require_tool check_tool get_tool_path

# Export variables
export VERSION CODENAME SCRIPT_NAME
export VOIDWAVE_ROOT VOIDWAVE_HOME CONFIG_DIR CONFIG_FILE LOG_DIR OUTPUT_DIR LOOT_DIR SESSION_DIR
export VOIDWAVE_LOG_DIR VOIDWAVE_LOG_FILE VOIDWAVE_AUDIT_FILE
export LOG_FILE AUDIT_LOG HISTORY_FILE
export BASE_LOG_DIR BASE_OUTPUT_DIR BASE_LOOT_DIR SESSIONS_DIR SESSION_FILE
export LEGAL_FILE FAVORITES_FILE ALIASES_FILE PROFILES_DIR TMP_DIR
export CURRENT_SESSION SESSION_NAME
export DEFAULT_INTERFACE DEFAULT_WORDLIST DEFAULT_THEME
export VERBOSE DEBUG QUIET
export CURRENT_LOG_LEVEL FILE_LOGGING
export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_SUCCESS LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_FATAL
export EXIT_CODE_SUCCESS EXIT_CODE_FAILURE EXIT_CODE_INVALID_ARGS EXIT_CODE_PERMISSION
export EXIT_CODE_NETWORK EXIT_CODE_TARGET_INVALID EXIT_CODE_TOOL_MISSING
export C_RESET C_BLACK C_RED C_GREEN C_YELLOW C_BLUE C_PURPLE C_CYAN C_WHITE C_GRAY
export C_BOLD C_BRED C_BGREEN C_BYELLOW C_BCYAN
export C_FIRE C_BLOOD C_GHOST C_SHADOW C_BORDER C_PROMPT C_ORANGE
export C_SUCCESS C_ERROR C_WARNING C_INFO
export C_VENOM C_SKULL C_GOLD C_STEEL C_DIM
