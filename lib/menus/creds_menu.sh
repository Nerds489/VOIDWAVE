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
# Credentials Menu: password attacks, hash cracking, wordlist generation
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_CREDS_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_CREDS_MENU_LOADED=1

show_creds_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Credential Attacks${C_RESET:-}"
        echo ""
        echo "    1) Hydra Brute Force"
        echo "    2) Hashcat Cracking"
        echo "    3) John the Ripper"
        echo "    4) Hash Identifier"
        echo "    5) Password List Generator"
        echo "    6) Extract Hashes from File"
        echo "    0) Back"
        echo ""

        local choice
        read -rp "    Select [0-6]: " choice

        case "$choice" in
            1) _creds_hydra ;;
            2) _creds_hashcat ;;
            3) _creds_john ;;
            4) _creds_identify ;;
            5) _creds_wordlist ;;
            6) _creds_extract ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_get_default_port() {
    case "$1" in
        ssh|SSH) echo "22" ;;
        ftp|FTP) echo "21" ;;
        http|HTTP) echo "80" ;;
        https|HTTPS) echo "443" ;;
        smb|SMB) echo "445" ;;
        rdp|RDP) echo "3389" ;;
        mysql|MySQL) echo "3306" ;;
        postgres|PostgreSQL) echo "5432" ;;
        vnc|VNC) echo "5900" ;;
        telnet|Telnet) echo "23" ;;
        *) echo "" ;;
    esac
}

_creds_hydra() {
    echo ""

    if ! command -v hydra &>/dev/null; then
        echo -e "    ${C_RED:-}hydra not found${C_RESET:-}"
        echo "    Install: apt install hydra"
        wait_for_keypress
        return 1
    fi

    local target service port user passlist threads

    read -rp "    Target IP/Host: " target
    [[ -z "$target" ]] && return

    echo ""
    echo "    1) SSH       5) RDP"
    echo "    2) FTP       6) MySQL"
    echo "    3) HTTP      7) PostgreSQL"
    echo "    4) SMB       8) VNC"
    echo ""

    local svc_choice
    read -rp "    Service [1-8]: " svc_choice

    case "$svc_choice" in
        1) service="ssh" ;;
        2) service="ftp" ;;
        3) service="http-get" ;;
        4) service="smb" ;;
        5) service="rdp" ;;
        6) service="mysql" ;;
        7) service="postgres" ;;
        8) service="vnc" ;;
        *) return ;;
    esac

    local default_port
    default_port=$(_get_default_port "$service")

    read -rp "    Port [$default_port]: " port
    port="${port:-$default_port}"

    read -rp "    Username (or file with -L): " user
    [[ -z "$user" ]] && return

    read -rp "    Password list [/usr/share/wordlists/rockyou.txt]: " passlist
    passlist="${passlist:-/usr/share/wordlists/rockyou.txt}"

    if [[ ! -f "$passlist" ]] && [[ ! "$passlist" =~ ^- ]]; then
        echo -e "    ${C_RED:-}Password list not found${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    read -rp "    Threads [16]: " threads
    threads="${threads:-16}"

    echo ""
    confirm "Start brute force against $target?" || return

    echo ""
    echo -e "    ${C_CYAN:-}Running hydra${C_RESET:-}"
    echo -e "    ${C_GRAY:-}hydra -l $user -P $passlist -t $threads -s $port $target $service${C_RESET:-}"
    echo ""

    local user_flag="-l"
    [[ "$user" =~ ^-L ]] && user_flag="" && user="${user#-L }"
    [[ -f "$user" ]] && user_flag="-L"

    # shellcheck disable=SC2086
    hydra $user_flag "$user" -P "$passlist" -t "$threads" -s "$port" "$target" "$service" 2>&1 | sed 's/^/    /' || true

    wait_for_keypress
}

