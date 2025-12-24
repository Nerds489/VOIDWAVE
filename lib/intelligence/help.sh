#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Help System
# ═══════════════════════════════════════════════════════════════════════════════
# Provides detailed descriptions for all menu options
# Access via: ? or H from any menu, or ?<num> for specific option
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_HELP_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_HELP_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# WIRELESS MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA WIRELESS_HELP=(
    # Interface Section
    [1]="SELECT INTERFACE
    
    Choose which wireless adapter to use for attacks.
    
    Shows all available WiFi interfaces with:
    • Current mode (managed/monitor)
    • Driver information
    • Chipset details
    
    TIP: Use adapters with Atheros AR9271 or Ralink RT3070 
    chipsets for best injection support."

    [2]="ENABLE MONITOR MODE
    
    Switch interface to monitor mode for packet capture/injection.
    
    This will:
    • Kill interfering processes (NetworkManager, wpa_supplicant)
    • Put adapter in monitor mode
    • Verify injection capability
    
    REQUIRED for: All wireless attacks, scanning
    
    WARNING: Normal WiFi connectivity will be disabled until 
    you run 'Monitor Mode OFF'"

    [3]="DISABLE MONITOR MODE
    
    Restore interface to managed mode.
    
    This will:
    • Stop monitor mode
    • Restart NetworkManager
    • Restore normal WiFi connectivity
    
    Use when finished with wireless attacks."

    [4]="MAC ADDRESS SPOOFING
    
    Change your adapter's MAC address.
    
    Options:
    • Random MAC - fully randomized
    • Specific MAC - clone another device
    • Vendor spoof - match Intel/Broadcom/etc
    • Restore original
    
    USE CASES:
    • Avoid MAC filtering
    • Impersonate authorized device
    • Evade detection/logging"

    # Scanning Section
    [5]="SCAN NETWORKS
    
    Discover all nearby wireless networks.
    
    Displays:
    • ESSID (network name)
    • BSSID (AP MAC address)
    • Channel
    • Encryption (Open/WEP/WPA/WPA2/WPA3)
    • Signal strength (PWR)
    • Connected clients
    
    Press Ctrl+C to stop scanning.
    
    TIP: Let it run 30-60 seconds to discover all networks 
    and see client activity."

    [6]="DETAILED TARGET SCAN
    
    Focus scan on a specific network.
    
    Shows:
    • All connected clients with MAC addresses
    • Client signal strength
    • Data/packet counts
    • Probe requests
    
    USEFUL FOR: Identifying high-value clients for deauth, 
    checking network activity before attacks."

    # WPS Section
    [10]="PIXIE-DUST ATTACK
    
    Offline WPS PIN recovery exploiting weak RNG.
    
    HOW IT WORKS:
    1. Captures M1/M2 WPS exchange from target
    2. Extracts E-S1/E-S2 nonces
    3. Cracks PIN offline using pixiewps
    
    SUCCESS RATE: ~30% of WPS-enabled routers
    TIME: Seconds to minutes (offline crack)
    
    TOOLS: reaver + pixiewps (or bully + pixiewps)
    
    TRY THIS FIRST - fastest WPS attack when vulnerable."

    [11]="WPS PIN BRUTEFORCE
    
    Online attack trying all possible WPS PINs.
    
    HOW IT WORKS:
    • Tests PINs against live AP
    • 11,000 possible combinations
    • Checksum reduces to ~11,000 attempts
    
    TIME: 4-10 hours (depends on AP rate limiting)
    
    WATCH FOR:
    • AP lockouts (60-second to permanent)
    • Rate limiting (slows attack)
    
    Use when Pixie-Dust fails."

    [12]="KNOWN PINS DATABASE
    
    Try manufacturer default PINs.
    
    Many routers ship with predictable PINs:
    • Belkin: often 12345670
    • D-Link: MAC-based patterns
    • TP-Link: serial-based
    • Netgear: label-based
    
    SPEED: Very fast - only tries known PINs
    
    Run this before bruteforce to save hours."

    [13]="ALGORITHM PIN ATTACK
    
    Calculate PIN from router MAC/serial.
    
    ALGORITHMS:
    • ComputePIN - BSSID-based calculation
    • EasyBox - Arcadyan/EasyBox routers
    • Arcadyan - specific vendor algorithm
    
    Works when manufacturer generates PINs 
    algorithmically rather than randomly.
    
    SPEED: Instant calculation, quick test"

    # WPA Section
    [20]="PMKID CAPTURE
    
    Capture PMKID hash WITHOUT client deauth.
    
    HOW IT WORKS:
    1. Send association request to AP
    2. AP responds with PMKID in first EAPOL frame
    3. Crack PMKID offline with hashcat
    
    ADVANTAGES:
    • No clients needed
    • No deauth required (stealthier)
    • Works on ~70% of WPA2 networks
    
    TOOLS: hcxdumptool + hcxpcapngtool
    
    FASTEST method to get crackable WPA hash."

    [21]="HANDSHAKE CAPTURE
    
    Capture 4-way WPA handshake.
    
    HOW IT WORKS:
    1. Monitor target channel
    2. Deauth connected client
    3. Capture handshake when client reconnects
    
    REQUIRES: At least one client connected
    
    OUTPUT: .cap file for aircrack-ng/hashcat
    
    Classic WPA attack - works on all WPA/WPA2."

    [22]="SMART HANDSHAKE CAPTURE
    
    Intelligent automated handshake capture.
    
    FEATURES:
    • Auto-detects connected clients
    • Targets strongest signal client
    • Validates capture in real-time
    • Stops when valid handshake obtained
    • Retries failed deauths
    
    ADVANTAGE: Set and forget - handles edge cases."

    # Evil Twin Section
    [30]="EVIL TWIN - FULL ATTACK
    
    Complete rogue AP with captive portal.
    
    ATTACK FLOW:
    1. Capture handshake from target (for validation)
    2. Create identical fake AP
    3. Deauth clients from real AP
    4. Serve phishing portal
    5. Validate submitted passwords
    6. Save correct password
    
    REQUIRES: 2 interfaces OR VIF support
    
    CUSTOMIZATION: Multiple portal templates, 
    language selection, vendor logos."

    [31]="EVIL TWIN - OPEN HONEYPOT
    
    Simple open network trap.
    
    Creates open WiFi to:
    • Capture probe requests
    • See what networks devices seek
    • Catch auto-connecting devices
    
    NO portal - just monitoring.
    
    GOOD FOR: Reconnaissance, passive intel."

    [32]="EVIL TWIN - WPA HONEYPOT
    
    Fake secured network.
    
    Creates WPA-protected AP to:
    • Capture connection attempts
    • Log PSK guesses
    • Test for downgrade attacks
    
    Set your own password to catch 
    devices trying known passwords."

    # DoS Section
    [40]="DEAUTHENTICATION ATTACK
    
    Disconnect clients from access point.
    
    OPTIONS:
    • Broadcast - kick all clients
    • Targeted - specific client MAC
    
    USES:
    • Force handshake capture
    • Denial of service
    • Force client to Evil Twin
    
    PACKET COUNT: Higher = more aggressive
    
    WARNING: Easily detected by WIDS"

    [41]="AMOK MODE
    
    Mass deauthentication attack.
    
    Hits ALL detected networks simultaneously.
    
    TOOL: mdk4
    
    AGGRESSIVE - use in controlled environments.
    
    WARNING: Major disruption, highly visible."

    [42]="BEACON FLOOD
    
    Create thousands of fake APs.
    
    EFFECTS:
    • Confuses WiFi scanners
    • Overwhelms client lists
    • Can crash some devices
    
    OPTIONS:
    • Random SSIDs
    • Wordlist SSIDs
    • Clone nearby networks
    
    TOOL: mdk4"

    [43]="PURSUIT MODE
    
    Follow channel-hopping targets.
    
    Some APs change channels to evade attacks.
    Pursuit mode:
    • Detects channel changes
    • Follows target automatically
    • Maintains continuous DoS
    
    TOOL: mdk4
    
    Defeats basic evasion attempts."

    # Legacy Section
    [50]="WEP ATTACK SUITE
    
    Full WEP cracking toolkit.
    
    METHODS:
    • ARP Replay - generate IVs fast
    • Fragmentation - works without clients
    • Chop-Chop - another clientless method
    • PTW - crack with fewer IVs
    
    WEP IS BROKEN - success virtually guaranteed.
    
    Need ~20,000-40,000 IVs to crack.
    
    TIME: Minutes to hours depending on traffic."

    [51]="ENTERPRISE ATTACK
    
    WPA-Enterprise / 802.1X attacks.
    
    ATTACK: Fake RADIUS server
    
    HOW IT WORKS:
    1. Create rogue AP with WPA-Enterprise
    2. Client connects, sends credentials
    3. Capture MSCHAP hash
    4. Crack offline
    
    TOOLS: hostapd-wpe, freeradius
    
    TARGETS: Corporate networks using PEAP/MSCHAP"

    # Advanced Section
    [60]="HIDDEN SSID REVEAL
    
    Discover cloaked network names.
    
    METHODS:
    • Deauth attack - force probe responses
    • Dictionary attack - common SSIDs
    • Passive wait - client probes
    
    Hidden SSIDs provide NO real security.
    
    Network always revealed when clients connect."

    [61]="WPA3 DOWNGRADE TEST
    
    Check for WPA3 vulnerabilities.
    
    TESTS:
    • Accepts WPA2 when advertising WPA3?
    • Transition mode weaknesses
    • Dragonfly handshake issues
    
    WPA3 often deployed in transition mode 
    allowing WPA2 fallback attacks."

    [62]="WIFITE AUTOMATED AUDIT
    
    Launch wifite for hands-off testing.
    
    WIFITE HANDLES:
    • Interface management
    • Network scanning
    • Attack selection
    • Capture/cracking
    
    GOOD FOR: Quick assessments, lazy audits
    
    Less control but fully automated."
)

