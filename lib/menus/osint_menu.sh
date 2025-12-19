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
# OSINT Menu: open source intelligence gathering
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_OSINT_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_OSINT_MENU_LOADED=1

show_osint_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}OSINT${C_RESET:-}"
        echo ""
        echo "    1) theHarvester"
        echo "    2) Shodan Search"
        echo "    3) Google Dorking"
        echo "    4) Social Media Lookup"
        echo "    5) IP Reputation Check"
        echo "    6) Domain Investigation"
        echo "    7) Full OSINT Report"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-7]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _osint_harvester ;;
            2) _osint_shodan ;;
            3) _osint_dorks ;;
            4) _osint_social ;;
            5) _osint_reputation ;;
            6) _osint_domain ;;
            7) _osint_full ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_osint_harvester() {
    echo ""

    local harvester_cmd=""
    if command -v theHarvester &>/dev/null; then
        harvester_cmd="theHarvester"
    elif command -v theharvester &>/dev/null; then
        harvester_cmd="theharvester"
    else
        echo -e "    ${C_RED:-}theHarvester not found${C_RESET:-}"
        echo "    Install: apt install theharvester"
        wait_for_keypress
        return 1
    fi

    local domain
    read -rp "    Target domain: " domain
    [[ -z "$domain" ]] && return

    echo ""
    echo "    Data sources:"
    echo "    1) Quick (google, bing)"
    echo "    2) Standard (google, bing, linkedin, twitter)"
    echo "    3) Full (all sources)"
    echo ""

    local sources
    read -rp "    Select [1-3]: " sources

    case "$sources" in
        1) sources="google,bing" ;;
        2) sources="google,bing,linkedin,twitter" ;;
        3) sources="all" ;;
        *) return ;;
    esac

    echo ""
    echo -e "    ${C_CYAN:-}Running theHarvester${C_RESET:-}"
    echo ""

    $harvester_cmd -d "$domain" -b "$sources" -l 200 2>&1 | sed 's/^/    /' || true

    wait_for_keypress
}

_osint_shodan() {
    echo ""

    # Check for API key
    local api_key="${SHODAN_API_KEY:-}"

    if [[ -z "$api_key" ]]; then
        echo -e "    ${C_YELLOW:-}Shodan API key not set${C_RESET:-}"
        read -rsp "    Enter API key (hidden): " api_key
        echo ""
        [[ -z "$api_key" ]] && return
    fi

    echo ""
    echo "    1) IP Lookup"
    echo "    2) Domain Search"
    echo "    3) Query Search"
    echo ""

    local mode
    read -rp "    Select [1-3]: " mode

    local query endpoint

    case "$mode" in
        1)
            read -rp "    IP Address: " query
            endpoint="https://api.shodan.io/shodan/host/${query}?key=${api_key}"
            ;;
        2)
            read -rp "    Domain: " query
            endpoint="https://api.shodan.io/dns/domain/${query}?key=${api_key}"
            ;;
        3)
            read -rp "    Search query: " query
            local encoded
            encoded=$(echo "$query" | sed 's/ /%20/g')
            endpoint="https://api.shodan.io/shodan/host/search?key=${api_key}&query=${encoded}"
            ;;
        *) return ;;
    esac

    [[ -z "$query" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}Querying Shodan${C_RESET:-}"
    echo ""

    if command -v jq &>/dev/null; then
        curl -s "$endpoint" 2>/dev/null | jq '.' | head -100 | sed 's/^/    /'
    else
        curl -s "$endpoint" 2>/dev/null | head -100 | sed 's/^/    /'
    fi

    wait_for_keypress
}

