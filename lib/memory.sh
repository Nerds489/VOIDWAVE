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
# Session Memory Library: track recent scans, resources, and provide smart prompts
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_MEMORY_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_MEMORY_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# MEMORY CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Memory storage directory
MEMORY_DIR="${VOIDWAVE_HOME:-$HOME/.voidwave}/memory"
MEMORY_MAX_ENTRIES="${MEMORY_MAX_ENTRIES:-20}"  # Max items to remember per type
MEMORY_SESSION_ONLY="${MEMORY_SESSION_ONLY:-0}" # 1=clear on new session, 0=persist

# Memory file paths (lazy-init in ensure_memory_dir)
declare -g MEMORY_FILE_NETWORKS=""
declare -g MEMORY_FILE_HOSTS=""
declare -g MEMORY_FILE_WIRELESS=""
declare -g MEMORY_FILE_INTERFACES=""

# ═══════════════════════════════════════════════════════════════════════════════
# MEMORY INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

ensure_memory_dir() {
    [[ -d "$MEMORY_DIR" ]] || mkdir -p "$MEMORY_DIR" 2>/dev/null
    chmod 700 "$MEMORY_DIR" 2>/dev/null

    # Initialize file paths
    MEMORY_FILE_NETWORKS="${MEMORY_DIR}/networks.mem"
    MEMORY_FILE_HOSTS="${MEMORY_DIR}/hosts.mem"
    MEMORY_FILE_WIRELESS="${MEMORY_DIR}/wireless.mem"
    MEMORY_FILE_INTERFACES="${MEMORY_DIR}/interfaces.mem"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CORE MEMORY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Add item to memory
# Usage: memory_add <type> <value> [metadata...]
# Types: network, host, wireless, interface
# Example: memory_add network "192.168.1.0/24" "gateway=192.168.1.1" "iface=eth0"
memory_add() {
    local type="$1"
    local value="$2"
    shift 2
    local metadata=("$@")

    ensure_memory_dir

    local mem_file
    case "$type" in
        network|networks)  mem_file="$MEMORY_FILE_NETWORKS" ;;
        host|hosts)        mem_file="$MEMORY_FILE_HOSTS" ;;
        wireless|wifi|ap)  mem_file="$MEMORY_FILE_WIRELESS" ;;
        interface|iface)   mem_file="$MEMORY_FILE_INTERFACES" ;;
        *)
            log_warning "Unknown memory type: $type"
            return 1
            ;;
    esac

    [[ -z "$value" ]] && return 1

    local timestamp
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1

    # Build entry line: timestamp|value|metadata1|metadata2|...
    local entry="${timestamp}|${value}"
    for meta in "${metadata[@]}"; do
        entry+="|${meta}"
    done

    # Remove duplicates (same value) and add new entry at top
    local tmp_file="${mem_file}.tmp.$$"
    {
        echo "$entry"
        if [[ -f "$mem_file" ]]; then
            grep -v "^[^|]*|${value}|" "$mem_file" 2>/dev/null | head -n "$((MEMORY_MAX_ENTRIES - 1))"
        fi
    } > "$tmp_file"
    mv "$tmp_file" "$mem_file"

    log_debug "Memory added: $type = $value"
}

# Get recent items from memory
# Usage: memory_get <type> [limit]
# Returns: lines of "timestamp|value|metadata..."
memory_get() {
    local type="$1"
    local limit="${2:-$MEMORY_MAX_ENTRIES}"

    ensure_memory_dir

    local mem_file
    case "$type" in
        network|networks)  mem_file="$MEMORY_FILE_NETWORKS" ;;
        host|hosts)        mem_file="$MEMORY_FILE_HOSTS" ;;
        wireless|wifi|ap)  mem_file="$MEMORY_FILE_WIRELESS" ;;
        interface|iface)   mem_file="$MEMORY_FILE_INTERFACES" ;;
        *)
            return 1
            ;;
    esac

    [[ -f "$mem_file" ]] || return 1
    head -n "$limit" "$mem_file" 2>/dev/null
}

# Get just values from memory (no timestamp/metadata)
# Usage: memory_get_values <type> [limit]
memory_get_values() {
    local type="$1"
    local limit="${2:-$MEMORY_MAX_ENTRIES}"

    memory_get "$type" "$limit" | cut -d'|' -f2
}

# Check if memory has items
# Usage: memory_has <type>
memory_has() {
    local type="$1"
    local entries
    entries=$(memory_get "$type" 1)
    [[ -n "$entries" ]]
}