# ═══════════════════════════════════════════════════════════════════════════════
# RECON MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA RECON_HELP=(
    [1]="DNS ENUMERATION

    Query DNS records for a target domain.

    RETRIEVES:
    • A records (IP addresses)
    • MX records (mail servers)
    • NS records (name servers)
    • TXT records (SPF, DKIM, etc.)

    TOOLS: dig, host

    TIP: TXT records often reveal email security
    policies and third-party services."

    [2]="SUBDOMAIN DISCOVERY

    Find subdomains of a target domain.

    METHODS:
    • Passive enumeration (subfinder, amass)
    • Certificate transparency logs
    • DNS brute forcing (fallback)

    TOOLS: subfinder, amass, or basic DNS queries

    TIP: Subdomains often expose development,
    staging, or forgotten services."

    [3]="WHOIS LOOKUP

    Query domain/IP registration information.

    REVEALS:
    • Registrar information
    • Registration/expiry dates
    • Name servers
    • Registrant contact (if not private)
    • ASN information for IPs

    TOOLS: whois

    TIP: Historical WHOIS can reveal ownership changes."

    [4]="EMAIL HARVESTING

    Discover email addresses associated with a domain.

    SOURCES:
    • Search engines (Google, Bing)
    • LinkedIn profiles
    • Data breaches (if configured)

    TOOLS: theHarvester

    USE CASES: Phishing target lists, OSINT profiles"

    [5]="TECHNOLOGY DETECTION

    Identify technologies used by a website.

    DETECTS:
    • Web server (Apache, Nginx, IIS)
    • CMS (WordPress, Drupal, Joomla)
    • Frameworks (React, Angular, Django)
    • CDN and hosting providers
    • Security headers

    TOOLS: whatweb, curl

    TIP: Knowing the tech stack helps find CVEs."

    [6]="FULL RECON SUITE

    Run all reconnaissance modules automatically.

    PERFORMS:
    • DNS enumeration
    • WHOIS lookup
    • Subdomain discovery
    • HTTP header analysis

    OUTPUT: Results saved to timestamped directory

    TIP: Good starting point for new targets."
)