_osint_dorks() {
    echo ""

    local domain
    read -rp "    Target domain: " domain
    [[ -z "$domain" ]] && return

    echo ""
    echo "    1) Sensitive files"
    echo "    2) Login pages"
    echo "    3) Config files"
    echo "    4) Database files"
    echo "    5) Error messages"
    echo "    6) All of above"
    echo ""

    local category
    read -rp "    Category [1-6]: " category

    local -a dorks=()

    case "$category" in
        1) dorks=("filetype:pdf" "filetype:doc" "filetype:xls" "filetype:sql" "filetype:log") ;;
        2) dorks=("inurl:login" "inurl:admin" "inurl:signin" "intitle:login" "inurl:wp-admin") ;;
        3) dorks=("filetype:conf" "filetype:cfg" "filetype:ini" "filetype:env" "filetype:yml") ;;
        4) dorks=("filetype:sql" "filetype:db" "filetype:mdb" "filetype:sqlite" "inurl:phpmyadmin") ;;
        5) dorks=("intitle:error" "intext:sql syntax" "intext:warning" "filetype:log") ;;
        6) dorks=("filetype:pdf" "inurl:login" "filetype:conf" "filetype:sql" "intitle:error") ;;
        *) return ;;
    esac

    echo ""
    echo -e "    ${C_CYAN:-}Google Dorks for $domain:${C_RESET:-}"
    echo ""

    for dork in "${dorks[@]}"; do
        echo "    site:$domain $dork"
        echo "    https://www.google.com/search?q=site:${domain}+${dork}"
        echo ""
    done

    if confirm "Open in browser?"; then
        for dork in "${dorks[@]}"; do
            xdg-open "https://www.google.com/search?q=site:${domain}+${dork}" &>/dev/null &
            sleep 2
        done
        disown
    fi

    wait_for_keypress
}

