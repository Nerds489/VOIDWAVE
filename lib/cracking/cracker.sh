#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Password Cracking: Hashcat, John, wordlist management, GPU detection
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_CRACKER_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_CRACKER_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"

#═══════════════════════════════════════════════════════════════════════════════
# CRACKING CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Setup voidwave directories
crack_setup_dirs() {
    local voidwave_dir="$HOME/.voidwave"
    local wordlist_dir="$voidwave_dir/wordlists"
    local rules_dir="$voidwave_dir/rules"

    mkdir -p "$wordlist_dir" "$rules_dir" 2>/dev/null
}

# Find wordlist directory
crack_find_wordlist_dir() {
    local locations=(
        "$HOME/.voidwave/wordlists"
        "/usr/share/wordlists"
        "/usr/share/seclists/Passwords"
        "/opt/wordlists"
        "/usr/local/share/wordlists"
        "$HOME/wordlists"
    )

    for loc in "${locations[@]}"; do
        if [[ -d "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done

    # Fallback to default
    echo "/usr/share/wordlists"
    return 1
}

# Find rules directory
crack_find_rules_dir() {
    local locations=(
        "$HOME/.voidwave/rules"
        "/usr/share/hashcat/rules"
        "/usr/local/share/hashcat/rules"
        "/opt/hashcat/rules"
        "$HOME/hashcat/rules"
    )

    for loc in "${locations[@]}"; do
        if [[ -d "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done

    # Fallback to default
    echo "/usr/share/hashcat/rules"
    return 1
}

# Setup directories on load
crack_setup_dirs

# Tool preferences
declare -g CRACK_PREFERRED_TOOL="${CRACK_PREFERRED_TOOL:-auto}"  # auto, hashcat, john, aircrack
declare -g CRACK_USE_GPU="${CRACK_USE_GPU:-true}"
declare -g CRACK_WORKLOAD="${CRACK_WORKLOAD:-3}"  # hashcat workload 1-4

# Wordlists
declare -g CRACK_WORDLIST_DIR="${CRACK_WORDLIST_DIR:-$(crack_find_wordlist_dir)}"
declare -g CRACK_DEFAULT_WORDLIST="${CRACK_DEFAULT_WORDLIST:-rockyou.txt}"

# Rules
declare -g CRACK_RULES_DIR="${CRACK_RULES_DIR:-$(crack_find_rules_dir)}"
declare -g CRACK_DEFAULT_RULES="${CRACK_DEFAULT_RULES:-best64.rule}"

# Process tracking
declare -g _CRACK_PID=""
declare -g _CRACK_TOOL=""

# Hash modes
declare -gA CRACK_HASH_MODES=(
    [wpa]="22000"
    [wpa_pmkid]="22000"
    [wpa_hccapx]="2500"
    [wep]="n/a"  # WEP uses aircrack-ng
    [mschap]="5500"
    [mschapv2]="5600"
    [md5]="0"
    [sha1]="100"
    [ntlm]="1000"
)

#═══════════════════════════════════════════════════════════════════════════════
# GPU DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Detect available GPUs
crack_detect_gpu() {
    local gpus=()

    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        local nvidia_gpus
        nvidia_gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
        while IFS= read -r gpu; do
            [[ -n "$gpu" ]] && gpus+=("NVIDIA: $gpu")
        done <<< "$nvidia_gpus"
    fi

    # AMD
    if command -v rocm-smi &>/dev/null; then
        local amd_gpus
        amd_gpus=$(rocm-smi --showproductname 2>/dev/null | grep -i "card" | awk '{print $NF}')
        while IFS= read -r gpu; do
            [[ -n "$gpu" ]] && gpus+=("AMD: $gpu")
        done <<< "$amd_gpus"
    fi

    # Intel
    if [[ -d /sys/class/drm ]]; then
        for card in /sys/class/drm/card*/device/vendor; do
            if [[ -f "$card" ]] && grep -q "0x8086" "$card"; then
                gpus+=("Intel: Integrated GPU")
                break
            fi
        done
    fi

    if [[ ${#gpus[@]} -eq 0 ]]; then
        log_warning "No GPU detected - using CPU only"
        echo "none"
        return 1
    fi

    printf '%s\n' "${gpus[@]}"
    return 0
}

# Get hashcat device options
crack_get_device_opts() {
    local opts=""

    if [[ "$CRACK_USE_GPU" == "true" ]]; then
        # Auto-detect best device
        if nvidia-smi &>/dev/null; then
            opts="-D 1,2"  # CUDA + OpenCL
        elif rocm-smi &>/dev/null; then
            opts="-D 2"    # OpenCL
        else
            opts="-D 1"    # CPU
        fi
    else
        opts="-D 1"  # CPU only
    fi

    echo "$opts"
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Get best available cracking tool
crack_get_tool() {
    case "$CRACK_PREFERRED_TOOL" in
        hashcat)
            command -v hashcat &>/dev/null && echo "hashcat" && return 0
            ;;
        john)
            command -v john &>/dev/null && echo "john" && return 0
            ;;
        aircrack)
            command -v aircrack-ng &>/dev/null && echo "aircrack" && return 0
            ;;
        auto|*)
            # Prefer hashcat for GPU support
            if [[ "$CRACK_USE_GPU" == "true" ]] && command -v hashcat &>/dev/null; then
                echo "hashcat"
                return 0
            elif command -v john &>/dev/null; then
                echo "john"
                return 0
            elif command -v aircrack-ng &>/dev/null; then
                echo "aircrack"
                return 0
            fi
            ;;
    esac

    log_error "No cracking tool found"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# WORDLIST MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Find wordlist
# Args: $1 = wordlist name or path
crack_find_wordlist() {
    local wordlist="$1"

    # Check if full path
    [[ -f "$wordlist" ]] && echo "$wordlist" && return 0

    # Check common locations
    local locations=(
        "$CRACK_WORDLIST_DIR"
        "/usr/share/wordlists"
        "/usr/share/seclists/Passwords"
        "/opt/wordlists"
        "$HOME/.voidwave/wordlists"
    )

    for loc in "${locations[@]}"; do
        if [[ -f "$loc/$wordlist" ]]; then
            echo "$loc/$wordlist"
            return 0
        fi

        # Check for compressed versions
        for ext in gz xz bz2; do
            if [[ -f "$loc/${wordlist}.${ext}" ]]; then
                echo "$loc/${wordlist}.${ext}"
                return 0
            fi
        done
    done

    # Check for rockyou specifically
    if [[ "$wordlist" == "rockyou.txt" ]]; then
        for loc in "${locations[@]}"; do
            if [[ -f "$loc/rockyou.txt.gz" ]]; then
                log_info "Decompressing rockyou.txt.gz..."
                gunzip -k "$loc/rockyou.txt.gz" 2>/dev/null
                echo "$loc/rockyou.txt"
                return 0
            fi
        done
    fi

    log_error "Wordlist not found: $wordlist"
    return 1
}

# List available wordlists
crack_list_wordlists() {
    echo ""
    echo -e "    ${C_CYAN}Available Wordlists${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..50})${C_RESET}"

    local locations=(
        "$CRACK_WORDLIST_DIR"
        "/usr/share/wordlists"
        "/usr/share/seclists/Passwords"
    )

    for loc in "${locations[@]}"; do
        [[ ! -d "$loc" ]] && continue

        echo -e "    ${C_WHITE}$loc:${C_RESET}"

        find "$loc" -maxdepth 2 -type f \( -name "*.txt" -o -name "*.txt.gz" \) 2>/dev/null | \
            head -20 | while read -r file; do
            local size
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            printf "      %-40s %s\n" "$(basename "$file")" "$size"
        done

        echo ""
    done
}

# Generate custom wordlist
# Args: $1 = output file, $2 = min length, $3 = max length, $4 = charset
crack_generate_wordlist() {
    local output="$1"
    local min_len="${2:-8}"
    local max_len="${3:-12}"
    local charset="${4:-lalpha}"

    if ! command -v crunch &>/dev/null; then
        log_error "crunch not found"
        return 1
    fi

    log_info "Generating wordlist: $output"
    log_info "Length: $min_len-$max_len, Charset: $charset"

    crunch "$min_len" "$max_len" -o "$output" -t "$charset" 2>/dev/null

    if [[ -f "$output" ]]; then
        local count
        count=$(wc -l < "$output")
        log_success "Generated $count words"
        return 0
    fi

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# HASHCAT CRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Crack with hashcat
# Args: $1 = hash file, $2 = hash type, $3 = wordlist, $4 = rules (optional)
crack_hashcat() {
    local hash_file="$1"
    local hash_type="$2"
    local wordlist="$3"
    local rules="${4:-}"

    if ! command -v hashcat &>/dev/null; then
        log_error "hashcat not found"
        return 1
    fi

    # Get hash mode
    local mode="${CRACK_HASH_MODES[$hash_type]:-$hash_type}"

    # Find wordlist
    local wl_path
    wl_path=$(crack_find_wordlist "$wordlist") || return 1

    log_info "Cracking with hashcat (mode: $mode)"
    log_info "Hash file: $hash_file"
    log_info "Wordlist: $wl_path"

    local cmd=(hashcat -m "$mode" -a 0)

    # Add device options
    cmd+=($(crack_get_device_opts))

    # Add workload
    cmd+=(-w "$CRACK_WORKLOAD")

    # Add rules if specified
    if [[ -n "$rules" ]]; then
        local rules_path="$CRACK_RULES_DIR/$rules"
        [[ -f "$rules_path" ]] && cmd+=(-r "$rules_path")
    fi

    cmd+=("$hash_file" "$wl_path")

    # Force for non-GPU systems
    cmd+=(--force)

    log_debug "Command: ${cmd[*]}"

    "${cmd[@]}"
    local result=$?

    # Check for cracked passwords
    if [[ $result -eq 0 ]]; then
        local cracked
        cracked=$(hashcat -m "$mode" "$hash_file" --show 2>/dev/null)

        if [[ -n "$cracked" ]]; then
            log_success "Password(s) cracked!"
            echo "$cracked"

            # Save to loot
            if declare -F wireless_loot_add_cracked &>/dev/null; then
                while IFS=':' read -r hash password; do
                    wireless_loot_add_cracked "" "" "$password" "hashcat"
                done <<< "$cracked"
            fi

            return 0
        fi
    fi

    log_warning "No passwords cracked"
    return 1
}

# Hashcat with multiple attack modes
# Args: $1 = hash file, $2 = hash type
crack_hashcat_smart() {
    local hash_file="$1"
    local hash_type="$2"

    local mode="${CRACK_HASH_MODES[$hash_type]:-$hash_type}"

    log_info "Starting smart hashcat attack"

    # Attack 1: Quick dictionary
    log_info "Phase 1: Quick dictionary attack"
    crack_hashcat "$hash_file" "$hash_type" "rockyou.txt" && return 0

    # Attack 2: Dictionary with rules
    log_info "Phase 2: Dictionary + rules"
    crack_hashcat "$hash_file" "$hash_type" "rockyou.txt" "best64.rule" && return 0

    # Attack 3: Combinator (if small enough)
    log_info "Phase 3: Common passwords with rules"
    if [[ -f "/usr/share/wordlists/fasttrack.txt" ]]; then
        crack_hashcat "$hash_file" "$hash_type" "fasttrack.txt" "dive.rule" && return 0
    fi

    log_warning "Smart attack did not crack password"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# JOHN THE RIPPER
#═══════════════════════════════════════════════════════════════════════════════

# Crack with John
# Args: $1 = hash file, $2 = format, $3 = wordlist (optional)
crack_john() {
    local hash_file="$1"
    local format="${2:-}"
    local wordlist="${3:-}"

    if ! command -v john &>/dev/null; then
        log_error "john not found"
        return 1
    fi

    log_info "Cracking with John the Ripper"

    local cmd=(john)

    [[ -n "$format" ]] && cmd+=(--format="$format")

    if [[ -n "$wordlist" ]]; then
        local wl_path
        wl_path=$(crack_find_wordlist "$wordlist") || return 1
        cmd+=(--wordlist="$wl_path")
    fi

    cmd+=("$hash_file")

    "${cmd[@]}"

    # Show cracked
    john --show "$hash_file" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# AIRCRACK-NG (WPA/WEP)
#═══════════════════════════════════════════════════════════════════════════════

# Crack WPA with aircrack-ng
# Args: $1 = capture file, $2 = wordlist, $3 = BSSID (optional)
crack_aircrack_wpa() {
    local cap_file="$1"
    local wordlist="$2"
    local bssid="${3:-}"

    if ! command -v aircrack-ng &>/dev/null; then
        log_error "aircrack-ng not found"
        return 1
    fi

    local wl_path
    wl_path=$(crack_find_wordlist "$wordlist") || return 1

    log_info "Cracking WPA with aircrack-ng"
    log_info "Capture: $cap_file"
    log_info "Wordlist: $wl_path"

    local cmd=(aircrack-ng -w "$wl_path")
    [[ -n "$bssid" ]] && cmd+=(-b "$bssid")
    cmd+=("$cap_file")

    local result
    result=$("${cmd[@]}" 2>&1)

    if echo "$result" | grep -q "KEY FOUND"; then
        local key
        key=$(echo "$result" | sed -n 's/.*KEY FOUND! \[[[:space:]]*\([^]]*\).*/\1/p')
        log_success "Password cracked: $key"

        # Save to loot
        if declare -F wireless_loot_add_cracked &>/dev/null; then
            wireless_loot_add_cracked "$bssid" "" "$key" "aircrack"
        fi

        return 0
    fi

    log_warning "Password not found in wordlist"
    return 1
}

# Crack WEP with aircrack-ng
# Args: $1 = capture file, $2 = BSSID (optional)
crack_aircrack_wep() {
    local cap_file="$1"
    local bssid="${2:-}"

    if ! command -v aircrack-ng &>/dev/null; then
        log_error "aircrack-ng not found"
        return 1
    fi

    log_info "Cracking WEP with aircrack-ng"

    local cmd=(aircrack-ng)
    [[ -n "$bssid" ]] && cmd+=(-b "$bssid")
    cmd+=("$cap_file")

    local result
    result=$("${cmd[@]}" 2>&1)

    if echo "$result" | grep -q "KEY FOUND"; then
        local key
        key=$(echo "$result" | sed -n 's/.*KEY FOUND! \[[[:space:]]*\([^]]*\).*/\1/p')
        log_success "WEP Key: $key"
        return 0
    fi

    log_warning "Need more IVs to crack WEP"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# UNIFIED CRACKING INTERFACE
#═══════════════════════════════════════════════════════════════════════════════

# Auto-detect and crack
# Args: $1 = hash/capture file, $2 = wordlist (optional)
crack_auto() {
    local file="$1"
    local wordlist="${2:-$CRACK_DEFAULT_WORDLIST}"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    # Detect file type
    local file_type=""

    case "$file" in
        *.cap|*.pcap)
            file_type="wpa_cap"
            ;;
        *.hccapx)
            file_type="wpa_hccapx"
            ;;
        *.22000|*.hc22000)
            file_type="wpa_pmkid"
            ;;
        *.ivs)
            file_type="wep"
            ;;
        *.5500|*.netntlm)
            file_type="mschap"
            ;;
        *)
            # Try to detect from content
            if file "$file" | grep -qi "pcap"; then
                file_type="wpa_cap"
            elif head -1 "$file" | grep -qE "^WPA\*"; then
                file_type="wpa_pmkid"
            fi
            ;;
    esac

    log_info "Detected file type: $file_type"

    case "$file_type" in
        wpa_cap)
            # Convert to hashcat format first if hashcat available
            if command -v hashcat &>/dev/null && command -v hcxpcapngtool &>/dev/null; then
                local hash_file="${file%.cap}.22000"
                hcxpcapngtool -o "$hash_file" "$file" &>/dev/null
                crack_hashcat "$hash_file" "wpa" "$wordlist"
            else
                crack_aircrack_wpa "$file" "$wordlist"
            fi
            ;;

        wpa_hccapx)
            crack_hashcat "$file" "2500" "$wordlist"
            ;;

        wpa_pmkid)
            crack_hashcat "$file" "wpa" "$wordlist"
            ;;

        wep)
            crack_aircrack_wep "$file"
            ;;

        mschap)
            crack_hashcat "$file" "mschap" "$wordlist"
            ;;

        *)
            log_error "Unknown file type - please specify manually"
            return 1
            ;;
    esac
}

