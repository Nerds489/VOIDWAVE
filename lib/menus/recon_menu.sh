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
# Reconnaissance Menu: DNS, subdomains, WHOIS, email harvesting, tech detection
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_RECON_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_RECON_MENU_LOADED=1

show_recon_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Reconnaissance${C_RESET:-}"
        echo ""
        echo "    1) DNS Enumeration"
        echo "    2) Subdomain Discovery"
        echo "    3) WHOIS Lookup"
        echo "    4) Email Harvesting"
        echo "    5) Technology Detection"
        echo "    6) Full Recon Suite"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-6]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _recon_dns ;;
            2) _recon_subdomains ;;
            3) _recon_whois ;;
            4) _recon_emails ;;
            5) _recon_tech ;;
            6) _recon_full ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_recon_dns() {
    echo ""
    local target
    read -rp "    Target domain: " target

    [[ -z "$target" ]] && return
    is_valid_domain "$target" || { echo -e "    ${C_RED:-}Invalid domain${C_RESET:-}"; return; }

    echo ""
    echo -e "    ${C_CYAN:-}DNS Enumeration: $target${C_RESET:-}"
    echo ""

    if command -v dig &>/dev/null; then
        echo -e "    ${C_BOLD:-}A Records:${C_RESET:-}"
        dig +short A "$target" 2>/dev/null | sed 's/^/    /'
        echo ""
        echo -e "    ${C_BOLD:-}MX Records:${C_RESET:-}"
        dig +short MX "$target" 2>/dev/null | sed 's/^/    /'
        echo ""
        echo -e "    ${C_BOLD:-}NS Records:${C_RESET:-}"
        dig +short NS "$target" 2>/dev/null | sed 's/^/    /'
        echo ""
        echo -e "    ${C_BOLD:-}TXT Records:${C_RESET:-}"
        dig +short TXT "$target" 2>/dev/null | sed 's/^/    /'
    elif command -v host &>/dev/null; then
        host "$target" 2>/dev/null | sed 's/^/    /'
    else
        echo -e "    ${C_RED:-}No DNS tools found (dig/host)${C_RESET:-}"
    fi

    wait_for_keypress
}

_recon_subdomains() {
    echo ""
    local target
    read -rp "    Target domain: " target

    [[ -z "$target" ]] && return
    is_valid_domain "$target" || { echo -e "    ${C_RED:-}Invalid domain${C_RESET:-}"; return; }

    echo ""
    echo -e "    ${C_CYAN:-}Subdomain Discovery: $target${C_RESET:-}"
    echo ""

    if command -v subfinder &>/dev/null; then
        subfinder -d "$target" -silent 2>/dev/null | head -20 | sed 's/^/    /'
    elif command -v amass &>/dev/null; then
        timeout 60 amass enum -passive -d "$target" 2>/dev/null | head -20 | sed 's/^/    /'
    else
        echo -e "    ${C_YELLOW:-}No subdomain tools found (subfinder/amass)${C_RESET:-}"
        echo "    Trying DNS brute with common prefixes..."
        echo ""
        for sub in www mail ftp admin api dev staging test; do
            host "${sub}.${target}" 2>/dev/null | grep -q "has address" && echo "    ${sub}.${target}"
        done
    fi

    wait_for_keypress
}

_recon_whois() {
    echo ""
    local target
    read -rp "    Target (domain or IP): " target

    [[ -z "$target" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}WHOIS: $target${C_RESET:-}"
    echo ""

    if command -v whois &>/dev/null; then
        whois "$target" 2>/dev/null | head -50 | sed 's/^/    /'
    else
        echo -e "    ${C_RED:-}whois not found${C_RESET:-}"
    fi

    wait_for_keypress
}

_recon_emails() {
    echo ""
    local target
    read -rp "    Target domain: " target

    [[ -z "$target" ]] && return
    is_valid_domain "$target" || { echo -e "    ${C_RED:-}Invalid domain${C_RESET:-}"; return; }

    echo ""
    echo -e "    ${C_CYAN:-}Email Harvesting: $target${C_RESET:-}"
    echo ""

    if command -v theHarvester &>/dev/null; then
        theHarvester -d "$target" -b google,bing -l 100 2>/dev/null | grep "@" | head -20 | sed 's/^/    /'
    elif command -v theharvester &>/dev/null; then
        theharvester -d "$target" -b google,bing -l 100 2>/dev/null | grep "@" | head -20 | sed 's/^/    /'
    else
        echo -e "    ${C_YELLOW:-}theHarvester not found${C_RESET:-}"
        echo "    Install: apt install theharvester"
    fi

    wait_for_keypress
}

_recon_tech() {
    echo ""
    local target
    read -rp "    Target URL (https://...): " target

    [[ -z "$target" ]] && return
    [[ ! "$target" =~ ^https?:// ]] && target="https://$target"

    echo ""
    echo -e "    ${C_CYAN:-}Technology Detection: $target${C_RESET:-}"
    echo ""

    if command -v whatweb &>/dev/null; then
        whatweb -a 3 "$target" 2>/dev/null | sed 's/^/    /'
    elif command -v curl &>/dev/null; then
        echo -e "    ${C_BOLD:-}HTTP Headers:${C_RESET:-}"
        curl -sI "$target" 2>/dev/null | head -20 | sed 's/^/    /'
    else
        echo -e "    ${C_RED:-}No tools found (whatweb/curl)${C_RESET:-}"
    fi

    wait_for_keypress
}

_recon_full() {
    echo ""
    local target
    read -rp "    Target domain: " target

    [[ -z "$target" ]] && return
    is_valid_domain "$target" || { echo -e "    ${C_RED:-}Invalid domain${C_RESET:-}"; return; }

    echo ""
    echo -e "    ${C_CYAN:-}Full Recon Suite: $target${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}This may take a few minutes...${C_RESET:-}"
    echo ""

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/recon_${target}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"

    echo -e "    ${C_BOLD:-}[1/4] DNS...${C_RESET:-}"
    dig ANY "$target" > "$outdir/dns.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[2/4] WHOIS...${C_RESET:-}"
    whois "$target" > "$outdir/whois.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[3/4] Subdomains...${C_RESET:-}"
    if command -v subfinder &>/dev/null; then
        subfinder -d "$target" -silent > "$outdir/subdomains.txt" 2>/dev/null
    fi

    echo -e "    ${C_BOLD:-}[4/4] Headers...${C_RESET:-}"
    curl -sI "https://$target" > "$outdir/headers.txt" 2>/dev/null

    echo ""
    echo -e "    ${C_GREEN:-}Results saved: $outdir${C_RESET:-}"

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_recon_menu
export -f _recon_dns _recon_subdomains _recon_whois _recon_emails _recon_tech _recon_full