# ═══════════════════════════════════════════════════════════════════════════════
# SCAN MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA SCAN_HELP=(
    [1]="QUICK SCAN

    Fast scan of top 100 most common ports.

    NMAP FLAGS: -T4 -F

    PORTS: HTTP, HTTPS, SSH, FTP, SMB, RDP, etc.

    TIME: ~30 seconds to 2 minutes

    USE WHEN: Initial reconnaissance, time-limited"

    [2]="FULL PORT SCAN

    Comprehensive scan of all 65,535 ports.

    NMAP FLAGS: -T3 -p-

    TIME: 10-30 minutes depending on target

    FINDS: Non-standard services, hidden ports

    TIP: Run overnight for thorough coverage."

    [3]="SERVICE VERSION DETECTION

    Identify exact service versions on open ports.

    NMAP FLAGS: -sV -T4

    DETECTS:
    • Software name and version
    • Protocol (HTTP, SSH, FTP)
    • OS hints from banners

    USE FOR: Vulnerability research, exploit matching"

    [4]="OS DETECTION

    Fingerprint target operating system.

    NMAP FLAGS: -O -T4

    REQUIRES: Root privileges

    IDENTIFIES:
    • OS family (Windows, Linux, BSD)
    • Version (Windows 10, Ubuntu 20.04)
    • Uptime estimate

    TIP: Multiple open ports improve accuracy."

    [5]="VULNERABILITY SCAN

    Check for known vulnerabilities with NSE scripts.

    NMAP FLAGS: -sV --script=vuln -T4

    CHECKS:
    • CVE vulnerabilities
    • Default credentials
    • Misconfigurations
    • Known exploits

    WARNING: More intrusive, may trigger alerts."

    [6]="STEALTH SCAN

    Low-profile scan to avoid detection.

    NMAP FLAGS: -sS -T2 -f --data-length 24

    TECHNIQUES:
    • SYN scan (no full connection)
    • Slow timing
    • Packet fragmentation
    • Random data padding

    REQUIRES: Root privileges

    USE WHEN: IDS/IPS evasion needed."

    [7]="UDP SCAN

    Scan UDP ports (often overlooked).

    NMAP FLAGS: -sU --top-ports 100 -T4

    FINDS:
    • DNS (53)
    • SNMP (161)
    • NTP (123)
    • TFTP (69)

    REQUIRES: Root privileges

    NOTE: UDP scans are slow due to no acknowledgment."

    [8]="CUSTOM SCAN

    Build your own scan with custom options.

    CONFIGURE:
    • Port range
    • Timing template (1-5)
    • NSE scripts

    TIP: Use timing 1-2 for stealth, 4-5 for speed."
)

