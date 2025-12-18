#compdef voidwave
# VOIDWAVE Zsh Completions
# Install: cp voidwave.zsh ~/.zsh/completions/_voidwave

_voidwave() {
    local -a commands global_opts

    global_opts=(
        '(-h --help)'{-h,--help}'[Show help message]'
        '--version[Show version]'
        '--dry-run[Preview commands without executing]'
        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]'
        '(-q --quiet)'{-q,--quiet}'[Suppress non-essential output]'
        '--no-color[Disable colored output]'
        '--debug[Enable debug mode]'
    )

    commands=(
        'menu:Interactive menu (default)'
        'wizard:Guided wizard'
        'scan:Network scanning'
        'discover:Host discovery'
        'wifi:Wireless operations'
        'crack:Handshake cracking'
        'session:Session management'
        'history:Target history'
        'favorite:Manage favorites'
        'alias:Manage aliases'
        'profile:Scan presets'
        'export:Export results'
        'schedule:Scheduled scans'
        'diff:Compare scan results'
        'status:Show tool status'
        'arsenal:Show tool status (alias)'
        'install:Install tools'
        'install-quick:Install essentials'
        'config:Configuration management'
        'update:Check for updates'
        'logs:View operation logs'
        'help:Show help'
    )

    _arguments -C \
        $global_opts \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            _describe -t commands 'voidwave commands' commands
            ;;
        args)
            case $words[1] in
                wizard)
                    local -a wizard_cmds=(
                        'scan:Guided scan wizard'
                        'wifi:Guided WiFi wizard'
                    )
                    _describe -t wizard-commands 'wizard commands' wizard_cmds
                    ;;
                scan)
                    _arguments \
                        '--quick[Quick scan]' \
                        '--full[Full port scan]' \
                        '--stealth[Stealth/SYN scan]' \
                        '--vuln[Vulnerability scan]' \
                        '--udp[UDP scan]' \
                        '--profile[Use saved profile]:profile:' \
                        '*:target:'
                    ;;
                wifi)
                    _arguments \
                        '--monitor[Enable monitor mode]:interface:' \
                        '--managed[Return to managed mode]:interface:' \
                        '--scan[Scan for networks]:interface:'
                    ;;
                crack)
                    _arguments \
                        '--aircrack[Use aircrack-ng]' \
                        '--john[Use John the Ripper]' \
                        '--cowpatty[Use cowpatty]' \
                        '--hashcat-rules[Use hashcat with rules]' \
                        '(-w --wordlist)'{-w,--wordlist}'[Wordlist file]:file:_files' \
                        '--ssid[Target SSID]:ssid:' \
                        '--rules[Rules file]:file:_files' \
                        '*:capture file:_files -g "*.cap *.pcap"'
                    ;;
                config)
                    local -a config_cmds=(
                        'edit:Edit config file'
                        'show:Show config'
                        'get:Get config value'
                        'set:Set config value'
                        'reset:Reset config'
                        'path:Show config path'
                    )
                    _describe -t config-commands 'config commands' config_cmds
                    ;;
                session)
                    local -a session_cmds=(
                        'start:Start new session'
                        'resume:Resume session'
                        'status:Session status'
                        'list:List sessions'
                        'export:Export session'
                        'notes:Session notes'
                    )
                    _describe -t session-commands 'session commands' session_cmds
                    ;;
                status|arsenal)
                    _arguments \
                        '(-c --compact)'{-c,--compact}'[Compact view]' \
                        '(-j --json)'{-j,--json}'[JSON output]' \
                        '(-C --category)'{-C,--category}'[Show category]:category:(scanning dns ssl wifi web exploit traffic osint creds post)'
                    ;;
                favorite)
                    local -a fav_cmds=(
                        'add:Add favorite'
                        'list:List favorites'
                        'use:Use favorite'
                    )
                    _describe -t favorite-commands 'favorite commands' fav_cmds
                    ;;
                alias)
                    local -a alias_cmds=(
                        'add:Add alias'
                        'remove:Remove alias'
                        'list:List aliases'
                    )
                    _describe -t alias-commands 'alias commands' alias_cmds
                    ;;
                profile)
                    local -a profile_cmds=(
                        'save:Save profile'
                        'load:Load profile'
                        'list:List profiles'
                    )
                    _describe -t profile-commands 'profile commands' profile_cmds
                    ;;
                install)
                    local -a install_cats=(
                        'all:Install everything'
                        'essentials:Essential tools'
                        'scanning:Scanning tools'
                        'wireless:Wireless tools'
                        'exploit:Exploit tools'
                        'creds:Credential tools'
                        'osint:OSINT tools'
                        'traffic:Traffic tools'
                        'web:Web tools'
                    )
                    _describe -t install-categories 'install categories' install_cats
                    ;;
                help)
                    local -a help_topics=(
                        'scan:Scan help'
                        'wifi:WiFi help'
                        'config:Config help'
                    )
                    _describe -t help-topics 'help topics' help_topics
                    ;;
                *)
                    _files
                    ;;
            esac
            ;;
    esac
}

_voidwave "$@"
