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
# UI library: banners, menus, prompts, progress indicators, display functions
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_UI_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_UI_LOADED=1

# Source core library
source "${BASH_SOURCE%/*}/core.sh"

#═══════════════════════════════════════════════════════════════════════════════
# VISUAL EFFECTS
#═══════════════════════════════════════════════════════════════════════════════

typewriter() {
    local text="${1:-}" delay="${2:-0.015}"
    if [[ "$QUIET" == "true" || "$QUIET" == "1" ]]; then
        echo "$text"
        return
    fi
    for ((i=0; i<${#text}; i++)); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

spinner() {
    local pid="${1:-}" msg="${2:-Processing}"
    [[ -z "$pid" ]] && return 1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    ${C_GHOST}%s${C_RESET} %s..." "${frames[$i]}" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.08
    done
    printf "\r    ${C_VENOM}✓${C_RESET} %s      \n" "$msg"
    tput cnorm 2>/dev/null || true
}

progress_bar() {
    local current="${1:-0}" total="${2:-1}" width=40 label="${3:-}"
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf '\r    %s[%s' "$C_SHADOW" "$C_RESET"
    printf '%s%*s%s' "$C_VENOM" "$filled" "" "$C_RESET" | tr ' ' '█'
    printf '%s%*s%s' "$C_SHADOW" "$empty" "" "$C_RESET" | tr ' ' '░'
    printf '%s]%s %s%3d%%%s' "$C_SHADOW" "$C_RESET" "$C_SKULL" "$pct" "$C_RESET"
    [[ -n "$label" ]] && printf ' %s%s%s' "$C_DIM" "$label" "$C_RESET"
}

draw_line() {
    local char="${1:-─}" width="${2:-70}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

draw_header() {
    local title="${1:-}" color="${2:-$C_CYAN}"
    local width=70
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    local right_padding=$(( width - padding - title_len ))

    echo -e "    ${color}╔$(printf '═%.0s' $(seq 1 $width))╗${C_RESET}"
    echo -e "    ${color}║$(printf ' %.0s' $(seq 1 $padding))${C_BOLD}${title}${C_RESET}${color}$(printf ' %.0s' $(seq 1 $right_padding))║${C_RESET}"
    echo -e "    ${color}╚$(printf '═%.0s' $(seq 1 $width))╝${C_RESET}"
}

#═══════════════════════════════════════════════════════════════════════════════
# PROGRESS INDICATORS
#═══════════════════════════════════════════════════════════════════════════════

# Show animated spinner while a background process runs
# Args: $1 = PID to wait for, $2 = message to display
show_spinner() {
    local pid="$1"
    local message="${2:-Working...}"
    local spinner_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    # Hide cursor if possible
    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r ${C_CYAN}[%s]${C_RESET} %s" "${spinner_chars:$i:1}" "$message"
        i=$(( (i + 1) % ${#spinner_chars} ))
        sleep 0.1
    done

    # Restore cursor
    tput cnorm 2>/dev/null || true
    printf "\r ${C_GREEN}[✓]${C_RESET} %s\n" "$message"
}

# Run a command with spinner display
# Args: $1 = message, $2... = command and arguments
run_with_spinner() {
    local message="$1"
    shift

    # Run the command in the background, redirecting its output (spinner is visual only)
    "$@" &>/dev/null &
    local cmd_pid=$!

    show_spinner "$cmd_pid" "$message"
    wait "$cmd_pid"
    return $?
}

# Show a progress bar for iterative operations
# Args: $1 = current, $2 = total, $3 = label (optional), $4 = width (optional)
show_progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-Progress}"
    local width="${4:-40}"

    (( total <= 0 )) && total=1

    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar=""

    local i
    for (( i=0; i<filled; i++ )); do
        bar+="█"
    done
    for (( i=0; i<empty; i++ )); do
        bar+="░"
    done

    printf "\r ${C_CYAN}%s:${C_RESET} [%s] %3d%%" "$label" "$bar" "$percent"

    if (( current >= total )); then
        echo
    fi
}

# Simple timers backed by an associative array
declare -gA _TIMERS

# Start a named timer
# Args: $1 = timer name (default: "default")
start_timer() {
    local name="${1:-default}"
    _TIMERS["$name"]="$(date +%s.%N)"
}

# Stop a timer and return elapsed time as formatted string
# Args: $1 = timer name (default: "default")
# Returns: formatted elapsed time string via stdout
stop_timer() {
    local name="${1:-default}"
    local start="${_TIMERS[$name]:-}"

    [[ -z "$start" ]] && return 1

    local now elapsed
    now="$(date +%s.%N)"

    # Use bc if available for sub-second precision; fall back to integer seconds
    if command -v bc &>/dev/null; then
        elapsed="$(printf '%s - %s\n' "$now" "$start" | bc -l)"
    else
        elapsed=$(( ${now%.*} - ${start%.*} ))
    fi

    unset "_TIMERS[$name]"

    # Pretty-print elapsed time
    if command -v bc &>/dev/null && [[ "$elapsed" == *.* ]]; then
        if (( $(printf '%s > 60\n' "$elapsed" | bc -l) )); then
            local minutes seconds
            minutes="$(printf '%s / 60\n' "$elapsed" | bc)"
            seconds="$(printf '%s %% 60\n' "$elapsed" | bc)"
            printf '%sm %ss' "$minutes" "$seconds"
        else
            printf '%.2fs' "$elapsed"
        fi
    else
        # Integer seconds
        if (( elapsed > 60 )); then
            local minutes=$(( elapsed / 60 ))
            local seconds=$(( elapsed % 60 ))
            printf '%dm %ds' "$minutes" "$seconds"
        else
            printf '%ds' "$elapsed"
        fi
    fi
}

# Run a command and log its duration
# Args: $1 = label for logging, $2... = command and arguments
# Returns: exit status of the command
timed_run() {
    local label="$1"
    shift

    start_timer "$label"
    "$@"
    local status=$?

    local duration
    duration="$(stop_timer "$label" 2>/dev/null || echo '?')"
    log_info "$label completed in $duration"

    return $status
}

# Display countdown before an operation
# Args: $1 = seconds to count down, $2 = message (optional)
countdown() {
    local seconds="$1"
    local message="${2:-Starting in}"

    local i
    for (( i=seconds; i>0; i-- )); do
        printf "\r ${C_YELLOW}%s %d...${C_RESET}" "$message" "$i"
        sleep 1
    done

    printf "\r ${C_GREEN}%s GO!${C_RESET}     \n" "$message"
}

#═══════════════════════════════════════════════════════════════════════════════
# SCREEN CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Cache terminal clear capability (set once at source time for performance)
# Values: 1=can clear, 0=cannot clear, ""=not yet tested
declare -g _TERM_CAN_CLEAR=""

# Initialize terminal capability cache
_init_term_capability() {
    if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM}" != "dumb" ]]; then
        _TERM_CAN_CLEAR=1
    else
        _TERM_CAN_CLEAR=0
    fi
}

# Initialize on source (one-time check)
_init_term_capability

clear_screen() {
    # Use cached terminal capability instead of checking every call
    if [[ "${_TERM_CAN_CLEAR:-0}" == "1" ]]; then
        clear 2>/dev/null || printf '\033[2J\033[H'
    fi
}

pause() {
    # Skip pause in non-interactive mode
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        return 0
    fi
    echo
    echo -ne "    ${C_SHADOW}Press Enter to continue...${C_RESET}"
    read -r
}

#═══════════════════════════════════════════════════════════════════════════════
# BANNER DISPLAY
#═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    clear_screen
    echo -e "${C_PURPLE}"
    cat << 'BANNER'

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║  ██╗   ██╗ ██████╗ ██╗██████╗     ██╗    ██╗ █████╗ ██╗   ██╗███████╗     ║
    ║  ██║   ██║██╔═══██╗██║██╔══██╗    ██║    ██║██╔══██╗██║   ██║██╔════╝     ║
    ║  ██║   ██║██║   ██║██║██║  ██║    ██║ █╗ ██║███████║██║   ██║█████╗       ║
    ║  ╚██╗ ██╔╝██║   ██║██║██║  ██║    ██║███╗██║██╔══██║╚██╗ ██╔╝██╔══╝       ║
    ║   ╚████╔╝ ╚██████╔╝██║██████╔╝    ╚███╔███╔╝██║  ██║ ╚████╔╝ ███████╗     ║
    ║    ╚═══╝   ╚═════╝ ╚═╝╚═════╝      ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═══╝  ╚══════╝     ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${C_RESET}"
    echo
    echo -e "    ${C_BORDER}══════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "    ${C_SHADOW}║${C_RESET} ${C_RED}\"Some tools scan.${C_RESET} ${C_CYAN}Some tools attack.${C_RESET} ${C_GREEN}I do both.\"${C_RESET}               ${C_SHADOW}║${C_RESET}"
    echo -e "    ${C_BORDER}══════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "                   ${C_SHADOW}[${C_RESET} ${C_RED}v${VERSION}${C_RESET} ${C_SHADOW}•${C_RESET} ${C_CYAN}${CODENAME}${C_RESET} ${C_SHADOW}•${C_RESET} ${C_GREEN}70+ Tools${C_RESET} ${C_SHADOW}]${C_RESET}"
    echo
}

show_mini_banner() {
    echo -e "${C_BLOOD}    ╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BLOOD}    ║${C_RESET}  ${C_SKULL}VOIDWAVE${C_RESET} ${C_SHADOW}v${VERSION}${C_RESET}                                              ${C_BLOOD}║${C_RESET}"
    echo -e "${C_BLOOD}    ╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
}

show_skull() {
    echo -e "${C_BLOOD}"
    cat << 'SKULL'
                              ______
                           .-"      "-.
                          /            \
                         |              |
                         |,  .-.  .-.  ,|
                         | )(_o/  \o_)( |
                         |/     /\     \|
                         (_     ^^     _)
                          \__|IIIIII|__/
                           | \IIIIII/ |
                           \          /
                            `--------`
SKULL
    echo -e "${C_RESET}"
}

#═══════════════════════════════════════════════════════════════════════════════
# INPUT SANITIZATION
#═══════════════════════════════════════════════════════════════════════════════

strip_ansi() {
    local text="$1"
    # Remove all ANSI escape sequences
    echo -e "$text" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b(B//g'
}

sanitize_filename() {
    local input="$1"
    # Strip ANSI, then keep only safe filename characters
    strip_ansi "$input" | tr -cd '[:alnum:]._-' | cut -c1-100
}

sanitize_target() {
    local input="$1"
    # Strip ANSI and trim whitespace
    strip_ansi "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

#═══════════════════════════════════════════════════════════════════════════════
# INPUT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

get_target_input() {
    local prompt="${1:-Enter target}"
    local default="${2:-}"
    local target=""

    # Non-interactive mode: return default or empty
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        echo "$default"
        return 0
    fi

    if [[ -n "$default" ]]; then
        echo -ne "    ${C_PROMPT}${prompt} ${C_SHADOW}[${default}]${C_RESET}: " >&2
    else
        echo -ne "    ${C_PROMPT}${prompt}: ${C_RESET}" >&2
    fi

    read -r target

    # Use default if empty
    [[ -z "$target" ]] && target="$default"

    # Sanitize and return (echo to stdout, prompts went to stderr)
    sanitize_target "$target"
}

get_input() {
    local prompt="${1:-Input}"
    local default="${2:-}"
    local input=""

    # Non-interactive mode: return default or empty
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        echo "$default"
        return 0
    fi

    if [[ -n "$default" ]]; then
        echo -ne "    ${C_PROMPT}${prompt} ${C_SHADOW}[${default}]${C_RESET}: " >&2
    else
        echo -ne "    ${C_PROMPT}${prompt}: ${C_RESET}" >&2
    fi

    read -r input

    # Use default if empty
    [[ -z "$input" ]] && input="$default"

    # Sanitize and return
    strip_ansi "$input"
}

get_password_input() {
    local prompt="${1:-Password}"
    local password=""

    # Non-interactive mode: return empty
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        echo ""
        return 0
    fi

    echo -ne "    ${C_PROMPT}${prompt}: ${C_RESET}" >&2
    read -rs password
    echo >&2  # Newline after hidden input

    echo "$password"
}

# Enhanced prompt_input with secret mode and validator support
# Args: $1=message, $2=validator (optional), $3=default (optional), $4=secret (optional, "true" for hidden input)
prompt_input() {
    local message="$1"
    local validator="${2:-}"
    local default="${3:-}"
    local secret="${4:-false}"
    local display_default=""
    local input=""

    [[ -n "$default" ]] && display_default=" ${C_SHADOW}[$default]${C_RESET}"

    # Non-interactive mode: return default or empty
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        log_debug "Non-interactive: returning default for prompt '$message'"
        echo "$default"
        return 0
    fi

    while true; do
        if [[ "$secret" == "true" ]]; then
            echo -ne "    ${C_PROMPT}$message: ${C_RESET}" >&2
            read -rs input
            echo >&2  # Newline after hidden input
        else
            echo -ne "    ${C_PROMPT}$message${display_default}: ${C_RESET}" >&2
            read -r input
        fi

        input="${input:-$default}"
        input=$(strip_ansi "$input")

        if [[ -z "$input" ]]; then
            log_warning "Input required"
            continue
        fi

        if [[ -n "$validator" ]]; then
            if $validator "$input"; then
                echo "$input"
                return 0
            else
                log_warning "Invalid input, please try again"
                continue
            fi
        fi

        echo "$input"
        return 0
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# CONFIRMATION FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Simple yes/no confirmation with non-interactive support
# Args: $1=message, $2=default (y/n)
# Returns: 0 if yes, 1 if no
confirm() {
    local message="${1:-Continue?}"
    local default="${2:-n}"
    local prompt response

    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    # Non-interactive mode: use default
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        log_debug "Non-interactive: using default '$default' for confirm '$message'"
        [[ "${default,,}" == "y" ]]
        return $?
    fi

    echo -ne "    ${C_PROMPT}$message $prompt: ${C_RESET}"
    read -r response
    response="${response:-$default}"
    [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]
}

# Alias for confirm
ask_yes_no() {
    confirm "$@"
}

confirm_action() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response=""

    # Non-interactive mode: use default
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        log_debug "Non-interactive: using default '$default' for confirm_action '$prompt'"
        [[ "${default,,}" == "y" ]]
        return $?
    fi

    if [[ "$default" == "y" ]]; then
        echo -ne "    ${C_PROMPT}${prompt} [Y/n]: ${C_RESET}" >&2
    else
        echo -ne "    ${C_PROMPT}${prompt} [y/N]: ${C_RESET}" >&2
    fi

    read -r response
    response="${response:-$default}"

    [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]
}

# Helper to check if unsafe mode is enabled (backward compatible)
# Duplicated here to avoid circular dependency with safety.sh
_ui_is_unsafe_mode_enabled() {
    local val="${VW_UNSAFE_MODE:-0}"
    case "${val,,}" in
        1|true|yes|y) return 0 ;;
        *) return 1 ;;
    esac
}

# Dangerous operation confirmation requiring exact phrase match
# Args: $1=message, $2=confirm_word (phrase user must type)
# Returns: 0 if confirmed, 1 if not
#
# Non-interactive behavior:
#   - Default: blocked (returns 1)
#   - If VW_UNSAFE_MODE enabled: auto-accepts (returns 0)
#   - If VW_FORCE_DANGEROUS=1: auto-accepts (returns 0)
confirm_dangerous() {
    local message="${1:-This is a dangerous operation}"
    local confirm_word="${2:-YES}"
    local response=""

    # Non-interactive mode handling
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        # Check for explicit override flags
        if _ui_is_unsafe_mode_enabled || [[ "${VW_FORCE_DANGEROUS:-0}" == "1" ]]; then
            log_warning "Dangerous operation auto-accepted in non-interactive unsafe mode: $message"
            log_audit "CONFIRM_DANGEROUS" "$message" "auto_accepted_non_interactive_unsafe"
            return 0
        fi

        # Default: block dangerous operations in non-interactive mode
        log_warning "Dangerous operation blocked in non-interactive mode: $message"
        log_audit "CONFIRM_DANGEROUS" "$message" "blocked_non_interactive"
        return 1
    fi

    echo >&2
    echo -e "    ${C_RED}╔══════════════════════════════════════════════════════════════╗${C_RESET}" >&2
    echo -e "    ${C_RED}║${C_RESET}  ${C_YELLOW}⚠  WARNING: POTENTIALLY DANGEROUS OPERATION  ⚠${C_RESET}             ${C_RED}║${C_RESET}" >&2
    echo -e "    ${C_RED}╚══════════════════════════════════════════════════════════════╝${C_RESET}" >&2
    echo >&2
    echo -e "    ${C_SHADOW}$message${C_RESET}" >&2
    echo >&2
    echo -ne "    ${C_YELLOW}Type '${C_GREEN}${confirm_word}${C_YELLOW}' to confirm: ${C_RESET}" >&2
    read -r response

    if [[ "$response" == "$confirm_word" ]]; then
        log_audit "CONFIRM_DANGEROUS" "$message" "user_confirmed"
        return 0
    else
        log_audit "CONFIRM_DANGEROUS" "$message" "user_declined"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# SELECTION FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Display numbered menu and get selection
# Args: $1=prompt, $2+=options array
# Returns: selected option via stdout, 0 on success, 1 on invalid selection
#
# Non-interactive behavior:
#   - Requires VW_NON_INTERACTIVE_DEFAULT_INDEX to be set
#   - Value must be a valid index (0-based) into the options array
#   - Returns error if not set, non-numeric, or out of range
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice
    local num_options=${#options[@]}

    # Non-interactive mode handling
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        local default_index="${VW_NON_INTERACTIVE_DEFAULT_INDEX:-}"

        # Check if index is set
        if [[ -z "$default_index" ]]; then
            log_error "Non-interactive selection for '$prompt' requires VW_NON_INTERACTIVE_DEFAULT_INDEX to be set"
            return 1
        fi

        # Check if index is numeric
        if [[ ! "$default_index" =~ ^[0-9]+$ ]]; then
            log_error "Non-interactive selection for '$prompt' has non-numeric default index '$default_index'"
            return 1
        fi

        # Check if index is in range (0-based)
        if (( default_index >= num_options )); then
            log_error "Non-interactive selection for '$prompt' has out-of-range default index '$default_index' (options: $num_options)"
            return 1
        fi

        log_debug "Non-interactive: selecting option index $default_index for '$prompt'"
        echo "${options[$default_index]}"
        return 0
    fi

    echo
    echo -e "    ${C_CYAN}$prompt${C_RESET}"
    echo
    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${C_GHOST}[$i]${C_RESET} $opt"
        ((i++)) || true
    done
    echo
    echo -ne "    ${C_PROMPT}Select [1-${#options[@]}]: ${C_RESET}"
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
        echo "${options[$((choice-1))]}"
        return 0
    fi

    log_warning "Invalid selection: $choice"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# OPERATION DISPLAY FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

operation_header() {
    local title="${1:-Operation}"
    local target="${2:-}"

    echo
    echo -e "    ${C_CYAN}┌─────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "    ${C_CYAN}│${C_RESET} ${C_FIRE}⚔${C_RESET}  ${C_WHITE}${title}${C_RESET}"
    if [[ -n "$target" ]]; then
        # Sanitize target for display
        local clean_target
        clean_target=$(strip_ansi "$target")
        echo -e "    ${C_CYAN}│${C_RESET} ${C_SHADOW}Target:${C_RESET} ${C_GREEN}${clean_target}${C_RESET}"
    fi
    echo -e "    ${C_CYAN}└─────────────────────────────────────────────────────────────┘${C_RESET}"
    echo

    log_audit "OPERATION" "$title" "started"
}

operation_summary() {
    local status="${1:-info}"
    local message="${2:-Complete}"
    local extra="${3:-}"

    if [[ ! "$status" =~ ^(success|ok|done|0|fail|failed|error|1|warn|warning|partial|info)$ ]]; then
        extra="${message}${extra:+\n$extra}"
        message="$status"
        status="info"
    fi

    echo
    case "$status" in
        success|ok|done|0)
            echo -e "    ${C_GREEN}[✓]${C_RESET} ${message}"
            log_audit "RESULT" "$message" "success"
            ;;
        fail|failed|error|1)
            echo -e "    ${C_RED}[✗]${C_RESET} ${message}"
            log_audit "RESULT" "$message" "failed"
            ;;
        warn|warning|partial)
            echo -e "    ${C_YELLOW}[!]${C_RESET} ${message}"
            log_audit "RESULT" "$message" "warning"
            ;;
        info|*)
            echo -e "    ${C_CYAN}[*]${C_RESET} ${message}"
            log_audit "RESULT" "$message" "info"
            ;;
    esac

    [[ -n "$extra" ]] && echo -e "    ${C_SHADOW}${extra}${C_RESET}"
}

operation_footer() {
    operation_summary "$@"
}

#═══════════════════════════════════════════════════════════════════════════════
# INPUT VALIDATORS (NOTE: validate_ip, validate_cidr, validate_port are in utils.sh)
#═══════════════════════════════════════════════════════════════════════════════

# Domain validation (alias for validate_hostname in utils.sh)
validate_domain() { [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; }
validate_interface() { ip link show "$1" &>/dev/null; }
validate_file_exists() { [[ -f "$1" ]]; }

# Validate input is not empty (after stripping whitespace)
validate_not_empty() {
    local input="$1"
    input="${input//[[:space:]]/}"
    [[ -n "$input" ]]
}

# Validate input is an integer
validate_integer() {
    local input="$1"
    [[ "$input" =~ ^-?[0-9]+$ ]]
}

# Validate input is a positive integer
validate_positive_integer() {
    local input="$1"
    [[ "$input" =~ ^[0-9]+$ ]] && ((input > 0))
}

# Validate port range (e.g., "1-1024" or "80,443,8080")
validate_port_range() {
    local input="$1"
    # Single port
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        validate_port "$input"
        return $?
    fi
    # Range format: 1-65535
    if [[ "$input" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}" end="${BASH_REMATCH[2]}"
        validate_port "$start" && validate_port "$end" && ((start <= end))
        return $?
    fi
    # Comma-separated list
    if [[ "$input" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        IFS=',' read -ra ports <<< "$input"
        for p in "${ports[@]}"; do
            validate_port "$p" || return 1
        done
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# MENU UI HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

select_multiple() {
    local prompt="$1"
    shift
    local options=("$@")
    local -a states=()

    for ((i=0; i<${#options[@]}; i++)); do
        states[$i]=0
    done

    while true; do
        echo -e "\n    ${C_CYAN:-}${prompt}${C_RESET:-} (toggle number, Enter to confirm):\n"

        for i in "${!options[@]}"; do
            if [[ ${states[$i]} -eq 1 ]]; then
                echo -e "    ${C_GREEN:-}[x]${C_RESET:-} $((i+1))) ${options[$i]}"
            else
                echo "    [ ] $((i+1))) ${options[$i]}"
            fi
        done

        echo ""
        read -rp "    Toggle [1-${#options[@]}] or Enter: " choice

        [[ -z "$choice" ]] && break

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            local idx=$((choice - 1))
            states[$idx]=$(( 1 - states[$idx] ))
        fi
    done

    SELECTED_ITEMS=()
    for i in "${!options[@]}"; do
        [[ ${states[$i]} -eq 1 ]] && SELECTED_ITEMS+=("${options[$i]}")
    done

    printf '%s\n' "${SELECTED_ITEMS[*]}"
}

show_progress() {
    local current="$1" total="$2" width="${3:-40}"
    [[ $total -eq 0 ]] && total=1
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r    ["
    printf '%*s' "$filled" '' | tr ' ' '='
    printf '%*s' "$empty" ''
    printf "] %3d%%" "$pct"
    [[ $current -eq $total ]] && echo ""
}

wait_for_keypress() {
    local msg="${1:-Press any key to continue...}"
    echo ""
    read -rsn1 -p "    $msg"
    echo ""
}

select_from_list() {
    local prompt="$1"
    local -n items_ref=$2
    local page_size="${3:-10}"
    local page=0 total=${#items_ref[@]}
    local pages=$(( (total + page_size - 1) / page_size ))

    [[ $total -eq 0 ]] && return 1

    while true; do
        local start=$((page * page_size))
        local end=$((start + page_size))
        [[ $end -gt $total ]] && end=$total

        echo -e "\n    ${C_CYAN:-}${prompt}${C_RESET:-} (Page $((page+1))/$pages):\n"

        for ((i=start; i<end; i++)); do
            printf "    %3d) %s\n" "$((i+1))" "${items_ref[$i]}"
        done

        echo ""
        read -rp "    Select [1-$total] or n/p/q: " choice

        case "$choice" in
            n|N) ((page < pages-1)) && ((page++)) ;;
            p|P) ((page > 0)) && ((page--)) ;;
            q|Q) return 1 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= total )); then
                    echo "${items_ref[$((choice-1))]}"
                    return 0
                fi
                ;;
        esac
    done
}

select_interface() {
    local type="${1:-all}"
    local -a interfaces=()

    case "$type" in
        wireless)
            while IFS= read -r iface; do
                [[ -n "$iface" ]] && interfaces+=("$iface")
            done < <(iw dev 2>/dev/null | awk '/Interface/{print $2}')
            ;;
        *)
            while IFS= read -r iface; do
                [[ -n "$iface" && "$iface" != "lo" ]] && interfaces+=("$iface")
            done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}')
            ;;
    esac

    [[ ${#interfaces[@]} -eq 0 ]] && return 1
    [[ ${#interfaces[@]} -eq 1 ]] && { echo "${interfaces[0]}"; return 0; }

    select_option "Select interface" "${interfaces[@]}"
}

get_default_gateway() {
    ip route 2>/dev/null | awk '/default/{print $3; exit}'
}

get_local_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
}

is_valid_domain() {
    [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]
}

show_table() {
    local -a rows=("$@")
    local -a widths=()

    for row in "${rows[@]}"; do
        IFS='|' read -ra cols <<< "$row"
        for i in "${!cols[@]}"; do
            local len=${#cols[$i]}
            [[ -z "${widths[$i]:-}" || $len -gt ${widths[$i]} ]] && widths[$i]=$len
        done
    done

    local first=1
    for row in "${rows[@]}"; do
        IFS='|' read -ra cols <<< "$row"
        printf "    "
        for i in "${!cols[@]}"; do
            printf "%-${widths[$i]}s  " "${cols[$i]}"
        done
        echo ""
        if [[ $first -eq 1 ]]; then
            printf "    "
            for i in "${!widths[@]}"; do
                printf '%*s  ' "${widths[$i]}" '' | tr ' ' '-'
            done
            echo ""
            first=0
        fi
    done
}

mask_string() {
    local str="$1" show="${2:-4}"
    [[ ${#str} -le $((show * 2)) ]] && { echo "****"; return; }
    echo "${str:0:$show}****${str: -$show}"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Visual effects
export -f typewriter spinner progress_bar draw_line draw_header

# Progress indicators
export -f show_spinner run_with_spinner show_progress_bar
export -f start_timer stop_timer timed_run countdown

# Screen control
export -f clear_screen pause

# Banners
export -f show_banner show_mini_banner show_skull

# Input sanitization
export -f strip_ansi sanitize_filename sanitize_target

# Input functions
export -f get_target_input get_input get_password_input prompt_input

# Confirmation functions
export -f confirm ask_yes_no confirm_action confirm_dangerous

# Selection functions
export -f select_option

# Operation display
export -f operation_header operation_summary operation_footer

# Validators (validate_ip, validate_cidr, validate_port are in utils.sh)
export -f validate_domain validate_interface validate_file_exists
export -f validate_not_empty validate_integer validate_positive_integer validate_port_range

# Menu UI helpers
export -f select_multiple show_progress wait_for_keypress select_from_list
export -f select_interface get_default_gateway get_local_ip is_valid_domain
export -f show_table mask_string