# ═══════════════════════════════════════════════════════════════════════════════
# CREDENTIALS MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA CREDS_HELP=(
    [1]="HYDRA BRUTE FORCE

    Online password attack against network services.

    SUPPORTED SERVICES:
    • SSH, FTP, Telnet
    • HTTP, HTTPS (form-based)
    • SMB, RDP, VNC
    • MySQL, PostgreSQL

    TOOLS: hydra

    WARNING: Generates logs, may lock accounts."

    [2]="HASHCAT CRACKING

    GPU-accelerated offline hash cracking.

    SUPPORTED HASHES:
    • MD5, SHA1, SHA256, SHA512
    • NTLM, NetNTLMv2
    • bcrypt, scrypt
    • WPA/WPA2

    ATTACK MODES:
    • Dictionary
    • Dictionary + Rules
    • Brute force

    TOOLS: hashcat

    TIP: GPU cracking is 50-100x faster than CPU."

    [3]="JOHN THE RIPPER

    Classic password cracker with auto-detection.

    FEATURES:
    • Auto hash format detection
    • Incremental mode
    • Custom rules
    • Session restore

    TOOLS: john

    TIP: Good for mixed hash files."

    [4]="HASH IDENTIFIER

    Identify unknown hash types.

    IDENTIFIES BY:
    • Length (32=MD5, 40=SHA1, etc.)
    • Prefix ($2a$=bcrypt, $6$=SHA512crypt)
    • Character set

    TOOLS: hashid (if installed)

    USE BEFORE: Selecting hashcat mode."

    [5]="PASSWORD LIST GENERATOR

    Create targeted wordlists from base words.

    GENERATES:
    • Case variations
    • Common suffixes (123, !, @)
    • Leet speak
    • Year patterns

    USE CASE: Company-specific password attacks."

    [6]="EXTRACT HASHES FROM FILE

    Parse hash files into crackable format.

    SUPPORTS:
    • Linux /etc/shadow
    • Windows SAM dumps
    • Raw hash extraction

    OUTPUT: Clean hash file for cracking tools."
)

