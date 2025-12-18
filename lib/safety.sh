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
# Safety library: authorization checks, target validation, privilege verification
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_SAFETY_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_SAFETY_LOADED=1

# Source core library
source "${BASH_SOURCE%/*}/core.sh"

#═══════════════════════════════════════════════════════════════════════════════
# PROTECTED RANGES
#═══════════════════════════════════════════════════════════════════════════════

# Default protected ranges that should never be targeted
# These are used by is_protected_ip() to block dangerous targets
declare -ga DEFAULT_PROTECTED_RANGES=(
    "127.0.0.0/8"       # Loopback
    "169.254.0.0/16"    # Link-local
    "224.0.0.0/4"       # Multicast
    "240.0.0.0/4"       # Reserved
    "255.255.255.255/32" # Broadcast
    "0.0.0.0/8"         # Current network
)

#═══════════════════════════════════════════════════════════════════════════════
# HELPER: IP-IN-CIDR CHECK
#═══════════════════════════════════════════════════════════════════════════════

# Convert IP to 32-bit integer
# Args: $1 = IP address (a.b.c.d)
# Returns: integer via stdout
_ip_to_int() {
    local ip="$1"
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# Check if IP falls within a CIDR range
# Args: $1 = IP address, $2 = CIDR (e.g., 192.168.0.0/16)
# Returns: 0 if IP is in CIDR, 1 if not
_ip_in_cidr() {
    local ip="$1"
    local cidr="$2"

    # Handle single IP (no prefix) as /32
    local network prefix
    if [[ "$cidr" == */* ]]; then
        network="${cidr%/*}"
        prefix="${cidr#*/}"
    else
        network="$cidr"
        prefix=32
    fi

    # Convert to integers
    local ip_int network_int mask
    ip_int=$(_ip_to_int "$ip")
    network_int=$(_ip_to_int "$network")

    # Calculate mask (handle prefix=0 edge case)
    if [[ "$prefix" -eq 0 ]]; then
        mask=0
    else
        mask=$(( 0xFFFFFFFF << (32 - prefix) ))
    fi

    # Check if IP is in network
    (( (ip_int & mask) == (network_int & mask) ))
}

#═══════════════════════════════════════════════════════════════════════════════
# PRIVILEGE CHECKS
#═══════════════════════════════════════════════════════════════════════════════

# Check if running as root
# Returns: 0 if root, 1 if not
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges"
        log_info "Please run with sudo or as root"
        return 1
    fi
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# UNSAFE MODE HELPERS
#═══════════════════════════════════════════════════════════════════════════════

# Check if unsafe mode is enabled (backward compatible)
# Accepts: "1", "true", "TRUE", "yes", "YES", "y", "Y"
# Returns: 0 if enabled, 1 if disabled
is_unsafe_mode_enabled() {
    local val="${VW_UNSAFE_MODE:-0}"
    case "${val,,}" in
        1|true|yes|y) return 0 ;;
        *) return 1 ;;
    esac
}

# Legacy alias for backward compatibility
is_unsafe_mode() {
    is_unsafe_mode_enabled
}

# Display unsafe mode warning banner
check_unsafe_mode() {
    if is_unsafe_mode_enabled; then
        log_warning "╔════════════════════════════════════════════════════╗"
        log_warning "║  UNSAFE MODE ENABLED                               ║"
        log_warning "║  All safety checks are BYPASSED                    ║"
        log_warning "╚════════════════════════════════════════════════════╝"
        log_audit "UNSAFE_MODE" "Enabled" "warning"
        return 0
    fi
    return 1
}

