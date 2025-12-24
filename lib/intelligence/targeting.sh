#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Target Acquisition System
# ═══════════════════════════════════════════════════════════════════════════════
# Smart network scanning and target selection:
# - Pre-scan before attacks
# - Parse scan results into selectable list
# - WPS-specific scanning
# - Client detection
# - Target validation
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_TARGETING_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_TARGETING_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# SCAN STORAGE
# ═══════════════════════════════════════════════════════════════════════════════

declare -g SCAN_TEMP="/tmp/voidwave_scan_$$"
declare -ga SCAN_RESULTS=()       # Array of "BSSID|CHANNEL|ESSID|ENC|PWR|WPS|CLIENTS"
declare -ga SCAN_CLIENTS=()       # Array of "MAC|BSSID|PWR"
declare -ga SCAN_WPS=()           # Array of "BSSID|CHANNEL|ESSID|LOCKED|VERSION"

# Currently selected target
declare -g TARGET_BSSID=""
declare -g TARGET_CHANNEL=""
declare -g TARGET_ESSID=""
declare -g TARGET_ENC=""
declare -g TARGET_CLIENT=""

# ═══════════════════════════════════════════════════════════════════════════════
# NETWORK SCANNING
# ═══════════════════════════════════════════════════════════════════════════════

# Scan networks and populate SCAN_RESULTS
# Args: $1 = interface, $2 = duration (default 20), $3 = channel (optional)
scan_networks() {
    local iface="$1"
    local duration="${2:-20}"
    local channel="${3:-}"
    
    [[ -z "$iface" ]] && { echo -e "    ${C_RED}No interface${C_RESET}"; return 1; }
    
    mkdir -p "$SCAN_TEMP"
    local outfile="$SCAN_TEMP/airodump"
    
    echo ""
    echo -e "    ${C_CYAN}⟳ Scanning networks (${duration}s)...${C_RESET}"
    echo -e "    ${C_SHADOW}Interface: $iface${C_RESET}"
    [[ -n "$channel" ]] && echo -e "    ${C_SHADOW}Channel: $channel${C_RESET}"
    echo ""
    
    # Build command
    local cmd="airodump-ng --write-interval 1 -w '$outfile' --output-format csv"
    [[ -n "$channel" ]] && cmd="$cmd -c $channel"
    cmd="$cmd '$iface'"
    
    # Run with timeout, suppress output
    timeout "$duration" bash -c "$cmd" &>/dev/null &
    local pid=$!
    
    # Progress bar
    local i=0
    while kill -0 $pid 2>/dev/null && [[ $i -lt $duration ]]; do
        local pct=$((i * 100 / duration))
        local filled=$((pct / 5))
        local empty=$((20 - filled))
        printf "\r    [${C_CYAN}%s%s${C_RESET}] %d%%" \
            "$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null)" \
            "$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null)" \
            "$pct"
        sleep 1
        ((i++))
    done
    printf "\r    [${C_GREEN}████████████████████${C_RESET}] 100%%\n"
    
    wait $pid 2>/dev/null
    
    # Parse results
    _parse_airodump_csv "$outfile-01.csv"
    
    echo ""
    echo -e "    ${C_GREEN}Found ${#SCAN_RESULTS[@]} networks${C_RESET}"
}

# Parse airodump CSV output
_parse_airodump_csv() {
    local csvfile="$1"
    [[ ! -f "$csvfile" ]] && return 1
    
    SCAN_RESULTS=()
    SCAN_CLIENTS=()
    
    local in_clients=0
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Detect client section
        if [[ "$line" == *"Station MAC"* ]]; then
            in_clients=1
            continue
        fi
        
        # Skip headers
        [[ "$line" == *"BSSID"* ]] && continue
        
        if [[ $in_clients -eq 0 ]]; then
            # Parse network line
            local bssid channel privacy essid power
            bssid=$(echo "$line" | cut -d',' -f1 | xargs)
            [[ -z "$bssid" || "$bssid" == "" ]] && continue
            
            channel=$(echo "$line" | cut -d',' -f4 | xargs)
            privacy=$(echo "$line" | cut -d',' -f6 | xargs)
            power=$(echo "$line" | cut -d',' -f9 | xargs)
            essid=$(echo "$line" | cut -d',' -f14 | xargs)
            
            # Clean up
            [[ "$power" == "-1" ]] && power="?"
            [[ -z "$essid" ]] && essid="<hidden>"
            
            SCAN_RESULTS+=("$bssid|$channel|$essid|$privacy|$power")
        else
            # Parse client line
            local mac bssid power
            mac=$(echo "$line" | cut -d',' -f1 | xargs)
            bssid=$(echo "$line" | cut -d',' -f6 | xargs)
            power=$(echo "$line" | cut -d',' -f4 | xargs)
            
            [[ -z "$mac" || "$mac" == "(not associated)" ]] && continue
            [[ "$bssid" == "(not associated)" ]] && continue
            
            SCAN_CLIENTS+=("$mac|$bssid|$power")
        fi
    done < "$csvfile"
}