# ═══════════════════════════════════════════════════════════════════════════════
# OSINT MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA OSINT_HELP=(
    [1]="THEHARVESTER

    Gather emails, subdomains, and IPs from public sources.

    SOURCES:
    • Google, Bing
    • LinkedIn
    • Twitter
    • DNS records

    TOOLS: theHarvester

    TIP: Results depend on search engine access."

    [2]="SHODAN SEARCH

    Query Shodan for internet-connected devices.

    REQUIRES: Shodan API key

    SEARCHES:
    • IP lookup
    • Domain lookup
    • Query search (org:target)

    FINDS: Open ports, banners, vulnerabilities

    TIP: Free tier allows 100 queries/month."

    [3]="GOOGLE DORKING

    Advanced Google searches to find sensitive data.

    DORK CATEGORIES:
    • Sensitive files (PDF, SQL, logs)
    • Login pages
    • Config files
    • Database files
    • Error messages

    TIP: Opens results in browser."

    [4]="SOCIAL MEDIA LOOKUP

    Find user profiles across platforms.

    CHECKS:
    • Twitter, GitHub, LinkedIn
    • Instagram, Facebook
    • Reddit, TikTok, YouTube

    TOOLS: sherlock (if installed)

    USE FOR: Profiling individuals."

    [5]="IP REPUTATION CHECK

    Check if an IP is flagged as malicious.

    SERVICES:
    • AbuseIPDB
    • VirusTotal
    • Shodan
    • Censys

    SHOWS: Links to reputation services."

    [6]="DOMAIN INVESTIGATION

    Comprehensive domain analysis.

    CHECKS:
    • WHOIS registration
    • DNS records
    • SSL certificate
    • HTTP headers
    • Technologies

    TIP: Good for initial target profiling."

    [7]="FULL OSINT REPORT

    Automated comprehensive OSINT collection.

    GATHERS:
    • WHOIS, DNS
    • Subdomains
    • SSL info
    • Headers
    • Emails

    OUTPUT: Saved to timestamped directory."
)

# ═══════════════════════════════════════════════════════════════════════════════
# TRAFFIC MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA TRAFFIC_HELP=(
    [1]="PACKET CAPTURE

    Capture network traffic with tcpdump.

    FILTERS:
    • All traffic
    • HTTP only
    • DNS only
    • SSH only
    • Custom BPF

    REQUIRES: Root privileges

    OUTPUT: PCAP file for analysis."

    [2]="WIRESHARK

    Launch Wireshark GUI for packet analysis.

    FEATURES:
    • Real-time capture
    • Protocol dissection
    • Follow streams
    • Export objects

    TOOLS: wireshark"

    [3]="ARP SPOOFING

    Man-in-the-middle via ARP cache poisoning.

    HOW IT WORKS:
    1. Poison target ARP cache
    2. Traffic flows through attacker
    3. Forward packets to gateway

    REQUIRES: Root, arpspoof

    WARNING: Only use on authorized networks."

    [4]="DNS SPOOFING

    Redirect DNS queries to attacker IP.

    HOW IT WORKS:
    1. Define IP -> domain mappings
    2. Intercept DNS requests
    3. Return spoofed responses

    REQUIRES: Root, dnsspoof

    USE CASE: Phishing, traffic redirection."

    [5]="NETWORK SNIFFING

    Live capture of specific traffic types.

    MODES:
    • HTTP URLs
    • FTP credentials
    • DNS queries
    • All cleartext

    REQUIRES: Root privileges

    TIP: Combine with ARP spoof for remote sniffing."

    [6]="PCAP ANALYSIS

    Analyze captured packet files.

    ANALYSIS TYPES:
    • Summary statistics
    • HTTP requests
    • DNS queries
    • Credential extraction
    • Conversation list

    TOOLS: tshark, tcpdump, wireshark"
)