#═══════════════════════════════════════════════════════════════════════════════
# BATCH CRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Crack all captures in directory
# Args: $1 = directory, $2 = wordlist
crack_batch() {
    local dir="$1"
    local wordlist="${2:-$CRACK_DEFAULT_WORDLIST}"

    if [[ ! -d "$dir" ]]; then
        log_error "Directory not found: $dir"
        return 1
    fi

    log_info "Batch cracking all captures in: $dir"

    local success=0
    local total=0

    shopt -s nullglob
    for file in "$dir"/*.cap "$dir"/*.pcap "$dir"/*.22000 "$dir"/*.hccapx "$dir"/*.ivs; do
        [[ ! -f "$file" ]] && continue
        ((total++)) || true

        log_info "Processing: $(basename "$file")"

        if crack_auto "$file" "$wordlist"; then
            ((success++)) || true
        fi
    done
    shopt -u nullglob

    log_info "Batch complete: $success/$total cracked"
}

#═══════════════════════════════════════════════════════════════════════════════
# STATUS AND CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Show cracking status
crack_status() {
    echo ""
    echo -e "    ${C_CYAN}Cracking Configuration${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    echo -e "    Preferred tool: ${C_WHITE}$CRACK_PREFERRED_TOOL${C_RESET}"
    echo -e "    Use GPU:        ${C_WHITE}$CRACK_USE_GPU${C_RESET}"

    # Show available tools
    echo ""
    echo -e "    ${C_YELLOW}Available Tools:${C_RESET}"
    command -v hashcat &>/dev/null && echo "      - hashcat $(hashcat --version 2>/dev/null)"
    command -v john &>/dev/null && echo "      - john $(john --version 2>/dev/null | head -1)"
    command -v aircrack-ng &>/dev/null && echo "      - aircrack-ng $(aircrack-ng --version 2>/dev/null | head -1)"

    # Show GPUs
    echo ""
    echo -e "    ${C_YELLOW}GPU Status:${C_RESET}"
    crack_detect_gpu | while read -r gpu; do
        echo "      - $gpu"
    done

    echo ""
}

# Stop running crack
crack_stop() {
    if [[ -n "$_CRACK_PID" ]]; then
        kill "$_CRACK_PID" 2>/dev/null
        wait "$_CRACK_PID" 2>/dev/null
        _CRACK_PID=""
        log_info "Cracking stopped"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

crack_cleanup() {
    crack_stop
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup crack_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f crack_setup_dirs crack_find_wordlist_dir crack_find_rules_dir
export -f crack_detect_gpu crack_get_device_opts crack_get_tool
export -f crack_find_wordlist crack_list_wordlists crack_generate_wordlist
export -f crack_hashcat crack_hashcat_smart
export -f crack_john
export -f crack_aircrack_wpa crack_aircrack_wep
export -f crack_auto crack_batch
export -f crack_status crack_stop crack_cleanup