# ═══════════════════════════════════════════════════════════════════════════════
# WPS SCANNING
# ═══════════════════════════════════════════════════════════════════════════════

# Scan for WPS-enabled networks
# Args: $1 = interface, $2 = duration (default 30)
scan_wps() {
    local iface="$1"
    local duration="${2:-30}"
    
    [[ -z "$iface" ]] && { echo -e "    ${C_RED}No interface${C_RESET}"; return 1; }
    
    if ! command -v wash &>/dev/null; then
        echo -e "    ${C_RED}wash not found - install reaver package${C_RESET}"
        return 1
    fi
    
    mkdir -p "$SCAN_TEMP"
    local outfile="$SCAN_TEMP/wps_scan.txt"
    
    echo ""
    echo -e "    ${C_CYAN}⟳ Scanning for WPS networks (${duration}s)...${C_RESET}"
    echo ""
    
    # Run wash
    timeout "$duration" wash -i "$iface" -5 2>/dev/null | tee "$outfile" &
    local pid=$!
    
    wait $pid 2>/dev/null
    
    # Parse results
    _parse_wash_output "$outfile"
    
    echo ""
    echo -e "    ${C_GREEN}Found ${#SCAN_WPS[@]} WPS-enabled networks${C_RESET}"
}

# Parse wash output
_parse_wash_output() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    
    SCAN_WPS=()
    
    while IFS= read -r line; do
        # Skip headers and empty
        [[ "$line" == *"BSSID"* ]] && continue
        [[ "$line" == *"----"* ]] && continue
        [[ -z "$line" ]] && continue
        
        local bssid channel essid locked version
        bssid=$(echo "$line" | awk '{print $1}')
        channel=$(echo "$line" | awk '{print $2}')
        locked=$(echo "$line" | awk '{print $5}')
        version=$(echo "$line" | awk '{print $4}')
        essid=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf $i" "; print ""}' | xargs)
        
        [[ -z "$bssid" ]] && continue
        
        SCAN_WPS+=("$bssid|$channel|$essid|$locked|$version")
    done < "$file"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TARGET SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Display networks and let user select
