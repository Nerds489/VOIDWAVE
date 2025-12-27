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
# Session Management Library: pause, resume, and track long-running operations
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_SESSIONS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_SESSIONS_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION GLOBALS
# ═══════════════════════════════════════════════════════════════════════════════
declare -g SESSION_ID=""
declare -g SESSION_FILE=""
declare -gA SESSION_DATA=()

# Session directory (respect explicit override, then use SESSION_DIR from core.sh)
if [[ -z "${VOIDWAVE_SESSION_DIR:-}" ]]; then
    VOIDWAVE_SESSION_DIR="${SESSION_DIR:-${VOIDWAVE_HOME:-$HOME/.voidwave}/sessions}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

# Start new session
# Usage: session_id=$(session_start "scan_operation")
session_start() {
    local name="${1:-session}"
    local timestamp
    # Use printf builtin for timestamp (faster than date subshell)
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1

    SESSION_ID="${name}_${timestamp}_$$"
    SESSION_FILE="${VOIDWAVE_SESSION_DIR}/${SESSION_ID}.session"

    # Ensure directory exists
    mkdir -p "$(dirname "$SESSION_FILE")" 2>/dev/null || true

    # Initialize session data
    SESSION_DATA=(
        [id]="$SESSION_ID"
        [name]="$name"
        [created]="$(date -Iseconds)"
        [updated]="$(date -Iseconds)"
        [status]="active"
        [progress]="0"
        [total]="0"
    )

    session_save

    # Audit log if available
    type -t log_audit &>/dev/null && log_audit "SESSION_START" "$SESSION_ID"

    echo "$SESSION_ID"
}