# Check if unsafe mode is enabled for dangerous operations
# Returns: 0 if unsafe mode enabled, 1 if not
require_unsafe_mode() {
    local operation="${1:-dangerous operation}"

    if ! is_unsafe_mode_enabled; then
        log_error "This $operation requires VW_UNSAFE_MODE=1"
        log_info "Set environment variable: export VW_UNSAFE_MODE=1"
        log_warning "This bypasses safety checks - use with extreme caution"
        return 1
    fi

    log_warning "VW_UNSAFE_MODE is enabled - safety checks bypassed"
    log_audit "UNSAFE_MODE" "$operation" "allowed"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# AUTHORIZATION CHECK
#═══════════════════════════════════════════════════════════════════════════════

# Authorization file location
readonly AUTHORIZATION_FILE="${VOIDWAVE_HOME}/.authorized"

# Check if user has acknowledged authorization requirement
# Returns: 0 if authorized, 1 if not (and prompts for confirmation)
#
# Non-interactive auto-authorization requires BOTH:
#   - VW_AUTO_AUTHORIZE_NON_INTERACTIVE=1 (explicit opt-in)
#   - VW_UNSAFE_MODE enabled (unsafe mode must be on)
check_authorization() {
    # Already authorized
    if [[ -f "$AUTHORIZATION_FILE" ]]; then
        return 0
    fi

    # Non-interactive mode handling
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        # Check for explicit opt-in for auto-authorization
        if [[ "${VW_AUTO_AUTHORIZE_NON_INTERACTIVE:-0}" == "1" ]] && is_unsafe_mode_enabled; then
            mkdir -p "$VOIDWAVE_HOME" 2>/dev/null
            echo "$(date -Iseconds) | $(whoami)@$(hostname) | Auto-authorized (non-interactive, unsafe mode)" > "$AUTHORIZATION_FILE"
            chmod 600 "$AUTHORIZATION_FILE" 2>/dev/null
            log_debug "Auto-authorized in non-interactive mode (VW_AUTO_AUTHORIZE_NON_INTERACTIVE=1, unsafe mode enabled)"
            log_audit "AUTO_AUTH_NON_INTERACTIVE" "authorized via VW_AUTO_AUTHORIZE_NON_INTERACTIVE" "success"
            return 0
        fi

        # Non-interactive without explicit opt-in: fail safe
        log_error "Authorization required but running in non-interactive mode"
        log_info "To auto-authorize in non-interactive mode, set:"
        log_info "  VW_AUTO_AUTHORIZE_NON_INTERACTIVE=1 VW_UNSAFE_MODE=1"
        log_audit "AUTO_AUTH_NON_INTERACTIVE" "blocked - no explicit opt-in" "failed"
        return 1
    fi

    # Ensure directory exists
    mkdir -p "$VOIDWAVE_HOME" 2>/dev/null

    echo
    echo -e "    ${C_RED}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}                   ${C_YELLOW}⚠  AUTHORIZATION REQUIRED  ⚠${C_RESET}                     ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}╠══════════════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}                                                                      ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_WHITE}VOIDWAVE is an offensive security toolkit.${C_RESET}                        ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_WHITE}Unauthorized use against systems you don't own or${C_RESET}                  ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_WHITE}have explicit written permission to test is ILLEGAL.${C_RESET}               ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}                                                                      ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_SHADOW}By proceeding, you confirm:${C_RESET}                                       ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_SHADOW}• You have WRITTEN authorization to test target systems${C_RESET}           ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_SHADOW}• You accept FULL legal responsibility for your actions${C_RESET}           ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_SHADOW}• You understand unauthorized access is a FEDERAL CRIME${C_RESET}           ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}                                                                      ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo

    echo -ne "    ${C_YELLOW}Type '${C_GREEN}I AM AUTHORIZED${C_YELLOW}' to confirm you have permission: ${C_RESET}"
    read -r response

    if [[ "$response" == "I AM AUTHORIZED" ]]; then
        # Record authorization
        echo "$(date -Iseconds) | $(whoami)@$(hostname) | Authorized" > "$AUTHORIZATION_FILE"
        chmod 600 "$AUTHORIZATION_FILE" 2>/dev/null
        log_success "Authorization confirmed"
        log_audit "AUTHORIZATION" "User accepted terms" "success"
        return 0
    else
        log_error "Authorization not confirmed"
        log_audit "AUTHORIZATION" "User declined terms" "failed"
        return 1
    fi
}

# Reset authorization (for testing or re-confirmation)
reset_authorization() {
    if [[ -f "$AUTHORIZATION_FILE" ]]; then
        rm -f "$AUTHORIZATION_FILE"
        log_info "Authorization reset. You will be prompted again on next run."
    else
        log_info "No authorization file found."
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# IP ADDRESS VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate IPv4 address format
# Args: $1 = IP address
# Returns: 0 if valid, 1 if invalid
is_valid_ip() {
    local ip="$1"
    local ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    [[ ! "$ip" =~ $ipv4_regex ]] && return 1

    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( octet > 255 )) && return 1
    done
    return 0
}

# Check if IP is RFC1918 private address
# Args: $1 = IP address
# Returns: 0 if private, 1 if public
is_private_ip() {
    local ip="$1"

    # Validate IP format first
    is_valid_ip "$ip" || return 1

    # 10.0.0.0/8
    [[ "$ip" =~ ^10\. ]] && return 0

    # 192.168.0.0/16
    [[ "$ip" =~ ^192\.168\. ]] && return 0

    # 127.0.0.0/8 (loopback)
    [[ "$ip" =~ ^127\. ]] && return 0

    # 172.16.0.0/12
    if [[ "$ip" =~ ^172\.([0-9]+)\. ]]; then
        local second="${BASH_REMATCH[1]}"
        (( second >= 16 && second <= 31 )) && return 0
    fi

    # 169.254.0.0/16 (link-local)
    [[ "$ip" =~ ^169\.254\. ]] && return 0

    # Not a private IP
    return 1
}

# Validate CIDR notation
# Args: $1 = CIDR (e.g., 192.168.1.0/24)
# Returns: 0 if valid, 1 if invalid
is_valid_cidr() {
    local cidr="$1"

    # Check format
    [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] && return 1

    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    # Validate IP part
    is_valid_ip "$ip" || return 1

    # Validate prefix (0-32 for IPv4)
    (( prefix >= 0 && prefix <= 32 )) || return 1

    return 0
}

# Check if target is a CIDR range that covers everything
# Args: $1 = target
# Returns: 0 if dangerous, 1 if OK
is_dangerous_range() {
    local target="$1"

    # Block 0.0.0.0/0 (entire internet)
    [[ "$target" == "0.0.0.0/0" ]] && return 0

    # Block ::/0 (entire IPv6 internet)
    [[ "$target" == "::/0" ]] && return 0

    # Block very broad ranges (/0 through /7)
    [[ "$target" =~ ^0\.0\.0\.0/[0-7]$ ]] && return 0

    # Block any /0 range
    [[ "$target" =~ /0$ ]] && return 0

    return 1
}

# Check if IP falls within a protected range
# Uses DEFAULT_PROTECTED_RANGES array for CIDR-based matching
# Args: $1 = IP address
# Returns: 0 if protected, 1 if not
is_protected_ip() {
    local ip="$1"

    # Validate IP format first
    is_valid_ip "$ip" || return 1

    # Check against all protected CIDR ranges
    local cidr
    for cidr in "${DEFAULT_PROTECTED_RANGES[@]}"; do
        if _ip_in_cidr "$ip" "$cidr"; then
            log_debug "IP $ip matches protected range $cidr"
            return 0
        fi
    done

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# TARGET VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate a target before scanning/attacking
# Args: $1 = target (IP, hostname, CIDR), $2 = operation name (optional)
# Returns: 0 if OK, 1 if blocked
validate_target() {
    local target="$1"
    local operation="${2:-scan}"

    # Empty target
    if [[ -z "$target" ]]; then
        log_error "No target specified"
        return 1
    fi

    # Check for dangerous ranges
    if is_dangerous_range "$target"; then
        log_error "Target '$target' is blocked - cannot target entire internet"
        log_audit "TARGET_BLOCKED" "$target" "dangerous_range"
        return 1
    fi

    local ip=""

    # Determine IP from target
    if is_valid_ip "$target"; then
        ip="$target"
    elif is_valid_cidr "$target"; then
        ip="${target%/*}"
    else
        # Try to resolve hostname
        if command -v dig &>/dev/null; then
            ip=$(dig +short "$target" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
        elif command -v host &>/dev/null; then
            ip=$(host "$target" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        elif command -v getent &>/dev/null; then
            ip=$(getent hosts "$target" 2>/dev/null | awk '{print $1}' | head -1)
        fi

        if [[ -z "$ip" ]] || ! is_valid_ip "$ip"; then
            log_error "Cannot resolve hostname: $target"
            return 1
        fi
        log_debug "Resolved $target -> $ip"
    fi

    # Check protected ranges
    if is_protected_ip "$ip"; then
        log_error "Target '$ip' is in a protected range"
        log_audit "TARGET_BLOCKED" "$target ($ip)" "protected_range"
        return 1
    fi

    # Warn on public IP (unless unsafe mode)
    if ! is_private_ip "$ip"; then
        if is_unsafe_mode_enabled; then
            log_warning "Target $ip is a PUBLIC IP address (unsafe mode enabled)"
            log_audit "PUBLIC_TARGET" "$target ($ip) for $operation" "allowed_unsafe_mode"
        else
            log_warning "Target $ip is a PUBLIC IP address"
            log_warning "Ensure you have WRITTEN AUTHORIZATION"

            # Use confirm_dangerous() for public IP confirmation
            # This handles non-interactive mode and audit logging internally
            if ! confirm_dangerous "Attack public IP $ip for $operation?" "I HAVE PERMISSION"; then
                log_info "Operation cancelled"
                log_audit "PUBLIC_TARGET" "$target ($ip)" "user_cancelled"
                return 1
            fi
            log_audit "PUBLIC_TARGET" "$target ($ip) for $operation" "user_confirmed"
        fi
    fi

    # Target passed validation
    log_audit "TARGET_VALIDATED" "$target ($ip) for $operation" "success"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Privilege checks
export -f check_root

# Authorization
export -f check_authorization reset_authorization

# IP validation
export -f is_valid_ip is_private_ip is_valid_cidr is_dangerous_range is_protected_ip

# Target validation
export -f validate_target

# Unsafe mode
export -f is_unsafe_mode_enabled is_unsafe_mode check_unsafe_mode require_unsafe_mode

# Internal helpers (exported for testing)
export -f _ip_to_int _ip_in_cidr

# Export variables
export AUTHORIZATION_FILE