# Returns: 0 if target selected, 1 if cancelled
# Sets: TARGET_BSSID, TARGET_CHANNEL, TARGET_ESSID, TARGET_ENC
select_target() {
    if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
        echo -e "    ${C_YELLOW}No scan results. Run scan first.${C_RESET}"
        return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ SELECT TARGET ━━━${C_RESET}"
    echo ""
    printf "    ${C_WHITE}%-4s %-18s %-4s %-24s %-8s %s${C_RESET}\n" \
        "NUM" "BSSID" "CH" "ESSID" "ENC" "PWR"
    echo -e "    ${C_SHADOW}────────────────────────────────────────────────────────────────────${C_RESET}"
    
    local i=1
    for entry in "${SCAN_RESULTS[@]}"; do
        local bssid channel essid enc power
        IFS='|' read -r bssid channel essid enc power <<< "$entry"
        
        # Count clients for this network
        local clients=0
        for client in "${SCAN_CLIENTS[@]}"; do
            [[ "$client" == *"$bssid"* ]] && ((clients++))
        done
        
        # Color code by encryption
        local enc_color="$C_GREEN"
        [[ "$enc" == *"WPA"* ]] && enc_color="$C_YELLOW"
        [[ "$enc" == *"WPA2"* ]] && enc_color="$C_RED"
        [[ "$enc" == *"WPA3"* ]] && enc_color="$C_PURPLE"
        
        # Truncate ESSID
        [[ ${#essid} -gt 22 ]] && essid="${essid:0:20}.."
        
        printf "    ${C_CYAN}%3d${C_RESET}) %-18s %3s  %-24s ${enc_color}%-8s${C_RESET} %s" \
            "$i" "$bssid" "$channel" "$essid" "$enc" "$power"
        [[ $clients -gt 0 ]] && printf " ${C_GREEN}[%d clients]${C_RESET}" "$clients"
        echo ""
        
        ((i++))
    done
    
    echo ""
    echo -e "    ${C_SHADOW}[S] Rescan  [M] Manual entry  [0] Cancel${C_RESET}"
    echo ""
    
    while true; do
        echo -en "    ${C_PURPLE}▶${C_RESET} Select target: "
        read -r choice
        
        case "${choice,,}" in
            0|q|cancel) return 1 ;;
            s|scan) return 2 ;;  # Signal to rescan
            m|manual)
                _manual_target_entry
                return $?
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && \
                   [[ "$choice" -ge 1 ]] && \
                   [[ "$choice" -le "${#SCAN_RESULTS[@]}" ]]; then
                    local entry="${SCAN_RESULTS[$((choice-1))]}"
                    IFS='|' read -r TARGET_BSSID TARGET_CHANNEL TARGET_ESSID TARGET_ENC _ <<< "$entry"
                    echo ""
                    echo -e "    ${C_GREEN}✓ Target: $TARGET_ESSID ($TARGET_BSSID) CH:$TARGET_CHANNEL${C_RESET}"
                    return 0
                fi
                echo -e "    ${C_RED}Invalid selection${C_RESET}"
                ;;
        esac
    done
}