_creds_hashcat() {
    echo ""

    if ! command -v hashcat &>/dev/null; then
        echo -e "    ${C_RED:-}hashcat not found${C_RESET:-}"
        echo "    Install: apt install hashcat"
        wait_for_keypress
        return 1
    fi

    local hashfile wordlist mode

    read -rp "    Hash file path: " hashfile
    [[ -z "$hashfile" || ! -f "$hashfile" ]] && { echo -e "    ${C_RED:-}File not found${C_RESET:-}"; wait_for_keypress; return; }

    # Show sample
    echo ""
    echo -e "    ${C_GRAY:-}Sample: $(head -c 60 "$hashfile")...${C_RESET:-}"
    echo ""

    echo "    Common modes:"
    echo "      0    = MD5"
    echo "      100  = SHA1"
    echo "      1400 = SHA256"
    echo "      1800 = SHA512crypt"
    echo "      3200 = bcrypt"
    echo "      1000 = NTLM"
    echo "      5600 = NetNTLMv2"
    echo ""

    read -rp "    Hash mode: " mode
    [[ -z "$mode" ]] && return

    read -rp "    Wordlist [/usr/share/wordlists/rockyou.txt]: " wordlist
    wordlist="${wordlist:-/usr/share/wordlists/rockyou.txt}"

    echo ""
    echo "    1) Dictionary attack"
    echo "    2) Dictionary + rules"
    echo "    3) Brute force (slow)"
    echo ""

    local attack
    read -rp "    Attack [1-3]: " attack

    local opts="-m $mode"
    case "$attack" in
        1) opts="$opts -a 0" ;;
        2) opts="$opts -a 0 -r /usr/share/hashcat/rules/best64.rule" ;;
        3) opts="$opts -a 3 ?a?a?a?a?a?a" ;;
        *) return ;;
    esac

    echo ""
    echo -e "    ${C_CYAN:-}Running hashcat${C_RESET:-}"
    echo ""

    # shellcheck disable=SC2086
    hashcat $opts "$hashfile" "$wordlist" 2>&1 | sed 's/^/    /' || true

    wait_for_keypress
}

_creds_john() {
    echo ""

    if ! command -v john &>/dev/null; then
        echo -e "    ${C_RED:-}john not found${C_RESET:-}"
        echo "    Install: apt install john"
        wait_for_keypress
        return 1
    fi

    local hashfile wordlist

    read -rp "    Hash file path: " hashfile
    [[ -z "$hashfile" || ! -f "$hashfile" ]] && { echo -e "    ${C_RED:-}File not found${C_RESET:-}"; wait_for_keypress; return; }

    echo ""
    echo "    1) Auto-detect format"
    echo "    2) Show cracked passwords"
    echo "    3) Wordlist attack"
    echo ""

    local mode
    read -rp "    Select [1-3]: " mode

    echo ""
    echo -e "    ${C_CYAN:-}Running john${C_RESET:-}"
    echo ""

    case "$mode" in
        1) john "$hashfile" 2>&1 | sed 's/^/    /' ;;
        2) john --show "$hashfile" 2>&1 | sed 's/^/    /' ;;
        3)
            read -rp "    Wordlist [/usr/share/wordlists/rockyou.txt]: " wordlist
            wordlist="${wordlist:-/usr/share/wordlists/rockyou.txt}"
            john --wordlist="$wordlist" "$hashfile" 2>&1 | sed 's/^/    /'
            ;;
        *) return ;;
    esac

    wait_for_keypress
}

