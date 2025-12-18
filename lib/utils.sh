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
# Utility library: timestamps, backups, file generation, validation, tool execution
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_UTILS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_UTILS_LOADED=1

# Source core library
source "${BASH_SOURCE%/*}/core.sh"

#═══════════════════════════════════════════════════════════════════════════════
# TIMESTAMP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Generate formatted timestamp
# Args: $1 = format (optional, defaults to ISO-like)
# Returns: formatted timestamp string
timestamp() {
    local format="${1:-%Y-%m-%d %H:%M:%S}"
    date +"$format"
}

# Generate timestamp for filenames (no special chars)
# Returns: YYYYMMDD_HHMMSS format
timestamp_filename() {
    date +"%Y%m%d_%H%M%S"
}

# Generate date-only timestamp
# Returns: YYYY-MM-DD format
timestamp_date() {
    date +"%Y-%m-%d"
}

# Generate ISO 8601 timestamp
# Returns: ISO 8601 format with timezone
timestamp_iso() {
    date -Iseconds
}

#═══════════════════════════════════════════════════════════════════════════════
# FILE BACKUP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Create timestamped backup of a file
# Args: $1 = file path
# Returns: path to backup file, or empty on failure
backup_file() {
    local file="$1"

    # Validate input
    if [[ -z "$file" ]]; then
        log_error "backup_file: No file specified"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "backup_file: File not found: $file"
        return 1
    fi

    # Generate backup filename
    local backup_name="${file}.backup.$(timestamp_filename)"

    # Create backup
    if cp "$file" "$backup_name" 2>/dev/null; then
        log_debug "Created backup: $backup_name"
        echo "$backup_name"
        return 0
    else
        log_error "backup_file: Failed to create backup of $file"
        return 1
    fi
}