# Display WPS networks and let user select
select_wps_target() {
    if [[ ${#SCAN_WPS[@]} -eq 0 ]]; then
        echo -e "    ${C_YELLOW}No WPS networks found. Run WPS scan first.${C_RESET}"
        return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ WPS TARGETS ━━━${C_RESET}"
    echo ""
    printf "    ${C_WHITE}%-4s %-18s %-4s %-24s %-6s %s${C_RESET}\n" \
        "NUM" "BSSID" "CH" "ESSID" "LOCKED" "VER"
    echo -e "    ${C_SHADOW}────────────────────────────────────────────────────────────────${C_RESET}"
    
    local i=1
    for entry in "${SCAN_WPS[@]}"; do
        local bssid channel essid locked version
        IFS='|' read -r bssid channel essid locked version <<< "$entry"
        
        local lock_color="$C_GREEN"
        local lock_text="No"
        if [[ "$locked" == "Yes" || "$locked" == "Lck" ]]; then
            lock_color="$C_RED"
            lock_text="YES"
        fi
        
        [[ ${#essid} -gt 22 ]] && essid="${essid:0:20}.."
        
        printf "    ${C_CYAN}%3d${C_RESET}) %-18s %3s  %-24s ${lock_color}%-6s${C_RESET} %s\n" \
            "$i" "$bssid" "$channel" "$essid" "$lock_text" "$version"
        
        ((i++))
    done
    
    echo ""
    echo -e "    ${C_SHADOW}[S] Rescan  [0] Cancel${C_RESET}"
    echo ""
    
    while true; do
        echo -en "    ${C_PURPLE}▶${C_RESET} Select target: "
        read -r choice
        
        case "${choice,,}" in
            0|q) return 1 ;;
            s) return 2 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && \
                   [[ "$choice" -ge 1 ]] && \
                   [[ "$choice" -le "${#SCAN_WPS[@]}" ]]; then
                    local entry="${SCAN_WPS[$((choice-1))]}"
                    IFS='|' read -r TARGET_BSSID TARGET_CHANNEL TARGET_ESSID _ _ <<< "$entry"
                    echo ""
                    echo -e "    ${C_GREEN}✓ Target: $TARGET_ESSID ($TARGET_BSSID) CH:$TARGET_CHANNEL${C_RESET}"
                    return 0
                fi
                echo -e "    ${C_RED}Invalid selection${C_RESET}"
                ;;
        esac
    done
}

# Manual target entry
_manual_target_entry() {
    echo ""
    read -rp "    BSSID (AA:BB:CC:DD:EE:FF): " TARGET_BSSID
    [[ -z "$TARGET_BSSID" ]] && return 1
    
    read -rp "    Channel: " TARGET_CHANNEL
    [[ -z "$TARGET_CHANNEL" ]] && return 1
    
    read -rp "    ESSID (optional): " TARGET_ESSID
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLIENT SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Show clients for selected target and let user pick
select_client() {
    [[ -z "$TARGET_BSSID" ]] && { echo -e "    ${C_RED}No target selected${C_RESET}"; return 1; }
    
    local -a target_clients=()
    for client in "${SCAN_CLIENTS[@]}"; do
        [[ "$client" == *"$TARGET_BSSID"* ]] && target_clients+=("$client")
    done
    
    if [[ ${#target_clients[@]} -eq 0 ]]; then
        echo -e "    ${C_YELLOW}No clients found for target${C_RESET}"
        echo -e "    ${C_SHADOW}Using broadcast deauth${C_RESET}"
        TARGET_CLIENT=""
        return 0
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ CLIENTS ON $TARGET_ESSID ━━━${C_RESET}"
    echo ""
    printf "    ${C_WHITE}%-4s %-18s %s${C_RESET}\n" "NUM" "CLIENT MAC" "SIGNAL"
    echo -e "    ${C_SHADOW}────────────────────────────────────${C_RESET}"
    
    local i=1
    for entry in "${target_clients[@]}"; do
        local mac _ power
        IFS='|' read -r mac _ power <<< "$entry"
        printf "    ${C_CYAN}%3d${C_RESET}) %-18s %s dBm\n" "$i" "$mac" "$power"
        ((i++))
    done
    
    echo ""
    echo -e "    ${C_SHADOW}[B] Broadcast (all clients)  [0] Cancel${C_RESET}"
    echo ""
    
    echo -en "    ${C_PURPLE}▶${C_RESET} Select client: "
    read -r choice
    
    case "${choice,,}" in
        0|q) return 1 ;;
        b|broadcast|"")
            TARGET_CLIENT=""
            echo -e "    ${C_GREEN}✓ Using broadcast deauth${C_RESET}"
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && \
               [[ "$choice" -ge 1 ]] && \
               [[ "$choice" -le "${#target_clients[@]}" ]]; then
                local entry="${target_clients[$((choice-1))]}"
                TARGET_CLIENT=$(echo "$entry" | cut -d'|' -f1)
                echo -e "    ${C_GREEN}✓ Target client: $TARGET_CLIENT${C_RESET}"
            fi
            ;;
    esac
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONVENIENCE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Combined scan + select flow
# Args: $1 = interface, $2 = scan type (networks/wps)
# Returns: 0 with target set, 1 if cancelled
acquire_target() {
    local iface="$1"
    local scan_type="${2:-networks}"
    
    while true; do
        case "$scan_type" in
            wps)
                scan_wps "$iface"
                select_wps_target
                ;;
            *)
                scan_networks "$iface"
                select_target
                ;;
        esac
        
        local rc=$?
        case $rc in
            0) return 0 ;;      # Target selected
            1) return 1 ;;      # Cancelled
            2) continue ;;      # Rescan requested
        esac
    done
}

# Check if we have a target
has_target() {
    [[ -n "$TARGET_BSSID" && -n "$TARGET_CHANNEL" ]]
}

# Clear target
clear_target() {
    TARGET_BSSID=""
    TARGET_CHANNEL=""
    TARGET_ESSID=""
    TARGET_ENC=""
    TARGET_CLIENT=""
}

# Get target as string
get_target_string() {
    if has_target; then
        echo "${TARGET_ESSID:-$TARGET_BSSID} (CH:$TARGET_CHANNEL)"
    else
        echo "none"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_scan_temp() {
    [[ -d "$SCAN_TEMP" ]] && rm -rf "$SCAN_TEMP"
}

trap cleanup_scan_temp EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f scan_networks scan_wps
export -f select_target select_wps_target select_client
export -f acquire_target has_target clear_target get_target_string
