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
# OSINT module: open source intelligence gathering tools
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_OSINT_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_OSINT_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"

#═══════════════════════════════════════════════════════════════════════════════
# THEHARVESTER FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run theHarvester for email and subdomain harvesting
# Args: $1 = target domain (optional)
run_theharvester() {
    # Check for either naming convention
    check_tool "theHarvester" || check_tool "theharvester" || {
        log_error "theHarvester not found"
        echo -e "    ${C_SHADOW}Install: apt install theharvester${C_RESET}"
        return 1
    }

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    echo -e "\n    ${C_CYAN}Data sources:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} All sources"
    echo -e "    ${C_GHOST}[2]${C_RESET} Google"
    echo -e "    ${C_GHOST}[3]${C_RESET} Bing"
    echo -e "    ${C_GHOST}[4]${C_RESET} LinkedIn"
    echo -e "    ${C_GHOST}[5]${C_RESET} DNSDumpster"
    echo -e "    ${C_GHOST}[6]${C_RESET} Shodan (requires API)"
    echo -e "    ${C_GHOST}[7]${C_RESET} Custom"
    echo ""

    local choice source
    get_target_input "Choice [1-7]: " choice

    case "$choice" in
        1) source="all" ;;
        2) source="google" ;;
        3) source="bing" ;;
        4) source="linkedin" ;;
        5) source="dnsdumpster" ;;
        6) source="shodan" ;;
        7) get_target_input "Source(s): " source ;;
        *) source="all" ;;
    esac

    operation_header "theHarvester" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "theharvester" "$target ($source)"

    local outfile="${OUTPUT_DIR:-/tmp}/harvester_${target}_$(timestamp_filename)"
    local cmd

    # Determine correct command name
    if command -v theHarvester &>/dev/null; then
        cmd="theHarvester"
    else
        cmd="theharvester"
    fi

    log_info "Running theHarvester on $target"
    log_command_preview "${cmd} -d ${target} -b ${source}"

    $cmd -d "$target" -b "$source" 2>&1 | tee "${outfile}.txt"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: ${outfile}.txt"
    operation_summary "success" "theHarvester" "Duration: $duration"
}