# ═══════════════════════════════════════════════════════════════════════════════
# EXPLOIT MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA EXPLOIT_HELP=(
    [1]="METASPLOIT CONSOLE

    Launch Metasploit Framework.

    FEATURES:
    • Exploit modules
    • Payload generation
    • Post-exploitation
    • Session management

    TOOLS: msfconsole

    TIP: Use 'search' to find exploits by CVE."

    [2]="SEARCHSPLOIT LOOKUP

    Search local Exploit-DB archive.

    SEARCHES:
    • Software name
    • Version numbers
    • CVE references

    TOOLS: searchsploit

    TIP: Use -m to copy exploit to current dir."

    [3]="SQLMAP

    Automated SQL injection tool.

    ATTACKS:
    • Boolean-based blind
    • Time-based blind
    • Error-based
    • UNION query

    TOOLS: sqlmap

    TIP: Use --dbs to list databases."

    [4]="REVERSE SHELL GENERATOR

    Generate reverse shell one-liners.

    LANGUAGES:
    • Bash
    • Python
    • Perl
    • PHP
    • Netcat
    • PowerShell

    CONFIGURE: LHOST and LPORT

    TIP: Start listener with 'nc -lvnp PORT'"

    [5]="PAYLOAD GENERATOR

    Create msfvenom payloads.

    OUTPUT FORMATS:
    • Windows EXE
    • Linux ELF
    • Python
    • PHP
    • ASP
    • WAR (Java)

    TOOLS: msfvenom

    TIP: Use encoders to evade AV."

    [6]="NIKTO WEB SCANNER

    Web server vulnerability scanner.

    CHECKS:
    • Outdated software
    • Default files
    • Misconfigurations
    • Known vulnerabilities

    TOOLS: nikto

    NOTE: Noisy scan, easily detected."
)

# ═══════════════════════════════════════════════════════════════════════════════
# STRESS MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA STRESS_HELP=(
    [1]="HTTP FLOOD

    Stress test HTTP/HTTPS services.

    TOOLS: slowloris, hping3, or curl

    SAFETY LIMITS:
    • Max duration: 300 seconds
    • Max connections: 10,000

    REQUIRES: Root privileges

    WARNING: Only use on authorized targets."

    [2]="SYN FLOOD

    TCP SYN packet flood.

    HOW IT WORKS:
    • Send SYN packets
    • Don't complete handshake
    • Exhaust connection table

    TOOLS: hping3

    REQUIRES: Root privileges"

    [3]="UDP FLOOD

    UDP packet flood attack.

    TARGETS: DNS, NTP, game servers

    TOOLS: hping3

    REQUIRES: Root privileges

    NOTE: Less effective against hardened targets."

    [4]="ICMP FLOOD

    Ping flood attack.

    HOW IT WORKS:
    • Send ICMP echo requests rapidly
    • Consume bandwidth
    • May crash weak targets

    TOOLS: hping3 or ping -f

    REQUIRES: Root privileges"

    [5]="CONNECTION TEST

    Test how many connections a service accepts.

    CHECKS:
    • Connection success rate
    • Response time
    • Service availability

    SAFE: Non-destructive testing."

    [6]="BANDWIDTH TEST

    Test network throughput with iperf3.

    REQUIRES: iperf3 server on target

    MEASURES:
    • Upload/download speed
    • Jitter
    • Packet loss

    TOOLS: iperf3"
)

# ═══════════════════════════════════════════════════════════════════════════════
# SETTINGS MENU DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