# Count memory entries
# Usage: memory_count <type>
memory_count() {
    local type="$1"
    ensure_memory_dir

    local mem_file
    case "$type" in
        network|networks)  mem_file="$MEMORY_FILE_NETWORKS" ;;
        host|hosts)        mem_file="$MEMORY_FILE_HOSTS" ;;
        wireless|wifi|ap)  mem_file="$MEMORY_FILE_WIRELESS" ;;
        interface|iface)   mem_file="$MEMORY_FILE_INTERFACES" ;;
        *)
            echo "0"
            return
            ;;
    esac

    [[ -f "$mem_file" ]] && wc -l < "$mem_file" 2>/dev/null || echo "0"
}

# Clear memory for a type
# Usage: memory_clear <type|all>
memory_clear() {
    local type="$1"

    ensure_memory_dir

    case "$type" in
        network|networks)  rm -f "$MEMORY_FILE_NETWORKS" ;;
        host|hosts)        rm -f "$MEMORY_FILE_HOSTS" ;;
        wireless|wifi|ap)  rm -f "$MEMORY_FILE_WIRELESS" ;;
        interface|iface)   rm -f "$MEMORY_FILE_INTERFACES" ;;
        all)
            rm -f "$MEMORY_FILE_NETWORKS" "$MEMORY_FILE_HOSTS" \
                  "$MEMORY_FILE_WIRELESS" "$MEMORY_FILE_INTERFACES"
            ;;
        *)
            return 1
            ;;
    esac

    log_debug "Memory cleared: $type"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SMART RESOURCE PROMPT SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

# Universal resource acquisition with memory
# Usage: get_resource_with_memory <type> <prompt> <scan_function> [validator]
#
# Flow:
#   1. Check memory for recent items of this type
#   2. If found: show selection menu with options to use recent, scan new, or enter manual
#   3. If not found: ask Y/N to auto-scan
#      - Y: run scan_function, save results to memory, return selected
#      - N: prompt for manual input
#
# Args:
#   type         - Memory type: network, host, wireless, interface
#   prompt       - Display prompt (e.g., "Select target network")
#   scan_func    - Function to call for auto-discovery (receives no args, echoes results)
#   validator    - Optional validator function for manual input
#
# Returns: selected value via stdout, 0 on success, 1 on cancel
get_resource_with_memory() {
    local type="$1"
    local prompt="$2"
    local scan_func="$3"
    local validator="${4:-}"

    ensure_memory_dir

    # Non-interactive mode
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        # Return most recent or require manual
        local recent
        recent=$(memory_get_values "$type" 1 | head -1)
        if [[ -n "$recent" ]]; then
            echo "$recent"
            return 0
        fi
        log_error "Non-interactive mode requires recent $type in memory or manual input"
        return 1
    fi

    # Check for recent items
    local count
    count=$(memory_count "$type")

    if [[ "$count" -gt 0 ]]; then
        # Show selection with recent items
        _memory_show_selection "$type" "$prompt" "$scan_func" "$validator"
    else
        # No recent items - ask to scan
        _memory_prompt_scan "$type" "$prompt" "$scan_func" "$validator"
    fi
}

# Internal: show selection menu with recent items
_memory_show_selection() {
    local type="$1"
    local prompt="$2"
    local scan_func="$3"
    local validator="$4"

    local -a items=()
    local -a displays=()

    # Load recent items
    while IFS='|' read -r timestamp value rest; do
        [[ -z "$value" ]] && continue
        items+=("$value")
        # Format display: value (time ago)
        local age
        age=$(_memory_time_ago "$timestamp")
        displays+=("$value ${C_SHADOW:-}($age)${C_RESET:-}")
    done < <(memory_get "$type" 10)

    # NOTE: All prompts go to stderr so they display even when stdout is captured
    echo "" >&2
    echo -e "    ${C_CYAN:-}${prompt}${C_RESET:-}" >&2
    echo "" >&2
    echo -e "    ${C_SHADOW:-}Recent:${C_RESET:-}" >&2

    local i
    for i in "${!displays[@]}"; do
        echo -e "    ${C_GHOST:-}[$((i+1))]${C_RESET:-} ${displays[$i]}" >&2
    done

    echo "" >&2
    echo -e "    ${C_GHOST:-}[S]${C_RESET:-} Scan for new" >&2
    echo -e "    ${C_GHOST:-}[M]${C_RESET:-} Enter manually" >&2
    echo -e "    ${C_GHOST:-}[0]${C_RESET:-} Cancel" >&2
    echo "" >&2

    local choice
    read -rp "    Select: " choice

    case "${choice,,}" in
        s|scan)
            _memory_do_scan "$type" "$scan_func" "$validator"
            return $?
            ;;
        m|manual)
            _memory_manual_input "$type" "$prompt" "$validator"
            return $?
            ;;
        0|q|quit|cancel)
            return 1
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
                local selected="${items[$((choice-1))]}"
                # Re-add to bump to top of memory
                memory_add "$type" "$selected"
                echo "$selected"
                return 0
            fi
            echo -e "    ${C_RED:-}Invalid selection: '$choice'${C_RESET:-}" >&2
            return 1
            ;;
    esac
}