# Create backup in a specific directory
# Args: $1 = file path, $2 = backup directory
# Returns: path to backup file
backup_file_to() {
    local file="$1"
    local backup_dir="${2:-$OUTPUT_DIR}"

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        log_error "backup_file_to: Invalid file: $file"
        return 1
    fi

    mkdir -p "$backup_dir" 2>/dev/null

    local basename=$(basename "$file")
    local backup_name="${backup_dir}/${basename}.backup.$(timestamp_filename)"

    if cp "$file" "$backup_name" 2>/dev/null; then
        log_debug "Created backup: $backup_name"
        echo "$backup_name"
        return 0
    else
        log_error "backup_file_to: Failed to create backup"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP FUNCTIONS (NOTE: Main cleanup registry is in core.sh)
#═══════════════════════════════════════════════════════════════════════════════

# Temp file cleanup - registered with core.sh cleanup registry
_utils_cleanup_temp() {
    # Clean temp files (use :? to prevent catastrophic rm if TMP_DIR unset)
    if [[ -n "${TMP_DIR:-}" ]] && [[ -d "$TMP_DIR" ]]; then
        rm -rf "${TMP_DIR:?TMP_DIR not set}"/* 2>/dev/null || true
    fi
}

# Register temp cleanup with core.sh registry if available
if declare -F register_cleanup &>/dev/null; then
    register_cleanup _utils_cleanup_temp
fi

#═══════════════════════════════════════════════════════════════════════════════
# FILENAME GENERATION
#═══════════════════════════════════════════════════════════════════════════════

# Generate unique report/output filename
# Args: $1 = prefix, $2 = extension (optional, default: txt)
# Returns: unique filename path
generate_report_name() {
    local prefix="${1:-report}"
    local extension="${2:-txt}"
    local output_dir="${OUTPUT_DIR:-/tmp}"

    # Sanitize prefix
    prefix=$(echo "$prefix" | tr -cd '[:alnum:]._-')

    # Generate unique name
    local filename="${prefix}_$(timestamp_filename).${extension}"
    local filepath="${output_dir}/${filename}"

    # Ensure output dir exists
    mkdir -p "$output_dir" 2>/dev/null

    echo "$filepath"
}

# Generate unique filename with target in name
# Args: $1 = target, $2 = prefix, $3 = extension
# Returns: unique filename path
generate_target_filename() {
    local target="${1:-unknown}"
    local prefix="${2:-scan}"
    local extension="${3:-txt}"

    # Sanitize target for filename
    local safe_target=$(echo "$target" | tr -cd '[:alnum:]._-' | cut -c1-50)

    generate_report_name "${prefix}_${safe_target}" "$extension"
}

#═══════════════════════════════════════════════════════════════════════════════
# INPUT VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate IPv4 address format
# Args: $1 = IP address
# Returns: 0 if valid, 1 if invalid
validate_ip() {
    local ip="$1"

    # Basic regex check
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    # Check each octet is 0-255
    local IFS='.'
    read -ra octets <<< "$ip"

    for octet in "${octets[@]}"; do
        if [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done

    return 0
}

# Validate CIDR notation
# Args: $1 = CIDR (e.g., 192.168.1.0/24)
# Returns: 0 if valid, 1 if invalid
validate_cidr() {
    local cidr="$1"

    # Check format
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi

    # Split IP and prefix
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    # Validate IP part
    if ! validate_ip "$ip"; then
        return 1
    fi

    # Validate prefix (0-32 for IPv4)
    if [[ "$prefix" -lt 0 ]] || [[ "$prefix" -gt 32 ]]; then
        return 1
    fi

    return 0
}

# Validate hostname format
# Args: $1 = hostname
# Returns: 0 if valid, 1 if invalid
validate_hostname() {
    local hostname="$1"

    # Check format (alphanumeric, hyphens, dots)
    if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi

    return 1
}

# Validate port number
# Args: $1 = port
# Returns: 0 if valid, 1 if invalid
validate_port() {
    local port="$1"

    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    fi

    return 1
}

# Validate port range (e.g., 1-1024 or 80,443,8080)
# Args: $1 = port specification
# Returns: 0 if valid, 1 if invalid
validate_port_spec() {
    local spec="$1"

    # Single port
    if [[ "$spec" =~ ^[0-9]+$ ]]; then
        validate_port "$spec"
        return $?
    fi

    # Range (e.g., 1-1024)
    if [[ "$spec" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start="${spec%-*}"
        local end="${spec#*-}"
        validate_port "$start" && validate_port "$end" && [[ "$start" -le "$end" ]]
        return $?
    fi

    # Comma-separated list
    if [[ "$spec" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        local IFS=','
        read -ra ports <<< "$spec"
        for port in "${ports[@]}"; do
            validate_port "$port" || return 1
        done
        return 0
    fi

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL EXECUTION
#═══════════════════════════════════════════════════════════════════════════════

# Run a tool with logging
# Args: $1 = tool name, $2+ = arguments
# Returns: tool's exit code
run_tool() {
    local tool="$1"
    shift
    local args=("$@")

    # Check tool exists
    if ! command -v "$tool" &>/dev/null; then
        log_error "Tool not found: $tool"
        return 127
    fi

    # Log command
    local cmd_str="$tool ${args[*]}"
    log_command_preview "$cmd_str"
    log_audit "TOOL_EXEC" "$tool" "started"

    # Execute
    local start_time=$(date +%s)
    "$tool" "${args[@]}"
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Log result
    if [[ $exit_code -eq 0 ]]; then
        log_debug "$tool completed successfully in ${duration}s"
        log_audit "TOOL_EXEC" "$tool" "success"
    else
        log_debug "$tool failed with exit code $exit_code after ${duration}s"
        log_audit "TOOL_EXEC" "$tool" "failed:$exit_code"
    fi

    return $exit_code
}

# Run a tool silently (no output)
# Args: $1 = tool name, $2+ = arguments
# Returns: tool's exit code
run_tool_silent() {
    local tool="$1"
    shift

    if ! command -v "$tool" &>/dev/null; then
        return 127
    fi

    "$tool" "$@" &>/dev/null
    return $?
}

# Run a tool with timeout
# Args: $1 = timeout (seconds), $2 = tool name, $3+ = arguments
# Returns: tool's exit code or 124 on timeout
run_tool_timeout() {
    local timeout_sec="$1"
    local tool="$2"
    shift 2

    if ! command -v timeout &>/dev/null; then
        log_warning "timeout command not available, running without timeout"
        run_tool "$tool" "$@"
        return $?
    fi

    log_command_preview "timeout $timeout_sec $tool $*"
    timeout "$timeout_sec" "$tool" "$@"
    local exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        log_warning "$tool timed out after ${timeout_sec}s"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# SAFE FILE OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Dangerous paths that should never be removed
declare -ga _PROTECTED_PATHS=(
    "/"
    "/bin"
    "/boot"
    "/dev"
    "/etc"
    "/home"
    "/lib"
    "/lib64"
    "/opt"
    "/proc"
    "/root"
    "/run"
    "/sbin"
    "/srv"
    "/sys"
    "/tmp"
    "/usr"
    "/var"
    "$HOME"
)

# Check if a path is protected
# Args: $1 = path
# Returns: 0 if protected (should NOT remove), 1 if safe
_is_protected_path() {
    local path="$1"

    # Normalize path (resolve symlinks, remove trailing slashes)
    local normalized
    normalized=$(realpath -s "$path" 2>/dev/null || echo "$path")
    normalized="${normalized%/}"

    # Empty path is dangerous
    [[ -z "$normalized" ]] && return 0

    # Check against protected paths
    for protected in "${_PROTECTED_PATHS[@]}"; do
        local norm_protected
        norm_protected=$(realpath -s "$protected" 2>/dev/null || echo "$protected")
        norm_protected="${norm_protected%/}"

        # Exact match
        [[ "$normalized" == "$norm_protected" ]] && return 0

        # Path is parent of protected path
        [[ "$norm_protected" == "$normalized"/* ]] && return 0
    done

    return 1
}

# safe_rm() - Safe file/directory removal with protection
# Args: $1 = path to remove, $2 = force flag (optional, "force" to skip confirmation)
# Returns: 0 on success, 1 on failure or blocked
safe_rm() {
    local path="$1"
    local force="${2:-}"

    # Validate input
    if [[ -z "$path" ]]; then
        log_error "safe_rm: No path specified"
        return 1
    fi

    # Check if path exists
    if [[ ! -e "$path" ]]; then
        log_debug "safe_rm: Path does not exist: $path"
        return 0  # Not an error - already gone
    fi

    # Check protected paths
    if _is_protected_path "$path"; then
        log_error "safe_rm: BLOCKED - Cannot remove protected path: $path"
        log_audit "SAFE_RM" "$path" "blocked_protected"
        return 1
    fi

    # Check if removing directory with contents
    if [[ -d "$path" ]] && [[ "$(ls -A "$path" 2>/dev/null)" ]]; then
        if [[ "$force" != "force" ]]; then
            log_warning "safe_rm: Directory not empty: $path"
            log_info "Use safe_rm \"$path\" force to remove recursively"
            return 1
        fi
    fi

    # Respect dry-run mode
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} rm -rf $path" >&2
        return 0
    fi

    # Perform removal
    log_debug "safe_rm: Removing $path"
    log_audit "SAFE_RM" "$path" "started"

    if rm -rf "$path" 2>/dev/null; then
        log_audit "SAFE_RM" "$path" "success"
        return 0
    else
        log_error "safe_rm: Failed to remove: $path"
        log_audit "SAFE_RM" "$path" "failed"
        return 1
    fi
}

# safe_mkdir() - Safe directory creation with logging
# Args: $1 = directory path, $2 = mode (optional, default: 755)
# Returns: 0 on success, 1 on failure
safe_mkdir() {
    local path="$1"
    local mode="${2:-755}"

    # Validate input
    if [[ -z "$path" ]]; then
        log_error "safe_mkdir: No path specified"
        return 1
    fi

    # Already exists
    if [[ -d "$path" ]]; then
        log_debug "safe_mkdir: Directory already exists: $path"
        return 0
    fi

    # Check if path exists but is not a directory
    if [[ -e "$path" ]]; then
        log_error "safe_mkdir: Path exists but is not a directory: $path"
        return 1
    fi

    # Respect dry-run mode
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} mkdir -p -m $mode $path" >&2
        return 0
    fi

    # Create directory
    log_debug "safe_mkdir: Creating $path (mode: $mode)"
    log_audit "SAFE_MKDIR" "$path" "started"

    if mkdir -p -m "$mode" "$path" 2>/dev/null; then
        log_audit "SAFE_MKDIR" "$path" "success"
        return 0
    else
        log_error "safe_mkdir: Failed to create: $path"
        log_audit "SAFE_MKDIR" "$path" "failed"
        return 1
    fi
}

# safe_copy() - Safe file copy with validation
# Signature: safe_copy [flags...] <source> <destination>
# Flags are passed through to cp; source and destination are the last two arguments.
# Recognizes -r, -R, --recursive for directory copies.
# Returns: 0 on success, 1 on failure
#
# Examples:
#   safe_copy file.txt /tmp/file.txt
#   safe_copy -r /path/to/dir /tmp/backup
#   safe_copy --recursive -p /src /dest
safe_copy() {
    local -a cp_args=()
    local source=""
    local dest=""
    local has_recursive=false

    # Need at least 2 arguments (source and dest)
    if [[ $# -lt 2 ]]; then
        log_error "safe_copy: Requires at least source and destination"
        return 1
    fi

    # Collect all arguments into array
    local -a all_args=("$@")
    local num_args=${#all_args[@]}

    # Last two arguments are source and destination
    source="${all_args[$((num_args-2))]}"
    dest="${all_args[$((num_args-1))]}"

    # Everything before that is flags
    local i
    for ((i=0; i<num_args-2; i++)); do
        local arg="${all_args[$i]}"
        cp_args+=("$arg")

        # Check for recursive flags
        case "$arg" in
            -r|-R|--recursive)
                has_recursive=true
                ;;
            -*)
                # Check for combined flags like -rp, -Rp, etc.
                if [[ "$arg" =~ r|R ]]; then
                    has_recursive=true
                fi
                ;;
        esac
    done

    # Validate source
    if [[ -z "$source" ]]; then
        log_error "safe_copy: No source specified"
        return 1
    fi

    # Validate destination
    if [[ -z "$dest" ]]; then
        log_error "safe_copy: No destination specified"
        return 1
    fi

    # Check source exists
    if [[ ! -e "$source" ]]; then
        log_error "safe_copy: Source does not exist: $source"
        return 1
    fi

    # Check if source is directory but recursive flag not provided
    if [[ -d "$source" ]] && [[ "$has_recursive" != true ]]; then
        log_error "safe_copy: Source is a directory, use -r, -R, or --recursive flag"
        return 1
    fi

    # Warn if destination exists
    if [[ -e "$dest" ]]; then
        log_warning "safe_copy: Destination exists, will be overwritten: $dest"
    fi

    # Ensure destination directory exists
    local dest_dir
    if [[ -d "$dest" ]]; then
        dest_dir="$dest"
    else
        dest_dir=$(dirname "$dest")
    fi

    if [[ ! -d "$dest_dir" ]]; then
        safe_mkdir "$dest_dir" || return 1
    fi

    # Respect dry-run mode
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        if [[ ${#cp_args[@]} -gt 0 ]]; then
            echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} cp ${cp_args[*]} $source $dest" >&2
        else
            echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} cp $source $dest" >&2
        fi
        return 0
    fi

    # Perform copy with properly quoted arguments
    log_debug "safe_copy: $source -> $dest"
    log_audit "SAFE_COPY" "$source -> $dest" "started"

    local exit_code
    if [[ ${#cp_args[@]} -gt 0 ]]; then
        cp "${cp_args[@]}" "$source" "$dest" 2>/dev/null
        exit_code=$?
    else
        cp "$source" "$dest" 2>/dev/null
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_audit "SAFE_COPY" "$source -> $dest" "success"
        return 0
    else
        log_error "safe_copy: Failed to copy $source to $dest"
        log_audit "SAFE_COPY" "$source -> $dest" "failed"
        return 1
    fi
}

# safe_move() - Safe file move with validation
# Args: $1 = source, $2 = destination
# Returns: 0 on success, 1 on failure
safe_move() {
    local source="$1"
    local dest="$2"

    # Validate input
    if [[ -z "$source" ]]; then
        log_error "safe_move: No source specified"
        return 1
    fi

    if [[ -z "$dest" ]]; then
        log_error "safe_move: No destination specified"
        return 1
    fi

    # Check source exists
    if [[ ! -e "$source" ]]; then
        log_error "safe_move: Source does not exist: $source"
        return 1
    fi

    # Check protected paths (cannot move system files)
    if _is_protected_path "$source"; then
        log_error "safe_move: BLOCKED - Cannot move protected path: $source"
        log_audit "SAFE_MOVE" "$source" "blocked_protected"
        return 1
    fi

    # Warn if destination exists
    if [[ -e "$dest" ]]; then
        log_warning "safe_move: Destination exists, will be overwritten: $dest"
    fi

    # Ensure destination directory exists
    local dest_dir
    if [[ -d "$dest" ]]; then
        dest_dir="$dest"
    else
        dest_dir=$(dirname "$dest")
    fi

    if [[ ! -d "$dest_dir" ]]; then
        safe_mkdir "$dest_dir" || return 1
    fi

    # Respect dry-run mode
    if [[ "${VW_DRY_RUN:-0}" -eq 1 ]]; then
        echo -e "${C_YELLOW}[DRY-RUN]${C_RESET} mv $source $dest" >&2
        return 0
    fi

    # Perform move
    log_debug "safe_move: $source -> $dest"
    log_audit "SAFE_MOVE" "$source -> $dest" "started"

    if mv "$source" "$dest" 2>/dev/null; then
        log_audit "SAFE_MOVE" "$source -> $dest" "success"
        return 0
    else
        log_error "safe_move: Failed to move $source to $dest"
        log_audit "SAFE_MOVE" "$source -> $dest" "failed"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# MISC UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

# Check if string is numeric
# Args: $1 = string
# Returns: 0 if numeric, 1 if not
is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Generate random string
# Args: $1 = length (default: 16)
# Returns: random alphanumeric string
random_string() {
    local length="${1:-16}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Calculate elapsed time in human-readable format
# Args: $1 = start timestamp (epoch), $2 = end timestamp (optional, defaults to now)
# Returns: human-readable duration
elapsed_time() {
    local start="$1"
    local end="${2:-$(date +%s)}"
    local duration=$((end - start))

    if [[ $duration -lt 60 ]]; then
        echo "${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $((duration % 3600 / 60))m"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# WORDLIST MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Wordlist search paths
declare -ga WORDLIST_PATHS=(
    "/usr/share/wordlists"
    "/usr/share/seclists"
    "$HOME/wordlists"
)

# Known wordlists mapping
declare -gA KNOWN_WORDLISTS=(
    [rockyou]="/usr/share/wordlists/rockyou.txt"
    [common]="/usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
)

# check_wordlists() - Display status of known wordlists
# Returns: 0 always (status report), 1 if KNOWN_WORDLISTS is empty
check_wordlists() {
    log_info "Checking wordlists..."

    # Warn if no wordlists defined
    if [[ ${#KNOWN_WORDLISTS[@]} -eq 0 ]]; then
        log_warning "No known wordlists defined"
        return 1
    fi

    local name path
    for name in "${!KNOWN_WORDLISTS[@]}"; do
        path="${KNOWN_WORDLISTS[$name]}"

        if [[ -f "$path" ]]; then
            # File exists
            echo -e "    ${C_GREEN}✓${C_RESET} $name: $path"
        elif [[ -f "${path}.gz" ]]; then
            # Compressed version exists
            echo -e "    ${C_YELLOW}○${C_RESET} $name: ${path}.gz ${C_SHADOW}(compressed)${C_RESET}"
        else
            # Not found
            echo -e "    ${C_RED}✗${C_RESET} $name: NOT FOUND"
        fi
    done

    return 0
}

# ensure_rockyou() - Ensure rockyou.txt is available
# Outputs: path to rockyou.txt on success
# Returns: 0 on success, 1 on failure
# Note: Respects WORDLIST_BASE env var for testing/custom paths
ensure_rockyou() {
    local base="${WORDLIST_BASE:-/usr/share/wordlists}"
    local rockyou="$base/rockyou.txt"
    local rockyou_gz="${rockyou}.gz"

    [[ -f "$rockyou" ]] && { echo "$rockyou"; return 0; }

    if [[ -f "$rockyou_gz" ]]; then
        log_info "Decompressing rockyou.txt.gz..."

        # If we can write here, don't sudo (so tests can mock cleanly)
        if [[ -w "$base" ]]; then
            gunzip -kf "$rockyou_gz" && { echo "$rockyou"; return 0; }
        else
            run_with_sudo gunzip -kf "$rockyou_gz" && { echo "$rockyou"; return 0; }
        fi
    fi

    log_warning "rockyou.txt not found"

    # Non-interactive must never prompt/install
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]]; then
        return 1
    fi

    if confirm "Install wordlists?" && run_with_sudo apt install -y wordlists; then
        ensure_rockyou
        return $?
    fi
    return 1
}

# require_wordlist() - Validate and return wordlist path
# Args: $1 = wordlist path (optional, defaults to rockyou)
# Outputs: validated wordlist path
# Returns: 0 on success, 1 on failure
require_wordlist() {
    local path="$1"

    # Default to rockyou if not specified
    if [[ -z "$path" ]]; then
        path=$(ensure_rockyou) || return 1
    fi

    # Validate: file exists
    if [[ ! -f "$path" ]]; then
        log_error "Wordlist not found: $path"
        return 1
    fi

    # Validate: readable
    if [[ ! -r "$path" ]]; then
        log_error "Wordlist not readable: $path"
        return 1
    fi

    # Validate: non-empty
    if [[ ! -s "$path" ]]; then
        log_error "Wordlist is empty: $path"
        return 1
    fi

    echo "$path"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Timestamps
export -f timestamp timestamp_filename timestamp_date timestamp_iso

# Backups
export -f backup_file backup_file_to

# Cleanup (temp file cleanup only - main registry is in core.sh)
export -f _utils_cleanup_temp

# Filename generation
export -f generate_report_name generate_target_filename

# Validation
export -f validate_ip validate_cidr validate_hostname validate_port validate_port_spec

# Tool execution
export -f run_tool run_tool_silent run_tool_timeout

# Safe file operations
export -f safe_rm safe_mkdir safe_copy safe_move

# Misc
export -f is_numeric random_string elapsed_time

# Wordlist management
export -f check_wordlists ensure_rockyou require_wordlist