declare -gA SETTINGS_HELP=(
    [1]="VIEW CURRENT SETTINGS

    Display all VOIDWAVE configuration.

    SHOWS:
    • Version information
    • Directory paths
    • Environment settings
    • API keys (masked)"

    [2]="CONFIGURE LOGGING

    Set logging verbosity and output.

    LEVELS:
    0) DEBUG - Most verbose
    1) INFO - Default
    2) SUCCESS
    3) WARNING
    4) ERROR
    5) FATAL - Quietest

    FILE LOGGING: Enable/disable log files"

    [3]="CONFIGURE API KEYS

    Manage API keys for external services.

    SERVICES:
    • Shodan
    • VirusTotal
    • Censys
    • Hunter.io

    STORAGE: Encrypted in config directory"

    [4]="CONFIGURE PATHS

    Set output and log directories.

    CONFIGURABLE:
    • Output directory (captures, payloads)
    • Log directory

    DEFAULT: ~/.voidwave/"

    [5]="EXPORT CONFIGURATION

    Backup current configuration to file.

    EXPORTS: All settings and paths

    USE FOR: Backup, migration"

    [6]="IMPORT CONFIGURATION

    Restore configuration from backup.

    IMPORTS: Settings file

    WARNING: Overwrites current settings"

    [7]="RESET TO DEFAULTS

    Clear all custom settings.

    RESETS:
    • All paths to defaults
    • API keys removed
    • Logging to default

    WARNING: Cannot be undone"
)

# ═══════════════════════════════════════════════════════════════════════════════
# HELP DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Show help for a specific option
# Args: $1 = menu name (wireless, recon, etc), $2 = option number
show_option_help() {
    local menu="$1"
    local option="$2"
    local -n help_array="${menu^^}_HELP"
    
    local help_text="${help_array[$option]:-}"
    
    clear_screen 2>/dev/null || clear
    echo ""
    echo -e "    ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "    ${C_WHITE}HELP: Option $option${C_RESET}"
    echo -e "    ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    
    if [[ -n "$help_text" ]]; then
        echo "$help_text" | sed 's/^/    /'
    else
        echo -e "    ${C_SHADOW}No help available for option $option${C_RESET}"
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    echo -e "    ${C_SHADOW}Press Enter to return...${C_RESET}"
    read -r
}

# Show full help screen for a menu
# Args: $1 = menu name
show_menu_help() {
    local menu="$1"
    local -n help_array="${menu^^}_HELP"
    
    clear_screen 2>/dev/null || clear
    echo ""
    echo -e "    ${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "    ${C_WHITE}${menu^^} MENU - HELP & DESCRIPTIONS${C_RESET}"
    echo -e "    ${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    echo -e "    ${C_SHADOW}Enter option number to see detailed help, or 0 to return${C_RESET}"
    echo ""
    
    # List all available options with first line of description
    for key in $(echo "${!help_array[@]}" | tr ' ' '\n' | sort -n); do
        local first_line
        first_line=$(echo "${help_array[$key]}" | head -1 | xargs)
        printf "    ${C_CYAN}%3s${C_RESET}) %s\n" "$key" "$first_line"
    done
    
    echo ""
    echo -e "    ${C_SHADOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    
    while true; do
        echo -en "    ${C_PURPLE}?${C_RESET} Help for option [0=back]: "
        read -r choice
        
        [[ "$choice" == "0" || "$choice" == "q" || -z "$choice" ]] && return 0
        
        if [[ -n "${help_array[$choice]:-}" ]]; then
            show_option_help "$menu" "$choice"
            show_menu_help "$menu"  # Redisplay help menu
            return 0
        else
            echo -e "    ${C_RED}No help for option $choice${C_RESET}"
        fi
    done
}

# Handle help input from menu
# Args: $1 = input (? or ?<num> or h or h<num>), $2 = menu name
# Returns: 0 if help was shown, 1 if not a help request
handle_help_input() {
    local input="$1"
    local menu="$2"
    
    case "$input" in
        "?"|"h"|"H"|"help"|"HELP")
            show_menu_help "$menu"
            return 0
            ;;
        "?"[0-9]*|"h"[0-9]*|"H"[0-9]*)
            local num="${input:1}"
            show_option_help "$menu" "$num"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_option_help show_menu_help handle_help_input