# Internal: prompt for scan when no recent items
_memory_prompt_scan() {
    local type="$1"
    local prompt="$2"
    local scan_func="$3"
    local validator="$4"

    # All prompts go to stderr so they display even when stdout is captured
    echo "" >&2
    echo -e "    ${C_CYAN:-}${prompt}${C_RESET:-}" >&2
    echo "" >&2
    echo -e "    ${C_SHADOW:-}No recent ${type}s found.${C_RESET:-}" >&2
    echo "" >&2

    local response
    read -rp "    Scan for ${type}s? [Y/n]: " response
    response="${response:-y}"

    case "${response,,}" in
        y|yes)
            _memory_do_scan "$type" "$scan_func" "$validator"
            return $?
            ;;
        *)
            _memory_manual_input "$type" "$prompt" "$validator"
            return $?
            ;;
    esac
}

# Internal: perform scan and select from results
_memory_do_scan() {
    local type="$1"
    local scan_func="$2"
    local validator="$3"

    if [[ -z "$scan_func" ]] || ! type -t "$scan_func" &>/dev/null; then
        echo -e "    ${C_RED:-}Scan function not available: $scan_func${C_RESET:-}" >&2
        _memory_manual_input "$type" "Enter $type" "$validator"
        return $?
    fi

    # All prompts go to stderr so they display even when stdout is captured
    echo "" >&2
    echo -e "    ${C_CYAN:-}Scanning...${C_RESET:-}" >&2
    echo "" >&2

    # Run scan function - expects it to output one item per line
    local -a results=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        results+=("$line")
        # Add to memory as we discover
        memory_add "$type" "$line"
    done < <($scan_func 2>/dev/null)

    if [[ ${#results[@]} -eq 0 ]]; then
        echo -e "    ${C_YELLOW:-}No ${type}s found${C_RESET:-}" >&2
        echo "" >&2
        _memory_manual_input "$type" "Enter $type manually" "$validator"
        return $?
    fi

    echo -e "    ${C_GREEN:-}Found ${#results[@]} ${type}(s):${C_RESET:-}" >&2
    echo "" >&2

    # Show selection
    local i
    for i in "${!results[@]}"; do
        echo -e "    ${C_GHOST:-}[$((i+1))]${C_RESET:-} ${results[$i]}" >&2
    done
    echo "" >&2

    local choice
    read -rp "    Select [1-${#results[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#results[@]} )); then
        echo "${results[$((choice-1))]}"
        return 0
    fi

    echo -e "    ${C_RED:-}Invalid selection${C_RESET:-}" >&2
    return 1
}

# Internal: prompt for manual input
_memory_manual_input() {
    local type="$1"
    local prompt="$2"
    local validator="$3"

    echo "" >&2
    local input

    while true; do
        read -rp "    ${prompt}: " input

        [[ -z "$input" ]] && {
            echo -e "    ${C_YELLOW:-}Input required${C_RESET:-}" >&2
            continue
        }

        # Validate if validator provided
        if [[ -n "$validator" ]] && type -t "$validator" &>/dev/null; then
            if ! $validator "$input"; then
                echo -e "    ${C_YELLOW:-}Invalid input, please try again${C_RESET:-}" >&2
                continue
            fi
        fi

        # Save to memory and return
        memory_add "$type" "$input"
        echo "$input"
        return 0
    done
}

# Internal: calculate time ago string
_memory_time_ago() {
    local timestamp="$1"
    local then_epoch now_epoch diff

    # Try to parse timestamp
    then_epoch=$(date -d "$timestamp" +%s 2>/dev/null) || then_epoch=0
    now_epoch=$(date +%s)
    diff=$((now_epoch - then_epoch))

    if (( diff < 60 )); then
        echo "just now"
    elif (( diff < 3600 )); then
        echo "$((diff / 60))m ago"
    elif (( diff < 86400 )); then
        echo "$((diff / 3600))h ago"
    elif (( diff < 604800 )); then
        echo "$((diff / 86400))d ago"
    else
        echo "$timestamp"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SPECIALIZED RESOURCE GETTERS
# ═══════════════════════════════════════════════════════════════════════════════

# Get network target with memory
# Usage: result=$(get_network_target)
get_network_target() {
    get_resource_with_memory "network" "Select target network" "_scan_local_networks" "validate_target"
}

# Get host target with memory
# Usage: result=$(get_host_target)
get_host_target() {
    get_resource_with_memory "host" "Select target host" "_scan_local_hosts" "validate_target"
}

# Get wireless AP with memory
# Usage: result=$(get_wireless_target)
get_wireless_target() {
    get_resource_with_memory "wireless" "Select target AP" "_scan_wireless_aps"
}

# Get interface with memory
# Usage: result=$(get_interface_target [wireless])
get_interface_target() {
    local type="${1:-all}"
    if [[ "$type" == "wireless" ]]; then
        get_resource_with_memory "interface" "Select wireless interface" "_scan_wireless_interfaces"
    else
        get_resource_with_memory "interface" "Select network interface" "_scan_network_interfaces"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCAN FUNCTIONS (used by get_resource_with_memory)
# ═══════════════════════════════════════════════════════════════════════════════

# Scan for local networks
_scan_local_networks() {
    local gateway iface network

    # Get networks from routing table
    while read -r network _ _ _ _ _ _ _ iface _; do
        [[ "$network" == "default" ]] && continue
        [[ "$network" =~ / ]] && echo "$network"
    done < <(ip route 2>/dev/null)

    # Also include local subnet based on interface IPs
    while IFS= read -r line; do
        local ip prefix
        ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
        prefix=$(echo "$line" | awk '{print $2}' | cut -d'/' -f2)
        [[ -n "$ip" && -n "$prefix" ]] && {
            # Convert to network address (simplified - just append /24 for common case)
            local network_addr
            network_addr=$(echo "$ip" | cut -d'.' -f1-3).0/${prefix}
            echo "$network_addr"
        }
    done < <(ip -4 addr show 2>/dev/null | grep inet | grep -v "127.0.0.1")
}

# Scan for hosts on local network (quick ping sweep)
_scan_local_hosts() {
    local gateway subnet
    gateway=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')

    [[ -n "$gateway" ]] && echo "$gateway"

    # Quick ARP scan if available
    if command -v arp-scan &>/dev/null && [[ $EUID -eq 0 ]]; then
        arp-scan -l --quiet 2>/dev/null | awk '/^[0-9]/{print $1}'
    elif command -v arp &>/dev/null; then
        arp -a 2>/dev/null | awk -F'[()]' '{print $2}' | grep -v "^$"
    fi
}

# Scan for wireless APs
_scan_wireless_aps() {
    local iface

    # Get first wireless interface
    iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')
    [[ -z "$iface" ]] && return 1

    # Quick scan - iwlist is faster than airodump for quick results
    if command -v iwlist &>/dev/null; then
        iwlist "$iface" scan 2>/dev/null | awk -F'"' '/ESSID:/{if($2!="")print $2}'
    elif command -v nmcli &>/dev/null; then
        nmcli -t -f SSID dev wifi list 2>/dev/null | grep -v "^$" | sort -u
    fi
}

# Scan for wireless interfaces
_scan_wireless_interfaces() {
    iw dev 2>/dev/null | awk '/Interface/{print $2}'
}

# Scan for all network interfaces
_scan_network_interfaces() {
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v "^lo$"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MEMORY DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

# Show memory contents
memory_show() {
    local type="${1:-all}"

    ensure_memory_dir

    echo ""
    echo -e "    ${C_CYAN:-}Session Memory${C_RESET:-}"
    echo -e "    ${C_SHADOW:-}$(printf '─%.0s' {1..50})${C_RESET:-}"
    echo ""

    _memory_show_type() {
        local t="$1" label="$2"
        local count
        count=$(memory_count "$t")

        echo -e "    ${C_GREEN:-}${label}${C_RESET:-} ${C_SHADOW:-}($count items)${C_RESET:-}"

        if [[ "$count" -gt 0 ]]; then
            while IFS='|' read -r timestamp value rest; do
                local age
                age=$(_memory_time_ago "$timestamp")
                echo -e "      ${C_GHOST:-}•${C_RESET:-} $value ${C_SHADOW:-}($age)${C_RESET:-}"
            done < <(memory_get "$t" 5)
        fi
        echo ""
    }

    case "$type" in
        all)
            _memory_show_type "network" "Networks"
            _memory_show_type "host" "Hosts"
            _memory_show_type "wireless" "Wireless APs"
            _memory_show_type "interface" "Interfaces"
            ;;
        *)
            _memory_show_type "$type" "${type^}s"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export MEMORY_DIR MEMORY_MAX_ENTRIES

# Core functions
export -f ensure_memory_dir
export -f memory_add memory_get memory_get_values memory_has memory_count memory_clear

# Smart resource getters
export -f get_resource_with_memory
export -f get_network_target get_host_target get_wireless_target get_interface_target

# Scan helpers
export -f _scan_local_networks _scan_local_hosts _scan_wireless_aps
export -f _scan_wireless_interfaces _scan_network_interfaces

# Display
export -f memory_show
