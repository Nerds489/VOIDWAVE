#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Loot: capture file management, credentials, organized output
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_LOOT_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_LOOT_LOADED=1

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# LOOT DIRECTORY STRUCTURE
#═══════════════════════════════════════════════════════════════════════════════

# Base wireless loot directory
declare -g WIRELESS_LOOT_DIR="${LOOT_DIR:-$HOME/.voidwave/loot}/wireless"

# Subdirectories
declare -g WIRELESS_LOOT_HANDSHAKES="${WIRELESS_LOOT_DIR}/handshakes"
declare -g WIRELESS_LOOT_PMKIDS="${WIRELESS_LOOT_DIR}/pmkids"
declare -g WIRELESS_LOOT_WPS="${WIRELESS_LOOT_DIR}/wps"
declare -g WIRELESS_LOOT_CREDENTIALS="${WIRELESS_LOOT_DIR}/credentials"
declare -g WIRELESS_LOOT_ENTERPRISE="${WIRELESS_LOOT_DIR}/enterprise"
declare -g WIRELESS_LOOT_PORTALS="${WIRELESS_LOOT_DIR}/portals"
declare -g WIRELESS_LOOT_CAPTURES="${WIRELESS_LOOT_DIR}/captures"
declare -g WIRELESS_LOOT_SCANS="${WIRELESS_LOOT_DIR}/scans"

#═══════════════════════════════════════════════════════════════════════════════
# DIRECTORY INITIALIZATION
#═══════════════════════════════════════════════════════════════════════════════