# Save current session state to disk
session_save() {
    [[ -z "$SESSION_FILE" ]] && return 1
    [[ ${#SESSION_DATA[@]} -eq 0 ]] && return 1

    SESSION_DATA[updated]="$(date -Iseconds)"

    # Write atomically via temp file
    local tmp_file="${SESSION_FILE}.tmp"
    {
        echo "# VOIDWAVE Session File"
        echo "# Do not edit manually"
        for key in "${!SESSION_DATA[@]}"; do
            # Escape values with printf %q to handle special characters
            printf '%s=%q\n' "$key" "${SESSION_DATA[$key]}"
        done
    } > "$tmp_file"

    mv "$tmp_file" "$SESSION_FILE"
}

# Set session variable
# Usage: session_set "target" "192.168.1.0/24"
session_set() {
    local key="$1"
    local value="$2"

    [[ -z "$key" ]] && return 1

    SESSION_DATA[$key]="$value"
    session_save
}

# Get session variable
# Usage: target=$(session_get "target")
session_get() {
    local key="$1"
    echo "${SESSION_DATA[$key]:-}"
}

# Validate session ID to prevent path traversal
# Usage: _validate_session_id "scan_20241215_143022_12345"
_validate_session_id() {
    local id="$1"
    [[ -z "$id" ]] && return 1
    # Only allow alphanumeric, underscore, hyphen, and dot
    [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || {
        echo "Error: Invalid session ID format: $id"
        return 1
    }
    return 0
}

# Resume existing session
# Usage: session_resume "scan_operation_20241215_143022_12345"
session_resume() {
    local id="$1"

    [[ -z "$id" ]] && {
        echo "Error: Session ID required"
        return 1
    }

    # Validate session ID to prevent path traversal
    _validate_session_id "$id" || return 1

    SESSION_FILE="${VOIDWAVE_SESSION_DIR}/${id}.session"

    [[ ! -f "$SESSION_FILE" ]] && {
        echo "Error: Session not found: $id"
        return 1
    }

    # Clear existing data
    SESSION_DATA=()

    # Parse session file with proper unescaping
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Trim whitespace from key
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"

        # Unescape value (printf %q format)
        value=$(printf '%b' "$value" 2>/dev/null) || value=""
        SESSION_DATA[$key]="$value"
    done < "$SESSION_FILE"

    SESSION_ID="${SESSION_DATA[id]}"
    SESSION_DATA[status]="resumed"
    session_save

    # Log resume
    if type -t log_info &>/dev/null; then
        log_info "Session resumed: $SESSION_ID"
        log_info "  Name: ${SESSION_DATA[name]:-N/A}"
        log_info "  Target: ${SESSION_DATA[target]:-N/A}"
        log_info "  Progress: ${SESSION_DATA[progress]:-0}/${SESSION_DATA[total]:-0}"
    else
        echo "Session resumed: $SESSION_ID"
        echo "  Name: ${SESSION_DATA[name]:-N/A}"
        echo "  Progress: ${SESSION_DATA[progress]:-0}/${SESSION_DATA[total]:-0}"
    fi

    type -t log_audit &>/dev/null && log_audit "SESSION_RESUME" "$SESSION_ID"

    return 0
}

# Mark session as completed
session_end() {
    [[ -z "$SESSION_FILE" ]] && return 0

    SESSION_DATA[status]="completed"
    SESSION_DATA[ended]="$(date -Iseconds)"
    session_save

    type -t log_audit &>/dev/null && log_audit "SESSION_END" "$SESSION_ID"

    # Clear globals
    SESSION_ID=""
    SESSION_FILE=""
}

# Mark session as failed
session_fail() {
    local reason="${1:-unknown}"

    [[ -z "$SESSION_FILE" ]] && return 0

    SESSION_DATA[status]="failed"
    SESSION_DATA[error]="$reason"
    SESSION_DATA[ended]="$(date -Iseconds)"
    session_save

    type -t log_audit &>/dev/null && log_audit "SESSION_FAIL" "$SESSION_ID" "$reason"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# List all sessions
# Usage: session_list [--active|--completed|--failed]
session_list() {
    local filter="${1:-}"
    local session_dir="${VOIDWAVE_SESSION_DIR}"

    [[ ! -d "$session_dir" ]] && {
        echo "No sessions found"
        return 0
    }

    # Check if any session files exist
    local has_sessions=0
    for f in "$session_dir"/*.session; do
        [[ -f "$f" ]] && { has_sessions=1; break; }
    done

    [[ $has_sessions -eq 0 ]] && {
        echo "No sessions found"
        return 0
    }

    local count=0

    echo ""
    printf "    %-40s %-12s %-20s\n" "SESSION ID" "STATUS" "CREATED"
    printf "    %s\n" "$(printf '─%.0s' {1..75})"

    for f in "$session_dir"/*.session; do
        [[ -f "$f" ]] || continue

        local id name status created
        id=$(grep "^id=" "$f" 2>/dev/null | cut -d= -f2)
        name=$(grep "^name=" "$f" 2>/dev/null | cut -d= -f2)
        status=$(grep "^status=" "$f" 2>/dev/null | cut -d= -f2)
        created=$(grep "^created=" "$f" 2>/dev/null | cut -d= -f2)

        # Apply filter
        case "$filter" in
            --active)    [[ "$status" != "active" && "$status" != "resumed" ]] && continue ;;
            --completed) [[ "$status" != "completed" ]] && continue ;;
            --failed)    [[ "$status" != "failed" ]] && continue ;;
        esac

        # Color status
        local status_color=""
        case "$status" in
            active|resumed) status_color="${C_GREEN:-}" ;;
            completed)      status_color="${C_CYAN:-}" ;;
            failed)         status_color="${C_RED:-}" ;;
        esac

        printf "    %-40s ${status_color}%-12s${C_RESET:-} %-20s\n" \
            "${id:0:40}" "$status" "${created:0:19}"

        ((count++)) || true
    done

    echo ""
    echo "    Total: $count session(s)"

    [[ $count -eq 0 ]] && return 1
    return 0
}

# Get session details
# Usage: session_info "session_id"
session_info() {
    local id="$1"

    # Validate session ID to prevent path traversal
    _validate_session_id "$id" || return 1

    local session_file="${VOIDWAVE_SESSION_DIR}/${id}.session"

    [[ ! -f "$session_file" ]] && {
        echo "Error: Session not found: $id"
        return 1
    }

    echo ""
    echo "    Session: $id"
    printf "    %s\n" "$(printf '─%.0s' {1..60})"

    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        # Unescape value for display
        value=$(printf '%b' "$value" 2>/dev/null) || value=""
        printf "    %-15s %s\n" "$key:" "$value"
    done < "$session_file"

    echo ""
}

# Delete session
# Usage: session_delete "session_id"
session_delete() {
    local id="$1"

    # Validate session ID to prevent path traversal
    _validate_session_id "$id" || return 1

    local session_file="${VOIDWAVE_SESSION_DIR}/${id}.session"

    [[ ! -f "$session_file" ]] && {
        echo "Error: Session not found: $id"
        return 1
    }

    rm -f "$session_file"
    echo "Session deleted: $id"

    type -t log_audit &>/dev/null && log_audit "SESSION_DELETE" "$id"
}

# Clean old sessions (older than N days)
# Usage: session_cleanup 30
session_cleanup() {
    local days="${1:-30}"
    local session_dir="${VOIDWAVE_SESSION_DIR}"
    local count=0

    [[ ! -d "$session_dir" ]] && {
        echo "No sessions directory found"
        return 0
    }

    while IFS= read -r -d '' f; do
        rm -f "$f"
        ((count++)) || true
    done < <(find "$session_dir" -name "*.session" -mtime +"$days" -print0 2>/dev/null)

    echo "Cleaned $count session(s) older than $days days"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESS TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

# Update progress
# Usage: session_progress 50 100
session_progress() {
    local current="$1"
    local total="${2:-${SESSION_DATA[total]:-100}}"

    SESSION_DATA[progress]="$current"
    SESSION_DATA[total]="$total"
    session_save
}

# Check if session is active
session_is_active() {
    [[ -n "$SESSION_ID" ]] && [[ "${SESSION_DATA[status]}" =~ ^(active|resumed)$ ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export SESSION_ID SESSION_FILE VOIDWAVE_SESSION_DIR
export -f session_start session_save session_set session_get
export -f session_resume session_end session_fail
export -f session_list session_info session_delete session_cleanup
export -f session_progress session_is_active