_creds_identify() {
    echo ""

    local hash
    read -rp "    Enter hash: " hash
    [[ -z "$hash" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}Identifying hash${C_RESET:-}"
    echo ""

    local len=${#hash}

    echo "    Length: $len characters"
    echo ""
    echo "    Possible types:"

    case "$len" in
        32)
            echo "    - MD5"
            echo "    - NTLM"
            echo "    - MD4"
            ;;
        40)
            echo "    - SHA1"
            echo "    - MySQL5"
            ;;
        64)
            echo "    - SHA256"
            echo "    - SHA3-256"
            ;;
        128)
            echo "    - SHA512"
            echo "    - SHA3-512"
            ;;
        *)
            if [[ "$hash" =~ ^\$2[aby]?\$ ]]; then
                echo "    - bcrypt"
            elif [[ "$hash" =~ ^\$6\$ ]]; then
                echo "    - SHA512crypt"
            elif [[ "$hash" =~ ^\$5\$ ]]; then
                echo "    - SHA256crypt"
            elif [[ "$hash" =~ ^\$1\$ ]]; then
                echo "    - MD5crypt"
            else
                echo "    - Unknown format"
            fi
            ;;
    esac

    # Try hashid if available
    if command -v hashid &>/dev/null; then
        echo ""
        echo -e "    ${C_GRAY:-}hashid output:${C_RESET:-}"
        echo "$hash" | hashid 2>/dev/null | head -10 | sed 's/^/    /'
    fi

    wait_for_keypress
}

_creds_wordlist() {
    echo ""

    local base outfile

    read -rp "    Base word (e.g., company name): " base
    [[ -z "$base" ]] && return

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/wordlists"
    mkdir -p "$outdir"
    outfile="$outdir/${base}_wordlist.txt"

    echo ""
    echo -e "    ${C_CYAN:-}Generating wordlist for: $base${C_RESET:-}"
    echo ""

    {
        # Base variations
        echo "$base"
        echo "${base^}"
        echo "${base^^}"
        echo "${base,,}"

        # Common suffixes
        for suffix in 1 12 123 1234 12345 ! @ '#' 2023 2024 2025; do
            echo "${base}${suffix}"
            echo "${base^}${suffix}"
        done

        # Leet speak
        local leet="${base//a/4}"
        leet="${leet//e/3}"
        leet="${leet//i/1}"
        leet="${leet//o/0}"
        leet="${leet//s/5}"
        echo "$leet"

        # Common patterns
        echo "${base}@123"
        echo "${base}#123"
        echo "${base}!@#"
        echo "P@ss${base}123"

    } > "$outfile"

    local count
    count=$(wc -l < "$outfile")

    echo -e "    ${C_GREEN:-}Generated $count passwords${C_RESET:-}"
    echo -e "    ${C_GREEN:-}Saved: $outfile${C_RESET:-}"

    wait_for_keypress
}

_creds_extract() {
    echo ""

    local infile
    read -rp "    Input file (shadow, SAM dump, etc.): " infile
    [[ -z "$infile" || ! -f "$infile" ]] && { echo -e "    ${C_RED:-}File not found${C_RESET:-}"; wait_for_keypress; return; }

    echo ""
    echo "    1) Linux shadow file"
    echo "    2) Windows SAM (pwdump format)"
    echo "    3) Raw hash extraction"
    echo ""

    local ftype
    read -rp "    File type [1-3]: " ftype

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/hashes"
    mkdir -p "$outdir"
    local outfile="$outdir/extracted_$(date +%Y%m%d_%H%M%S).txt"

    echo ""

    case "$ftype" in
        1)
            # Extract hashes from shadow
            awk -F: '$2 ~ /^\$/ {print $1":"$2}' "$infile" > "$outfile"
            ;;
        2)
            # Already in usable format
            grep -E '^[^:]+:[0-9]+:' "$infile" > "$outfile"
            ;;
        3)
            # Extract anything that looks like a hash
            grep -oE '[a-fA-F0-9]{32,128}|\$[0-9a-z]+\$[^\s:]+' "$infile" > "$outfile"
            ;;
        *) return ;;
    esac

    local count
    count=$(wc -l < "$outfile")

    echo -e "    ${C_GREEN:-}Extracted $count hashes${C_RESET:-}"
    echo -e "    ${C_GREEN:-}Saved: $outfile${C_RESET:-}"

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_creds_menu _get_default_port
export -f _creds_hydra _creds_hashcat _creds_john
export -f _creds_identify _creds_wordlist _creds_extract