# Initialize loot directory structure
wireless_loot_init() {
    local dirs=(
        "$WIRELESS_LOOT_DIR"
        "$WIRELESS_LOOT_HANDSHAKES"
        "$WIRELESS_LOOT_PMKIDS"
        "$WIRELESS_LOOT_WPS"
        "$WIRELESS_LOOT_CREDENTIALS"
        "$WIRELESS_LOOT_ENTERPRISE"
        "$WIRELESS_LOOT_PORTALS"
        "$WIRELESS_LOOT_CAPTURES"
        "$WIRELESS_LOOT_SCANS"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null
            chmod 700 "$dir" 2>/dev/null
        fi
    done

    # Create credentials database if not exists
    if [[ ! -f "${WIRELESS_LOOT_CREDENTIALS}/cracked.txt" ]]; then
        cat > "${WIRELESS_LOOT_CREDENTIALS}/cracked.txt" << 'EOF'
# VOIDWAVE Cracked Credentials Database
# Format: ESSID:BSSID:PASSWORD:METHOD:DATE
# ═══════════════════════════════════════════════════════════════════════════════
EOF
        chmod 600 "${WIRELESS_LOOT_CREDENTIALS}/cracked.txt" 2>/dev/null
    fi

    log_debug "Wireless loot directories initialized"
}

#═══════════════════════════════════════════════════════════════════════════════
# FILE NAMING
#═══════════════════════════════════════════════════════════════════════════════

# Sanitize ESSID for filename
# Args: $1 = ESSID
# Returns: sanitized name
_loot_sanitize_name() {
    local name="$1"
    # Remove or replace unsafe characters
    name="${name//[\/\\:*?\"<>|]/_}"
    # Trim whitespace
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    # Limit length
    echo "${name:0:32}"
}

# Generate standardized filename
# Args: $1 = essid, $2 = bssid, $3 = type (cap, hc22000, etc)
# Returns: filename (without path)
wireless_loot_filename() {
    local essid="$1"
    local bssid="$2"
    local type="${3:-cap}"
    local timestamp

    timestamp=$(date +%Y%m%d_%H%M%S)
    essid=$(_loot_sanitize_name "$essid")
    bssid="${bssid//:/-}"

    if [[ -n "$essid" ]]; then
        echo "${essid}_${bssid}_${timestamp}.${type}"
    else
        echo "unknown_${bssid}_${timestamp}.${type}"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Save handshake capture
# Args: $1 = source capture file, $2 = essid, $3 = bssid
# Returns: 0 on success, path to saved file
wireless_loot_save_handshake() {
    local src_file="$1"
    local essid="$2"
    local bssid="$3"

    if [[ ! -f "$src_file" ]]; then
        log_error "Source file not found: $src_file"
        return 1
    fi

    wireless_loot_init

    local filename
    filename=$(wireless_loot_filename "$essid" "$bssid" "cap")
    local dest_file="${WIRELESS_LOOT_HANDSHAKES}/${filename}"

    if cp "$src_file" "$dest_file"; then
        chmod 600 "$dest_file" 2>/dev/null
        log_success "Handshake saved: $dest_file"
        log_audit "LOOT" "handshake" "essid=$essid bssid=$bssid file=$dest_file"
        echo "$dest_file"
        return 0
    else
        log_error "Failed to save handshake"
        return 1
    fi
}

# Convert handshake to hashcat format and save
# Args: $1 = capture file
# Returns: path to hash file
wireless_loot_convert_handshake() {
    local cap_file="$1"

    if [[ ! -f "$cap_file" ]]; then
        log_error "Capture file not found: $cap_file"
        return 1
    fi

    # Determine output path
    local base_name
    base_name=$(basename "${cap_file%.*}")
    local hash_file="${WIRELESS_LOOT_HANDSHAKES}/${base_name}.hc22000"

    # Try hcxpcapngtool first (modern)
    if command -v hcxpcapngtool &>/dev/null; then
        if hcxpcapngtool -o "$hash_file" "$cap_file" 2>/dev/null; then
            if [[ -s "$hash_file" ]]; then
                log_success "Hash extracted: $hash_file"
                echo "$hash_file"
                return 0
            fi
        fi
    fi

    # Fallback to cap2hccapx (legacy)
    if command -v cap2hccapx &>/dev/null; then
        local legacy_file="${WIRELESS_LOOT_HANDSHAKES}/${base_name}.hccapx"
        if cap2hccapx "$cap_file" "$legacy_file" 2>/dev/null; then
            if [[ -s "$legacy_file" ]]; then
                log_success "Hash extracted (legacy): $legacy_file"
                echo "$legacy_file"
                return 0
            fi
        fi
    fi

    log_error "Failed to convert handshake"
    return 1
}

# List saved handshakes
wireless_loot_list_handshakes() {
    wireless_loot_init

    echo ""
    echo -e "    ${C_CYAN}Saved Handshakes${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..60})${C_RESET}"

    local count=0
    while IFS= read -r -d '' file; do
        local filename size
        filename=$(basename "$file")
        size=$(du -h "$file" 2>/dev/null | cut -f1)
        printf "    ${C_GREEN}%-45s${C_RESET} ${C_SHADOW}%s${C_RESET}\n" "$filename" "$size"
        ((count++)) || true
    done < <(find "$WIRELESS_LOOT_HANDSHAKES" -maxdepth 1 -type f \( -name "*.cap" -o -name "*.hc22000" -o -name "*.hccapx" \) -print0 2>/dev/null | sort -z)

    if [[ $count -eq 0 ]]; then
        echo -e "    ${C_SHADOW}No handshakes saved${C_RESET}"
    else
        echo ""
        echo -e "    ${C_SHADOW}Total: $count file(s)${C_RESET}"
    fi

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# PMKID MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Save PMKID hash
# Args: $1 = source file or hash string, $2 = essid, $3 = bssid
wireless_loot_save_pmkid() {
    local src="$1"
    local essid="$2"
    local bssid="$3"

    wireless_loot_init

    local filename
    filename=$(wireless_loot_filename "$essid" "$bssid" "22000")
    local dest_file="${WIRELESS_LOOT_PMKIDS}/${filename}"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest_file"
    else
        # Assume it's a hash string
        echo "$src" > "$dest_file"
    fi

    chmod 600 "$dest_file" 2>/dev/null
    log_success "PMKID saved: $dest_file"
    log_audit "LOOT" "pmkid" "essid=$essid bssid=$bssid"
    echo "$dest_file"
}

# List saved PMKIDs
wireless_loot_list_pmkids() {
    wireless_loot_init

    echo ""
    echo -e "    ${C_CYAN}Saved PMKIDs${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..60})${C_RESET}"

    local count=0
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")
        printf "    ${C_GREEN}%s${C_RESET}\n" "$filename"
        ((count++)) || true
    done < <(find "$WIRELESS_LOOT_PMKIDS" -maxdepth 1 -type f -name "*.22000" -print0 2>/dev/null | sort -z)

    if [[ $count -eq 0 ]]; then
        echo -e "    ${C_SHADOW}No PMKIDs saved${C_RESET}"
    else
        echo ""
        echo -e "    ${C_SHADOW}Total: $count file(s)${C_RESET}"
    fi

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# WPS PIN MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Save WPS PIN
# Args: $1 = essid, $2 = bssid, $3 = pin, $4 = psk (optional)
wireless_loot_save_wps() {
    local essid="$1"
    local bssid="$2"
    local pin="$3"
    local psk="${4:-}"

    wireless_loot_init

    local filename
    filename=$(_loot_sanitize_name "$essid")
    local dest_file="${WIRELESS_LOOT_WPS}/${filename}_${bssid//:/-}_wps.txt"

    {
        echo "# WPS Credentials"
        echo "# Captured: $(date -Iseconds)"
        echo "ESSID: $essid"
        echo "BSSID: $bssid"
        echo "PIN: $pin"
        [[ -n "$psk" ]] && echo "PSK: $psk"
    } > "$dest_file"

    chmod 600 "$dest_file" 2>/dev/null
    log_success "WPS PIN saved: $dest_file"
    log_audit "LOOT" "wps_pin" "essid=$essid bssid=$bssid pin=$pin"

    # Also add to cracked credentials if PSK available
    if [[ -n "$psk" ]]; then
        wireless_loot_add_cracked "$essid" "$bssid" "$psk" "WPS"
    fi

    echo "$dest_file"
}

#═══════════════════════════════════════════════════════════════════════════════
# CRACKED CREDENTIALS
#═══════════════════════════════════════════════════════════════════════════════

# Add cracked password to database
# Args: $1 = essid, $2 = bssid, $3 = password, $4 = method
wireless_loot_add_cracked() {
    local essid="$1"
    local bssid="$2"
    local password="$3"
    local method="${4:-unknown}"
    local timestamp

    wireless_loot_init

    timestamp=$(date -Iseconds)
    local db_file="${WIRELESS_LOOT_CREDENTIALS}/cracked.txt"

    # Check for duplicate
    if grep -qF "$bssid" "$db_file" 2>/dev/null; then
        log_warning "Credentials for $bssid already exist"
        return 0
    fi

    echo "${essid}:${bssid}:${password}:${method}:${timestamp}" >> "$db_file"
    log_success "Cracked password saved for $essid"
    log_audit "LOOT" "cracked" "essid=$essid bssid=$bssid method=$method"
}

# Show cracked passwords
wireless_loot_show_cracked() {
    wireless_loot_init

    local db_file="${WIRELESS_LOOT_CREDENTIALS}/cracked.txt"

    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}                   ${C_BOLD}CRACKED PASSWORDS${C_RESET}                              ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    local count=0
    while IFS=':' read -r essid bssid password method date; do
        # Skip comments and empty lines
        [[ "$essid" =~ ^# ]] && continue
        [[ -z "$essid" ]] && continue

        printf "    ${C_GREEN}%-20s${C_RESET} ${C_SHADOW}%-17s${C_RESET}\n" "$essid" "$bssid"
        printf "    ${C_BOLD}Password:${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "$password"
        printf "    ${C_SHADOW}Method: %-10s Date: %s${C_RESET}\n" "$method" "${date:0:10}"
        echo ""
        ((count++)) || true
    done < "$db_file"

    if [[ $count -eq 0 ]]; then
        echo -e "    ${C_SHADOW}No cracked passwords yet${C_RESET}"
    else
        echo -e "    ${C_SHADOW}Total: $count password(s)${C_RESET}"
    fi

    echo ""
}

# Search cracked passwords
# Args: $1 = search term (essid or bssid)
wireless_loot_search_cracked() {
    local search="$1"
    local db_file="${WIRELESS_LOOT_CREDENTIALS}/cracked.txt"

    grep -i "$search" "$db_file" 2>/dev/null | while IFS=':' read -r essid bssid password method date; do
        echo "ESSID: $essid"
        echo "BSSID: $bssid"
        echo "Password: $password"
        echo "Method: $method"
        echo "Date: $date"
        echo ""
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# PORTAL CREDENTIALS
#═══════════════════════════════════════════════════════════════════════════════

# Save portal-captured credentials
# Args: $1 = essid, $2 = username/input, $3 = password, $4 = client_ip
wireless_loot_save_portal_creds() {
    local essid="$1"
    local input="$2"
    local password="$3"
    local client_ip="${4:-unknown}"

    wireless_loot_init

    local filename
    filename=$(_loot_sanitize_name "$essid")
    local dest_file="${WIRELESS_LOOT_PORTALS}/${filename}_$(date +%Y%m%d).log"

    {
        echo "# ═══════════════════════════════════════════════════════════════"
        echo "# Timestamp: $(date -Iseconds)"
        echo "# Client IP: $client_ip"
        echo "# ═══════════════════════════════════════════════════════════════"
        echo "ESSID: $essid"
        echo "Input: $input"
        echo "Password: $password"
        echo ""
    } >> "$dest_file"

    chmod 600 "$dest_file" 2>/dev/null
    log_success "Portal credentials captured"
    log_audit "LOOT" "portal_creds" "essid=$essid client=$client_ip"
}

#═══════════════════════════════════════════════════════════════════════════════
# LOOT SUMMARY
#═══════════════════════════════════════════════════════════════════════════════

# Show loot summary
wireless_loot_summary() {
    wireless_loot_init

    local handshakes pmkids wps_pins cracked portals
    handshakes=$(find "$WIRELESS_LOOT_HANDSHAKES" -type f 2>/dev/null | wc -l)
    pmkids=$(find "$WIRELESS_LOOT_PMKIDS" -type f 2>/dev/null | wc -l)
    wps_pins=$(find "$WIRELESS_LOOT_WPS" -type f 2>/dev/null | wc -l)
    cracked=$(grep -v "^#" "${WIRELESS_LOOT_CREDENTIALS}/cracked.txt" 2>/dev/null | grep -c . || echo 0)
    portals=$(find "$WIRELESS_LOOT_PORTALS" -type f 2>/dev/null | wc -l)

    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}                      ${C_BOLD}WIRELESS LOOT${C_RESET}                               ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    printf "    ${C_GHOST}%-20s${C_RESET} ${C_GREEN}%d${C_RESET} file(s)\n" "Handshakes:" "$handshakes"
    printf "    ${C_GHOST}%-20s${C_RESET} ${C_GREEN}%d${C_RESET} file(s)\n" "PMKIDs:" "$pmkids"
    printf "    ${C_GHOST}%-20s${C_RESET} ${C_GREEN}%d${C_RESET} file(s)\n" "WPS PINs:" "$wps_pins"
    printf "    ${C_GHOST}%-20s${C_RESET} ${C_YELLOW}%d${C_RESET} password(s)\n" "Cracked:" "$cracked"
    printf "    ${C_GHOST}%-20s${C_RESET} ${C_GREEN}%d${C_RESET} file(s)\n" "Portal Captures:" "$portals"
    echo ""
    echo -e "    ${C_SHADOW}Location: $WIRELESS_LOOT_DIR${C_RESET}"
    echo ""
}

# Export loot to single archive
# Args: $1 = output path (optional)
wireless_loot_export() {
    local output="${1:-$HOME/voidwave_loot_$(date +%Y%m%d_%H%M%S).tar.gz}"

    wireless_loot_init

    if tar -czf "$output" -C "$(dirname "$WIRELESS_LOOT_DIR")" "$(basename "$WIRELESS_LOOT_DIR")" 2>/dev/null; then
        log_success "Loot exported: $output"
        echo "$output"
        return 0
    else
        log_error "Failed to export loot"
        return 1
    fi
}

# Clean old loot files
# Args: $1 = days to keep (default 30)
wireless_loot_cleanup() {
    local days="${1:-30}"

    log_info "Cleaning loot older than $days days..."

    local count=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((count++)) || true
    done < <(find "$WIRELESS_LOOT_DIR" -type f -mtime "+$days" -print0 2>/dev/null)

    log_success "Cleaned $count old file(s)"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export WIRELESS_LOOT_DIR WIRELESS_LOOT_HANDSHAKES WIRELESS_LOOT_PMKIDS
export WIRELESS_LOOT_WPS WIRELESS_LOOT_CREDENTIALS WIRELESS_LOOT_ENTERPRISE
export WIRELESS_LOOT_PORTALS WIRELESS_LOOT_CAPTURES WIRELESS_LOOT_SCANS

export -f wireless_loot_init wireless_loot_filename
export -f wireless_loot_save_handshake wireless_loot_convert_handshake wireless_loot_list_handshakes
export -f wireless_loot_save_pmkid wireless_loot_list_pmkids
export -f wireless_loot_save_wps
export -f wireless_loot_add_cracked wireless_loot_show_cracked wireless_loot_search_cracked
export -f wireless_loot_save_portal_creds
export -f wireless_loot_summary wireless_loot_export wireless_loot_cleanup