_osint_social() {
    echo ""

    local username
    read -rp "    Username to search: " username
    [[ -z "$username" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}Social media links for: $username${C_RESET:-}"
    echo ""

    local -a platforms=(
        "Twitter|https://twitter.com/$username"
        "GitHub|https://github.com/$username"
        "LinkedIn|https://linkedin.com/in/$username"
        "Instagram|https://instagram.com/$username"
        "Facebook|https://facebook.com/$username"
        "Reddit|https://reddit.com/user/$username"
        "TikTok|https://tiktok.com/@$username"
        "YouTube|https://youtube.com/@$username"
    )

    for platform in "${platforms[@]}"; do
        local name="${platform%%|*}"
        local url="${platform##*|}"

        # Check if profile exists
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

        if [[ "$status" == "200" ]]; then
            echo -e "    ${C_GREEN:-}[+]${C_RESET:-} $name: $url"
        else
            echo -e "    ${C_GRAY:-}[-] $name: not found${C_RESET:-}"
        fi
    done

    # Check with sherlock if available
    if command -v sherlock &>/dev/null; then
        echo ""
        if confirm "Run Sherlock for full search?"; then
            echo ""
            sherlock "$username" 2>&1 | head -50 | sed 's/^/    /'
        fi
    fi

    wait_for_keypress
}

_osint_reputation() {
    echo ""

    local ip
    read -rp "    IP Address: " ip
    [[ -z "$ip" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}IP Reputation: $ip${C_RESET:-}"
    echo ""

    # AbuseIPDB
    echo -e "    ${C_BOLD:-}AbuseIPDB:${C_RESET:-}"
    echo "    https://www.abuseipdb.com/check/$ip"

    # VirusTotal
    echo ""
    echo -e "    ${C_BOLD:-}VirusTotal:${C_RESET:-}"
    echo "    https://www.virustotal.com/gui/ip-address/$ip"

    # Shodan
    echo ""
    echo -e "    ${C_BOLD:-}Shodan:${C_RESET:-}"
    echo "    https://www.shodan.io/host/$ip"

    # Censys
    echo ""
    echo -e "    ${C_BOLD:-}Censys:${C_RESET:-}"
    echo "    https://search.censys.io/hosts/$ip"

    # Basic checks
    echo ""
    echo -e "    ${C_BOLD:-}Basic Info:${C_RESET:-}"

    if command -v whois &>/dev/null; then
        whois "$ip" 2>/dev/null | grep -Ei "^(orgname|org-name|netname|country|descr):" | head -10 | sed 's/^/    /'
    fi

    wait_for_keypress
}

_osint_domain() {
    echo ""

    local domain
    read -rp "    Domain: " domain
    [[ -z "$domain" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}Domain Investigation: $domain${C_RESET:-}"
    echo ""

    # WHOIS
    echo -e "    ${C_BOLD:-}[1/5] WHOIS${C_RESET:-}"
    if command -v whois &>/dev/null; then
        whois "$domain" 2>/dev/null | grep -Ei "^(registrar|creation|expir|name server|registrant)" | head -10 | sed 's/^/    /'
    fi

    # DNS
    echo ""
    echo -e "    ${C_BOLD:-}[2/5] DNS Records${C_RESET:-}"
    if command -v dig &>/dev/null; then
        echo "    A:  $(dig +short A "$domain" 2>/dev/null | head -1)"
        echo "    MX: $(dig +short MX "$domain" 2>/dev/null | head -1)"
        echo "    NS: $(dig +short NS "$domain" 2>/dev/null | head -1)"
    fi

    # SSL
    echo ""
    echo -e "    ${C_BOLD:-}[3/5] SSL Certificate${C_RESET:-}"
    if command -v openssl &>/dev/null; then
        echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null | sed 's/^/    /'
    fi

    # Headers
    echo ""
    echo -e "    ${C_BOLD:-}[4/5] HTTP Headers${C_RESET:-}"
    curl -sI "https://$domain" 2>/dev/null | head -10 | sed 's/^/    /'

    # Tech detection
    echo ""
    echo -e "    ${C_BOLD:-}[5/5] Technologies${C_RESET:-}"
    if command -v whatweb &>/dev/null; then
        whatweb -q "https://$domain" 2>/dev/null | sed 's/^/    /'
    else
        echo "    (whatweb not installed)"
    fi

    wait_for_keypress
}

_osint_full() {
    echo ""

    local target
    read -rp "    Target (domain): " target
    [[ -z "$target" ]] && return

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/osint_${target}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"

    echo ""
    echo -e "    ${C_CYAN:-}Full OSINT Report: $target${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Output: $outdir${C_RESET:-}"
    echo ""

    echo -e "    ${C_BOLD:-}[1/6] WHOIS...${C_RESET:-}"
    whois "$target" > "$outdir/whois.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[2/6] DNS...${C_RESET:-}"
    dig ANY "$target" > "$outdir/dns.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[3/6] Subdomains...${C_RESET:-}"
    if command -v subfinder &>/dev/null; then
        subfinder -d "$target" -silent > "$outdir/subdomains.txt" 2>/dev/null
    fi

    echo -e "    ${C_BOLD:-}[4/6] SSL...${C_RESET:-}"
    echo | openssl s_client -connect "$target:443" -servername "$target" 2>/dev/null | openssl x509 -noout -text > "$outdir/ssl.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[5/6] Headers...${C_RESET:-}"
    curl -sI "https://$target" > "$outdir/headers.txt" 2>/dev/null

    echo -e "    ${C_BOLD:-}[6/6] Emails...${C_RESET:-}"
    if command -v theHarvester &>/dev/null || command -v theharvester &>/dev/null; then
        local hcmd="theHarvester"
        command -v theharvester &>/dev/null && hcmd="theharvester"
        $hcmd -d "$target" -b google,bing -l 100 > "$outdir/emails.txt" 2>/dev/null
    fi

    echo ""
    echo -e "    ${C_GREEN:-}Report saved: $outdir${C_RESET:-}"

    # Summary
    echo ""
    echo -e "    ${C_BOLD:-}Files:${C_RESET:-}"
    ls -la "$outdir" | sed 's/^/    /'

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_osint_menu
export -f _osint_harvester _osint_shodan _osint_dorks _osint_social
export -f _osint_reputation _osint_domain _osint_full