# Run theHarvester with all sources and HTML output
# Args: $1 = target domain
run_theharvester_full() {
    check_tool "theHarvester" || check_tool "theharvester" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    operation_header "theHarvester Full" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "theharvester_full" "$target"

    local outfile="${OUTPUT_DIR:-/tmp}/harvester_full_${target}_$(timestamp_filename)"
    local cmd

    if command -v theHarvester &>/dev/null; then
        cmd="theHarvester"
    else
        cmd="theharvester"
    fi

    log_info "Running comprehensive theHarvester scan on $target"
    log_command_preview "${cmd} -d ${target} -b all -f ${outfile}"

    $cmd -d "$target" -b all -f "$outfile" 2>&1 | tee "${outfile}.txt"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: ${outfile}.txt"
    [[ -f "${outfile}.html" ]] && log_loot "HTML report: ${outfile}.html"
    operation_summary "success" "theHarvester Full" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# RECON-NG FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run recon-ng framework
# Args: none
run_recon_ng() {
    check_tool "recon-ng" || return 1

    operation_header "Recon-ng" "interactive"
    local start_ms=$(date +%s)

    log_audit "OSINT" "recon-ng" "interactive"
    log_info "Launching Recon-ng framework"

    log_command_preview "recon-ng"
    recon-ng

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "Recon-ng" "Duration: $duration"
}

# Run recon-ng with workspace
# Args: $1 = workspace name
run_recon_ng_workspace() {
    check_tool "recon-ng" || return 1

    local workspace="$1"

    if [[ -z "$workspace" ]]; then
        get_target_input "Workspace name: " workspace
    fi

    operation_header "Recon-ng" "workspace: $workspace"
    local start_ms=$(date +%s)

    log_audit "OSINT" "recon-ng" "workspace: $workspace"
    log_info "Launching Recon-ng with workspace: $workspace"

    log_command_preview "recon-ng -w ${workspace}"
    recon-ng -w "$workspace"

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "Recon-ng" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# SHODAN FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run Shodan host lookup
# Args: $1 = target IP/hostname
run_shodan_host() {
    if ! command -v shodan &>/dev/null; then
        log_error "Shodan CLI not found"
        echo -e "    ${C_SHADOW}Install: pip3 install shodan${C_RESET}"
        echo -e "    ${C_SHADOW}Configure: shodan init <YOUR_API_KEY>${C_RESET}"
        return 1
    fi

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    operation_header "Shodan Host" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "shodan_host" "$target"
    log_info "Querying Shodan for $target"

    local outfile="${OUTPUT_DIR:-/tmp}/shodan_host_$(timestamp_filename).txt"

    log_command_preview "shodan host ${target}"
    shodan host "$target" 2>&1 | tee "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Shodan Host" "Duration: $duration"
}

# Run Shodan search
# Args: $1 = search query
run_shodan_search() {
    if ! command -v shodan &>/dev/null; then
        log_error "Shodan CLI not found"
        echo -e "    ${C_SHADOW}Install: pip3 install shodan${C_RESET}"
        return 1
    fi

    local query="$1"

    if [[ -z "$query" ]]; then
        echo -e "\n    ${C_CYAN}Example queries:${C_RESET}"
        echo -e "    ${C_SHADOW}apache country:US          - Apache servers in US${C_RESET}"
        echo -e "    ${C_SHADOW}port:22 org:\"Company\"      - SSH on specific org${C_RESET}"
        echo -e "    ${C_SHADOW}vuln:CVE-2021-44228        - Log4j vulnerable${C_RESET}"
        echo -e "    ${C_SHADOW}ssl.cert.subject.cn:target - SSL cert matching${C_RESET}"
        echo ""
        get_target_input "Search query: " query
    fi

    operation_header "Shodan Search" "$query"
    local start_ms=$(date +%s)

    log_audit "OSINT" "shodan_search" "$query"
    log_info "Searching Shodan: $query"

    local outfile="${OUTPUT_DIR:-/tmp}/shodan_search_$(timestamp_filename).txt"

    log_command_preview "shodan search \"${query}\""
    shodan search "$query" 2>&1 | tee "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Shodan Search" "Duration: $duration"
}

# Run Shodan domain lookup
# Args: $1 = domain
run_shodan_domain() {
    if ! command -v shodan &>/dev/null; then
        log_error "Shodan CLI not found"
        return 1
    fi

    local domain="$1"

    if [[ -z "$domain" ]]; then
        get_target_input "Domain: " domain
    fi

    operation_header "Shodan Domain" "$domain"
    local start_ms=$(date +%s)

    log_audit "OSINT" "shodan_domain" "$domain"
    log_info "Querying Shodan for domain: $domain"

    local outfile="${OUTPUT_DIR:-/tmp}/shodan_domain_$(timestamp_filename).txt"

    log_command_preview "shodan domain ${domain}"
    shodan domain "$domain" 2>&1 | tee "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Shodan Domain" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# WHOIS / DNS FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run WHOIS lookup with caching and formatted output
# Args: $1 = target domain/IP
# Returns: 0 on success, 1 on failure
run_whois() {
    local target="$1"
    local cache_ttl=86400  # 24 hours in seconds

    # Validate input
    if [[ -z "$target" ]]; then
        log_error "No target specified"
        return 1
    fi

    # Require whois tool
    require_tools whois || return 1

    # Helper function: get file modification time (cross-platform)
    _get_mtime() {
        local file="$1"
        local mtime=""

        # Try Linux stat first
        if mtime=$(stat -c %Y "$file" 2>/dev/null); then
            echo "$mtime"
            return 0
        fi

        # Try BSD/macOS stat
        if mtime=$(stat -f %m "$file" 2>/dev/null); then
            echo "$mtime"
            return 0
        fi

        # Fallback: return 0 (treat as expired)
        echo "0"
        return 0
    }

    # Determine cache directory
    local cache_dir=""
    if [[ -n "${VOIDWAVE_STATE_DIR:-}" ]]; then
        cache_dir="${VOIDWAVE_STATE_DIR}/cache/whois"
    elif [[ -n "${VOIDWAVE_HOME:-}" ]]; then
        cache_dir="${VOIDWAVE_HOME}/cache/whois"
    else
        cache_dir="${HOME}/.voidwave/cache/whois"
    fi

    # Create cache directory
    if declare -f ensure_dir &>/dev/null; then
        ensure_dir "$cache_dir"
    else
        mkdir -p "$cache_dir" 2>/dev/null
    fi

    # Sanitize target for filename (replace unsafe chars with _)
    local safe_target="${target//\//_}"
    safe_target="${safe_target// /_}"
    safe_target="${safe_target//[^a-zA-Z0-9._-]/_}"
    local cache_file="${cache_dir}/${safe_target}.txt"

    # Check cache
    if [[ -f "$cache_file" ]]; then
        local now=$(date +%s)
        local file_mtime=$(_get_mtime "$cache_file")
        local age=$((now - file_mtime))

        if [[ $age -lt $cache_ttl ]]; then
            # Cache hit - return cached content
            draw_header "WHOIS: $target (cached)"

            # Extract and display key fields from cache
            local registrar org country
            registrar=$(grep -iE "^Registrar:" "$cache_file" | head -1 | cut -d: -f2- | xargs)
            org=$(grep -iE "^(Organization|Org):" "$cache_file" | head -1 | cut -d: -f2- | xargs)
            country=$(grep -iE "^Country:" "$cache_file" | head -1 | cut -d: -f2- | xargs)

            [[ -n "$registrar" ]] && echo -e "    ${C_CYAN}Registrar:${C_RESET}    $registrar"
            [[ -n "$org" ]] && echo -e "    ${C_CYAN}Organization:${C_RESET} $org"
            [[ -n "$country" ]] && echo -e "    ${C_CYAN}Country:${C_RESET}      $country"
            echo ""

            # Audit logging (guarded)
            if declare -f log_audit &>/dev/null; then
                log_audit "WHOIS" "$target" "cache_hit"
            fi

            # Interactive: offer to view raw output
            if [[ "${VW_NON_INTERACTIVE:-0}" != "1" ]]; then
                if confirm "View raw output?" "n"; then
                    cat "$cache_file"
                fi
            fi

            return 0
        fi
    fi

    # Cache miss or expired - run whois
    log_info "WHOIS lookup: $target..."

    local output
    if ! output=$(whois "$target" 2>&1); then
        log_error "WHOIS lookup failed for $target"
        return 1
    fi

    # Check if output is empty or error
    if [[ -z "$output" ]]; then
        log_error "WHOIS returned empty response"
        return 1
    fi

    # Save to cache
    echo "$output" > "$cache_file" 2>/dev/null

    # Display formatted output
    draw_header "WHOIS: $target"

    # Extract and display key fields
    local registrar org country
    registrar=$(echo "$output" | grep -iE "^Registrar:" | head -1 | cut -d: -f2- | xargs)
    org=$(echo "$output" | grep -iE "^(Organization|Org):" | head -1 | cut -d: -f2- | xargs)
    country=$(echo "$output" | grep -iE "^Country:" | head -1 | cut -d: -f2- | xargs)

    [[ -n "$registrar" ]] && echo -e "    ${C_CYAN}Registrar:${C_RESET}    $registrar"
    [[ -n "$org" ]] && echo -e "    ${C_CYAN}Organization:${C_RESET} $org"
    [[ -n "$country" ]] && echo -e "    ${C_CYAN}Country:${C_RESET}      $country"
    echo ""

    # Audit logging (guarded)
    if declare -f log_audit &>/dev/null; then
        log_audit "WHOIS" "$target"
    fi

    # Interactive: offer to view raw output
    if [[ "${VW_NON_INTERACTIVE:-0}" != "1" ]]; then
        if confirm "View raw output?" "n"; then
            echo "$output"
        fi
    fi

    return 0
}

# Run DNS enumeration with dig
# Args: $1 = target domain
run_dns_enum() {
    check_tool "dig" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    operation_header "DNS Enumeration" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "dns_enum" "$target"

    local outfile="${OUTPUT_DIR:-/tmp}/dns_enum_$(timestamp_filename).txt"

    echo -e "\n    ${C_CYAN}=== A Records ===${C_RESET}" | tee "$outfile"
    log_command_preview "dig +short A ${target}"
    dig +short A "$target" | tee -a "$outfile"

    echo -e "\n    ${C_CYAN}=== AAAA Records ===${C_RESET}" | tee -a "$outfile"
    log_command_preview "dig +short AAAA ${target}"
    dig +short AAAA "$target" | tee -a "$outfile"

    echo -e "\n    ${C_CYAN}=== MX Records ===${C_RESET}" | tee -a "$outfile"
    log_command_preview "dig +short MX ${target}"
    dig +short MX "$target" | tee -a "$outfile"

    echo -e "\n    ${C_CYAN}=== NS Records ===${C_RESET}" | tee -a "$outfile"
    log_command_preview "dig +short NS ${target}"
    dig +short NS "$target" | tee -a "$outfile"

    echo -e "\n    ${C_CYAN}=== TXT Records ===${C_RESET}" | tee -a "$outfile"
    log_command_preview "dig +short TXT ${target}"
    dig +short TXT "$target" | tee -a "$outfile"

    echo -e "\n    ${C_CYAN}=== SOA Record ===${C_RESET}" | tee -a "$outfile"
    log_command_preview "dig +short SOA ${target}"
    dig +short SOA "$target" | tee -a "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "DNS Enum" "Duration: $duration"
}

# Run reverse DNS lookup
# Args: $1 = IP address
run_reverse_dns() {
    check_tool "dig" || return 1

    local ip="$1"

    if [[ -z "$ip" ]]; then
        get_target_input "IP address: " ip
    fi

    operation_header "Reverse DNS" "$ip"
    local start_ms=$(date +%s)

    log_audit "OSINT" "reverse_dns" "$ip"

    log_command_preview "dig -x ${ip} +short"
    dig -x "$ip" +short

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "Reverse DNS" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# SUBDOMAIN ENUMERATION
#═══════════════════════════════════════════════════════════════════════════════

# Run Amass for subdomain enumeration
# Args: $1 = target domain
run_amass() {
    check_tool "amass" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    echo -e "\n    ${C_CYAN}Amass mode:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Passive (fast, no direct contact)"
    echo -e "    ${C_GHOST}[2]${C_RESET} Active (thorough, contacts target)"
    echo ""

    local choice mode
    get_target_input "Choice [1-2]: " choice

    case "$choice" in
        1) mode="passive" ;;
        2) mode="active" ;;
        *) mode="passive" ;;
    esac

    operation_header "Amass" "$target ($mode)"
    local start_ms=$(date +%s)

    log_audit "OSINT" "amass" "$target ($mode)"

    local outfile="${OUTPUT_DIR:-/tmp}/amass_${target}_$(timestamp_filename).txt"

    if [[ "$mode" == "passive" ]]; then
        log_command_preview "amass enum -passive -d ${target} -o ${outfile}"
        amass enum -passive -d "$target" -o "$outfile"
    else
        log_command_preview "amass enum -active -d ${target} -o ${outfile}"
        amass enum -active -d "$target" -o "$outfile"
    fi

    local count=$(wc -l < "$outfile" 2>/dev/null || echo "0")
    local duration=$(elapsed_time "$start_ms")
    log_loot "Found $count subdomains: $outfile"
    operation_summary "success" "Amass" "Duration: $duration"
}

# Run Subfinder for subdomain enumeration
# Args: $1 = target domain
run_subfinder() {
    check_tool "subfinder" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    operation_header "Subfinder" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "subfinder" "$target"

    local outfile="${OUTPUT_DIR:-/tmp}/subfinder_${target}_$(timestamp_filename).txt"

    log_command_preview "subfinder -d ${target} -o ${outfile}"
    subfinder -d "$target" -o "$outfile"

    local count=$(wc -l < "$outfile" 2>/dev/null || echo "0")
    local duration=$(elapsed_time "$start_ms")
    log_loot "Found $count subdomains: $outfile"
    operation_summary "success" "Subfinder" "Duration: $duration"
}

# Run Sublist3r for subdomain enumeration
# Args: $1 = target domain
run_sublist3r() {
    check_tool "sublist3r" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    operation_header "Sublist3r" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "sublist3r" "$target"

    local outfile="${OUTPUT_DIR:-/tmp}/sublist3r_${target}_$(timestamp_filename).txt"

    log_command_preview "sublist3r -d ${target} -o ${outfile}"
    sublist3r -d "$target" -o "$outfile"

    local count=$(wc -l < "$outfile" 2>/dev/null || echo "0")
    local duration=$(elapsed_time "$start_ms")
    log_loot "Found $count subdomains: $outfile"
    operation_summary "success" "Sublist3r" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# GOOGLE DORKING / WEB OSINT
#═══════════════════════════════════════════════════════════════════════════════

# Generate Google dorks for a domain
# Args: $1 = target domain
generate_dorks() {
    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target domain: " target
    fi

    operation_header "Google Dorks" "$target"
    local start_ms=$(date +%s)

    log_audit "OSINT" "dorks" "$target"

    local outfile="${OUTPUT_DIR:-/tmp}/dorks_${target}_$(timestamp_filename).txt"

    echo -e "\n    ${C_CYAN}=== Generated Google Dorks ===${C_RESET}\n" | tee "$outfile"

    # File discovery
    echo -e "    ${C_SHADOW}=== File Discovery ===${C_RESET}" | tee -a "$outfile"
    echo "site:${target} filetype:pdf" | tee -a "$outfile"
    echo "site:${target} filetype:doc OR filetype:docx" | tee -a "$outfile"
    echo "site:${target} filetype:xls OR filetype:xlsx" | tee -a "$outfile"
    echo "site:${target} filetype:sql OR filetype:db" | tee -a "$outfile"
    echo "site:${target} filetype:log" | tee -a "$outfile"
    echo "site:${target} filetype:bak OR filetype:backup" | tee -a "$outfile"
    echo "site:${target} filetype:conf OR filetype:config" | tee -a "$outfile"

    # Sensitive directories
    echo -e "\n    ${C_SHADOW}=== Sensitive Directories ===${C_RESET}" | tee -a "$outfile"
    echo "site:${target} inurl:admin" | tee -a "$outfile"
    echo "site:${target} inurl:login" | tee -a "$outfile"
    echo "site:${target} inurl:wp-admin" | tee -a "$outfile"
    echo "site:${target} inurl:phpmyadmin" | tee -a "$outfile"
    echo "site:${target} inurl:backup" | tee -a "$outfile"

    # Exposed information
    echo -e "\n    ${C_SHADOW}=== Exposed Information ===${C_RESET}" | tee -a "$outfile"
    echo "site:${target} \"index of /\"" | tee -a "$outfile"
    echo "site:${target} intitle:\"Index of\"" | tee -a "$outfile"
    echo "site:${target} intext:password" | tee -a "$outfile"
    echo "site:${target} intext:username" | tee -a "$outfile"
    echo "site:${target} \"Error\" OR \"Warning\"" | tee -a "$outfile"

    # Code repositories
    echo -e "\n    ${C_SHADOW}=== Code/Repo Leaks ===${C_RESET}" | tee -a "$outfile"
    echo "site:github.com \"${target}\"" | tee -a "$outfile"
    echo "site:gitlab.com \"${target}\"" | tee -a "$outfile"
    echo "site:pastebin.com \"${target}\"" | tee -a "$outfile"
    echo "site:trello.com \"${target}\"" | tee -a "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Dorks saved: $outfile"
    operation_summary "success" "Google Dorks" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# SOCIAL MEDIA OSINT
#═══════════════════════════════════════════════════════════════════════════════

# Run Sherlock for username search
# Args: $1 = username
run_sherlock() {
    check_tool "sherlock" || return 1

    local username="$1"

    if [[ -z "$username" ]]; then
        get_target_input "Username to search: " username
    fi

    operation_header "Sherlock" "$username"
    local start_ms=$(date +%s)

    log_audit "OSINT" "sherlock" "$username"

    local outfile="${OUTPUT_DIR:-/tmp}/sherlock_${username}_$(timestamp_filename).txt"

    log_command_preview "sherlock ${username} -o ${outfile}"
    sherlock "$username" -o "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Sherlock" "Duration: $duration"
}

# Run Holehe for email account check
# Args: $1 = email address
run_holehe() {
    check_tool "holehe" || return 1

    local email="$1"

    if [[ -z "$email" ]]; then
        get_target_input "Email address: " email
    fi

    operation_header "Holehe" "$email"
    local start_ms=$(date +%s)

    log_audit "OSINT" "holehe" "$email"

    local outfile="${OUTPUT_DIR:-/tmp}/holehe_$(timestamp_filename).txt"

    log_command_preview "holehe ${email}"
    holehe "$email" 2>&1 | tee "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Holehe" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# SPIDERFOOT
#═══════════════════════════════════════════════════════════════════════════════

# Run Spiderfoot web interface
# Args: none
run_spiderfoot() {
    check_tool "spiderfoot" || return 1

    local port
    get_target_input "Web UI port [5001]: " port
    port="${port:-5001}"

    operation_header "SpiderFoot" "port $port"
    local start_ms=$(date +%s)

    log_audit "OSINT" "spiderfoot" "port $port"
    log_info "Starting SpiderFoot web interface"
    echo -e "    ${C_SHADOW}Access: http://localhost:${port}${C_RESET}"

    log_command_preview "spiderfoot -l 127.0.0.1:${port}"
    spiderfoot -l "127.0.0.1:${port}"

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "SpiderFoot" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# MALTEGO
#═══════════════════════════════════════════════════════════════════════════════

# Launch Maltego
# Args: none
run_maltego() {
    check_tool "maltego" || return 1

    operation_header "Maltego" "GUI"
    local start_ms=$(date +%s)

    log_audit "OSINT" "maltego" "GUI"
    log_info "Launching Maltego"

    log_command_preview "maltego"
    maltego &

    operation_summary "success" "Maltego" "Launched in background"
}

#═══════════════════════════════════════════════════════════════════════════════
# OSINT MENU
#═══════════════════════════════════════════════════════════════════════════════

# Main OSINT menu
osint_menu() {
    while true; do
        clear
        echo -e "\n"
        echo -e "    ${C_SKULL}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}                    ${C_FIRE}🔎 OSINT RECONNAISSANCE${C_RESET}                     ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}INFORMATION GATHERING${C_RESET}                                        ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[1]${C_RESET} theHarvester            ${C_SHADOW}Email & subdomain harvesting${C_RESET}    ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[2]${C_RESET} theHarvester (Full)     ${C_SHADOW}Comprehensive scan${C_RESET}              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[3]${C_RESET} Recon-ng                ${C_SHADOW}OSINT framework${C_RESET}                 ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[4]${C_RESET} SpiderFoot              ${C_SHADOW}Automated OSINT${C_RESET}                 ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[5]${C_RESET} Maltego                 ${C_SHADOW}Link analysis GUI${C_RESET}               ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}SHODAN${C_RESET}                                                        ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[6]${C_RESET} Shodan Host             ${C_SHADOW}IP/hostname lookup${C_RESET}              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[7]${C_RESET} Shodan Search           ${C_SHADOW}Custom search query${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[8]${C_RESET} Shodan Domain           ${C_SHADOW}Domain intelligence${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}DNS / WHOIS${C_RESET}                                                   ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[9]${C_RESET} WHOIS Lookup            ${C_SHADOW}Domain registration info${C_RESET}        ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[10]${C_RESET} DNS Enumeration        ${C_SHADOW}All DNS record types${C_RESET}            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[11]${C_RESET} Reverse DNS            ${C_SHADOW}PTR record lookup${C_RESET}               ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}SUBDOMAIN ENUMERATION${C_RESET}                                         ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[12]${C_RESET} Amass                  ${C_SHADOW}OWASP subdomain tool${C_RESET}            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[13]${C_RESET} Subfinder              ${C_SHADOW}Fast passive enumeration${C_RESET}        ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[14]${C_RESET} Sublist3r              ${C_SHADOW}Multi-source enum${C_RESET}               ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}SOCIAL / WEB OSINT${C_RESET}                                            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[15]${C_RESET} Sherlock               ${C_SHADOW}Username search${C_RESET}                 ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[16]${C_RESET} Holehe                 ${C_SHADOW}Email account finder${C_RESET}            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[17]${C_RESET} Google Dorks           ${C_SHADOW}Generate search dorks${C_RESET}           ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_GHOST}[0]${C_RESET} Back"
        echo ""

        local choice
        get_target_input "Select option: " choice

        case "$choice" in
            1) run_theharvester ;;
            2) run_theharvester_full ;;
            3) run_recon_ng ;;
            4) run_spiderfoot ;;
            5) run_maltego ;;
            6) run_shodan_host ;;
            7) run_shodan_search ;;
            8) run_shodan_domain ;;
            9) run_whois ;;
            10) run_dns_enum ;;
            11) run_reverse_dns ;;
            12) run_amass ;;
            13) run_subfinder ;;
            14) run_sublist3r ;;
            15) run_sherlock ;;
            16) run_holehe ;;
            17) generate_dorks ;;
            0|q|Q|back|exit) return 0 ;;
            *) log_warning "Invalid option" ;;
        esac

        echo ""
        read -rp "    Press Enter to continue..."
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# theHarvester functions
export -f run_theharvester run_theharvester_full

# Recon-ng functions
export -f run_recon_ng run_recon_ng_workspace

# Shodan functions
export -f run_shodan_host run_shodan_search run_shodan_domain

# DNS/WHOIS functions
export -f run_whois run_dns_enum run_reverse_dns

# Subdomain functions
export -f run_amass run_subfinder run_sublist3r

# Social OSINT functions
export -f run_sherlock run_holehe generate_dorks

# Framework functions
export -f run_spiderfoot run_maltego

# Menu
export -f osint_menu
