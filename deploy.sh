#!/bin/bash
# ============================================
# PRO VPN SSH SERVER - GCP DEPLOYMENT v3.0
# Full Professional Suite | No Errors
# SSH + TLS + Squid + V2Ray + Trojan
# ============================================
clear

# ============================================
# COLOR DEFINITIONS
# ============================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
BG_RED='\033[41m'; BG_GREEN='\033[42m'; BG_BLUE='\033[44m'

# ============================================
# ERROR HANDLING
# ============================================
set -e
trap 'echo -e "\n${BG_RED}${WHITE} [FATAL] Script failed at line $LINENO ${RESET}"; exit 1' ERR

error_exit() { echo -e "\n${BG_RED}${WHITE} [FATAL] $1 ${RESET}"; exit 1; }
success() { echo -e "  ${GREEN}[OK]${RESET} $1"; }
info() { echo -e "  ${CYAN}[*]${RESET} $1"; }
warn() { echo -e "  ${YELLOW}[!]${RESET} $1"; }
section() { echo -e "\n${BOLD}${WHITE}[$1]${RESET} ${CYAN}$2${RESET}"; }

# ============================================
# CUSTOMIZABLE CREDENTIALS
# ============================================
SERVICE_NAME="vpn-pro-server"
SSH_USER="proxyadmin"
SSH_PASS="ProxySecure@2025"
ROOT_PASS="RootSecure@2025"
SSH_PORT="22"
TLS_PORT="443"
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) SERVICE_NAME="$2"; shift 2 ;;
        --user) SSH_USER="$2"; shift 2 ;;
        --pass) SSH_PASS="$2"; shift 2 ;;
        --root) ROOT_PASS="$2"; shift 2 ;;
        --ssh-port) SSH_PORT="$2"; shift 2 ;;
        --tls-port) TLS_PORT="$2"; shift 2 ;;
        --zone) ZONE="$2"; shift 2 ;;
        --machine) MACHINE_TYPE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

FIREWALL_SSH="allow-${SERVICE_NAME}-ssh-${SSH_PORT}"
FIREWALL_TLS="allow-${SERVICE_NAME}-tls-${TLS_PORT}"

# ============================================
# BANNER
# ============================================
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║   ${WHITE}██████╗ ██████╗  ██████╗     ${CYAN}██╗   ██╗██████╗ ███╗   ██╗       ${RESET}${CYAN}${BOLD}║"
echo "║   ${WHITE}██╔══██╗██╔══██╗██╔═══██╗    ${CYAN}██║   ██║██╔══██╗████╗  ██║       ${RESET}${CYAN}${BOLD}║"
echo "║   ${WHITE}██████╔╝██████╔╝██║   ██║    ${CYAN}██║   ██║██████╔╝██╔██╗ ██║       ${RESET}${CYAN}${BOLD}║"
echo "║   ${WHITE}██╔═══╝ ██╔══██╗██║   ██║    ${CYAN}╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║       ${RESET}${CYAN}${BOLD}║"
echo "║   ${WHITE}██║     ██║  ██║╚██████╔╝    ${CYAN} ╚████╔╝ ██║     ██║ ╚████║       ${RESET}${CYAN}${BOLD}║"
echo "║   ${WHITE}╚═╝     ╚═╝  ╚═╝ ╚═════╝     ${CYAN}  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝       ${RESET}${CYAN}${BOLD}║"
echo "║                                                                  ║"
echo "║   ${WHITE}SSH + TLS + Squid + V2Ray + Trojan - GCP Deployment${CYAN}              ${RESET}${CYAN}${BOLD}║"
echo "║   ${DIM}Professional VPN Protocol Suite v3.0${CYAN}${BOLD}                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ============================================
# CONFIGURATION SUMMARY
# ============================================
echo ""
echo -e "${YELLOW}${BOLD}  CONFIGURATION SUMMARY${RESET}"
echo -e "  ${CYAN}Service:${RESET}     ${WHITE}$SERVICE_NAME${RESET}"
echo -e "  ${CYAN}SSH User:${RESET}     ${WHITE}$SSH_USER${RESET}"
echo -e "  ${CYAN}SSH Pass:${RESET}     ${WHITE}$SSH_PASS${RESET}"
echo -e "  ${CYAN}SSH Port:${RESET}     ${WHITE}$SSH_PORT${RESET}"
echo -e "  ${CYAN}TLS Port:${RESET}     ${WHITE}$TLS_PORT${RESET}"
echo -e "  ${CYAN}Zone:${RESET}         ${WHITE}$ZONE${RESET}"
echo -e "  ${CYAN}Machine:${RESET}      ${WHITE}$MACHINE_TYPE${RESET}"
echo ""

# ============================================
# CHECK PREREQUISITES
# ============================================
section "1/6" "CHECKING PREREQUISITES"

if ! command -v gcloud &> /dev/null; then
    error_exit "gcloud CLI not found. Run in Cloud Shell."
fi

ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")
if [ -z "$ACCOUNT" ]; then
    error_exit "Not authenticated. Run: gcloud auth login"
fi
success "Authenticated: $ACCOUNT"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud projects list --format='value(projectId)' --limit=1 2>/dev/null || echo "")
    if [ -z "$PROJECT_ID" ]; then
        error_exit "No project found."
    fi
    gcloud config set project "$PROJECT_ID" 2>/dev/null
fi
success "Project: $PROJECT_ID"

# ============================================
# ENABLE APIS
# ============================================
section "2/6" "ENABLING APIS"

gcloud services enable compute.googleapis.com --quiet 2>/dev/null
success "Compute Engine API enabled"

# ============================================
# FIREWALL
# ============================================
section "3/6" "CONFIGURING FIREWALL"

for rule in $FIREWALL_SSH $FIREWALL_TLS "allow-${SERVICE_NAME}-8080" "allow-${SERVICE_NAME}-3128" "allow-${SERVICE_NAME}-8888"; do
    gcloud compute firewall-rules delete "$rule" --quiet 2>/dev/null || true
done

gcloud compute firewall-rules create "$FIREWALL_SSH" \
    --allow tcp:${SSH_PORT} --direction=INGRESS --priority=1000 --quiet 2>/dev/null
success "SSH firewall created (port $SSH_PORT)"

gcloud compute firewall-rules create "$FIREWALL_TLS" \
    --allow tcp:${TLS_PORT} --direction=INGRESS --priority=1000 --quiet 2>/dev/null
success "TLS firewall created (port $TLS_PORT)"

for port in 8080 3128 8888 2083 2087 2096; do
    gcloud compute firewall-rules create "allow-${SERVICE_NAME}-${port}" \
        --allow tcp:${port} --direction=INGRESS --priority=1000 --quiet 2>/dev/null
done
success "Additional ports opened"

# ============================================
# BUILD STARTUP SCRIPT
# ============================================
section "4/6" "BUILDING DEPLOYMENT CONFIG"

TMP_DIR=$(mktemp -d)

cat > "$TMP_DIR/startup-script.sh" << 'STARTUPEOF'
#!/bin/bash
set -e

# Read metadata
SSH_USER=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SSH_USER" -H "Metadata-Flavor: Google" || echo "proxyadmin")
SSH_PASS=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SSH_PASS" -H "Metadata-Flavor: Google")
SSH_PORT=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SSH_PORT" -H "Metadata-Flavor: Google" || echo "22")
TLS_PORT=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/TLS_PORT" -H "Metadata-Flavor: Google" || echo "443")
ROOT_PASS=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ROOT_PASS" -H "Metadata-Flavor: Google")

LOG="/var/log/vpn-setup.log"
echo "[$(date)] Starting VPN Server Setup" > "$LOG"

# Update system
apt-get update -y >> "$LOG" 2>&1
apt-get upgrade -y -qq >> "$LOG" 2>&1

# Install packages
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    nginx squid stunnel4 openssl docker.io curl wget netcat-openbsd \
    certbot python3 python3-pip sshpass qrencode >> "$LOG" 2>&1

# ============================================
# SSL CERTIFICATE
# ============================================
PUBLIC_IP=$(curl -sf http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
mkdir -p /etc/ssl/vpn
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=CA/L=City/O=VPN/CN=${PUBLIC_IP}" \
    -keyout /etc/ssl/vpn/server.key \
    -out /etc/ssl/vpn/server.crt 2>> "$LOG"
cat /etc/ssl/vpn/server.crt /etc/ssl/vpn/server.key > /etc/ssl/vpn/server.pem
chmod 600 /etc/ssl/vpn/server.pem

# ============================================
# SSH CONTAINER
# ============================================
systemctl enable docker
systemctl start docker
docker rm -f ssh-server 2>/dev/null || true

cat > /root/Dockerfile.ssh << 'DOCKEREOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server sudo curl wget net-tools socat python3 sshpass \
    vim nano htop && mkdir -p /var/run/sshd && apt-get clean
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config && \
    echo 'GatewayPorts yes' >> /etc/ssh/sshd_config && \
    echo 'PermitTunnel yes' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'MaxSessions 100' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd yes' >> /etc/ssh/sshd_config && \
    echo 'Port 22' >> /etc/ssh/sshd_config
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
DOCKEREOF

docker build -t ssh-pro-image /root/ -f /root/Dockerfile.ssh >> "$LOG" 2>&1
docker run -d --name ssh-server --restart unless-stopped \
    --network host --cap-add=NET_ADMIN --privileged \
    ssh-pro-image >> "$LOG" 2>&1

sleep 3

# Configure user
docker exec ssh-server bash -c "
    useradd -rm -d /home/$SSH_USER -s /bin/bash -G sudo,root $SSH_USER 2>/dev/null || true
    echo '$SSH_USER:$SSH_PASS' | chpasswd
    echo 'root:$ROOT_PASS' | chpasswd
    echo '$SSH_USER ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/$SSH_USER
    # MOTD Banner
    cat > /etc/motd << 'MOTD'
\033[1;36m
╔══════════════════════════════════════════╗
║     PRO VPN SERVER - READY              ║
║     Authorized Access Only              ║
╚══════════════════════════════════════════╝
\033[0m
MOTD
    # Change SSH port
    sed -i 's/Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config
    echo 'Port $SSH_PORT' >> /etc/ssh/sshd_config
" >> "$LOG" 2>&1

docker exec ssh-server service ssh restart >> "$LOG" 2>&1 || docker exec ssh-server kill -HUP 1 2>/dev/null
echo "SSH container ready" >> "$LOG"

# ============================================
# STUNNEL TLS
# ============================================
cat > /etc/stunnel/stunnel.conf << STUNEOF
cert = /etc/ssl/vpn/server.pem
pid = /var/run/stunnel.pid

[ssh-tls]
accept = 0.0.0.0:$TLS_PORT
connect = 127.0.0.1:$SSH_PORT
TIMEOUTclose = 0
STUNEOF

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true
systemctl restart stunnel4 2>/dev/null || stunnel4 /etc/stunnel/stunnel.conf &
echo "Stunnel ready on port $TLS_PORT" >> "$LOG"

# ============================================
# SQUID PROXY
# ============================================
cat > /etc/squid/squid.conf << SQUIDEOF
http_port 0.0.0.0:3128
acl all src 0.0.0.0/0
http_access allow all
forwarded_for delete
via off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
access_log /var/log/squid/access.log
SQUIDEOF
systemctl restart squid
echo "Squid ready on port 3128" >> "$LOG"

# ============================================
# V2RAY
# ============================================
bash <(curl -sL https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) >> "$LOG" 2>&1
UUID=$(cat /proc/sys/kernel/random/uuid)

cat > /usr/local/etc/v2ray/config.json << V2RAYEOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 8888, "protocol": "vmess",
      "settings": {"clients": [{"id": "$UUID", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 2083, "protocol": "vless",
      "settings": {"clients": [{"id": "$UUID"}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 2087, "protocol": "vmess",
      "settings": {"clients": [{"id": "$UUID", "alterId": 0}]},
      "streamSettings": {
        "network": "tcp", "security": "tls",
        "tlsSettings": {"certificates": [{"certificateFile": "/etc/ssl/vpn/server.crt", "keyFile": "/etc/ssl/vpn/server.key"}]}
      }
    }
  ],
  "outbounds": [{"protocol": "freedom", "settings": {}}]
}
V2RAYEOF

systemctl enable v2ray
systemctl restart v2ray
echo "$UUID" > /etc/v2ray-uuid.txt
echo "V2Ray ready" >> "$LOG"

# ============================================
# TROJAN
# ============================================
bash <(curl -sL https://raw.githubusercontent.com/trojan-gfw/trojan/master/scripts/install.sh) >> "$LOG" 2>&1
TROJAN_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)

cat > /usr/local/etc/trojan/config.json << TROJANEOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 2096,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": ["$TROJAN_PASS"],
  "ssl": {"cert": "/etc/ssl/vpn/server.crt", "key": "/etc/ssl/vpn/server.key"}
}
TROJANEOF

systemctl enable trojan
systemctl restart trojan
echo "$TROJAN_PASS" > /etc/trojan-password.txt
echo "Trojan ready" >> "$LOG"

# ============================================
# NGINX WEBSOCKET
# ============================================
cat > /etc/nginx/conf.d/websocket.conf << 'NGXEOF'
server {
    listen 8080;
    location /vmess { proxy_pass http://127.0.0.1:8888; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; }
    location /vless { proxy_pass http://127.0.0.1:2083; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; }
    location / { return 200 '{"status":"ok","server":"PRO VPN"}'; add_header Content-Type application/json; }
}
NGXEOF
systemctl restart nginx
echo "Nginx WebSocket ready" >> "$LOG"

# ============================================
# SAVE REPORT
# ============================================
cat > /root/vpn-report.txt << REPORTEOF
============================================
PRO VPN SERVER - FULL REPORT
============================================
Server IP: $PUBLIC_IP
============================================
[SSH]
Port: $SSH_PORT
User: $SSH_USER
Pass: $SSH_PASS
Root: $ROOT_PASS

[TLS/Stunnel]
Port: $TLS_PORT
Connect: ssh $SSH_USER@$PUBLIC_IP -p $TLS_PORT

[Squid Proxy]
Port: 3128
Use: curl -x http://$PUBLIC_IP:3128 https://example.com

[V2Ray VMess WS]
Port: 8888
Path: /vmess
UUID: $UUID

[V2Ray VLESS WS]
Port: 2083
Path: /vless
UUID: $UUID

[V2Ray VMess TLS]
Port: 2087
UUID: $UUID

[Trojan]
Port: 2096
Password: $TROJAN_PASS

[WebSocket]
Port: 8080
============================================
REPORTEOF

echo "SETUP_COMPLETE" > /var/log/vpn-setup-complete.log
echo "[$(date)] ALL DONE" >> "$LOG"
STARTUPEOF

chmod +x "$TMP_DIR/startup-script.sh"
success "Startup script built"

# ============================================
# DEPLOY VM
# ============================================
section "5/6" "DEPLOYING VIRTUAL MACHINE"

if gcloud compute instances describe "$SERVICE_NAME" --zone="$ZONE" --quiet 2>/dev/null; then
    warn "Removing existing VM: $SERVICE_NAME"
    gcloud compute instances delete "$SERVICE_NAME" --zone="$ZONE" --quiet 2>/dev/null
    sleep 5
fi

gcloud compute instances create "$SERVICE_NAME" \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --machine-type="$MACHINE_TYPE" \
    --zone="$ZONE" \
    --tags="${FIREWALL_SSH},${FIREWALL_TLS}" \
    --metadata-from-file startup-script="$TMP_DIR/startup-script.sh" \
    --metadata="SSH_USER=$SSH_USER,SSH_PASS=$SSH_PASS,SSH_PORT=$SSH_PORT,TLS_PORT=$TLS_PORT,ROOT_PASS=$ROOT_PASS,SERVICE_NAME=$SERVICE_NAME" \
    --boot-disk-size=30GB \
    --boot-disk-type=pd-standard \
    --quiet 2>/dev/null

success "VM deployed: $SERVICE_NAME"
rm -rf "$TMP_DIR"

# ============================================
# GET IP + VERIFY
# ============================================
section "6/6" "VERIFYING DEPLOYMENT"

sleep 20
PUBLIC_IP=$(gcloud compute instances describe "$SERVICE_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "")

if [ -z "$PUBLIC_IP" ]; then
    for i in {1..12}; do
        sleep 10
        PUBLIC_IP=$(gcloud compute instances describe "$SERVICE_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "")
        [ -n "$PUBLIC_IP" ] && break
    done
fi

if [ -z "$PUBLIC_IP" ]; then
    error_exit "Could not retrieve public IP. Check: gcloud compute instances list"
fi

success "Server IP: $PUBLIC_IP"

# Wait for SSH
info "Waiting for SSH to become available..."
for i in {1..24}; do
    if nc -zv -w 3 "$PUBLIC_IP" "$SSH_PORT" 2>/dev/null; then
        break
    fi
    sleep 10
done

# ============================================
# FINAL OUTPUT
# ============================================
echo ""
echo -e "${BG_GREEN}${WHITE}${BOLD}                                                                      ${RESET}"
echo -e "${BG_GREEN}${WHITE}${BOLD}     PRO VPN SERVER - DEPLOYMENT COMPLETE                               ${RESET}"
echo -e "${BG_GREEN}${WHITE}${BOLD}                                                                      ${RESET}"
echo ""
echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}  ║  SERVER CONNECTION DETAILS                                       ║${RESET}"
echo -e "${CYAN}${BOLD}  ╚══════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${WHITE}Server IP:${RESET}     ${GREEN}${BOLD}$PUBLIC_IP${RESET}"
echo -e "  ${WHITE}SSH Port:${RESET}      ${BOLD}$SSH_PORT${RESET}"
echo -e "  ${WHITE}TLS Port:${RESET}      ${BOLD}$TLS_PORT${RESET}"
echo -e "  ${WHITE}Username:${RESET}      ${BOLD}$SSH_USER${RESET}"
echo -e "  ${WHITE}Password:${RESET}      ${BOLD}$SSH_PASS${RESET}"
echo -e "  ${WHITE}Root Pass:${RESET}     ${BOLD}$ROOT_PASS${RESET}"
echo -e "  ${WHITE}Squid:${RESET}         ${BOLD}3128${RESET}"
echo -e "  ${WHITE}V2Ray WS:${RESET}     ${BOLD}8888${RESET}"
echo -e "  ${WHITE}V2Ray TLS:${RESET}    ${BOLD}2087${RESET}"
echo -e "  ${WHITE}Trojan:${RESET}       ${BOLD}2096${RESET}"
echo ""
echo -e "  ${GREEN}[Direct SSH]${RESET}      ssh $SSH_USER@$PUBLIC_IP -p $SSH_PORT"
echo -e "  ${GREEN}[SSH over TLS]${RESET}   ssh $SSH_USER@$PUBLIC_IP -p $TLS_PORT"
echo -e "  ${GREEN}[SOCKS5 VPN]${RESET}     ssh -D 1080 -N -p $SSH_PORT $SSH_USER@$PUBLIC_IP"
echo -e "  ${GREEN}[Squid Proxy]${RESET}    curl -x http://$PUBLIC_IP:3128 https://google.com"
echo ""
echo -e "  ${RED}[Delete Server]${RESET}   gcloud compute instances delete $SERVICE_NAME --zone=$ZONE --quiet"
echo ""

# Save credentials file
cat > "$HOME/vpn-credentials-${SERVICE_NAME}.txt" << CREDEOF
============================================
PRO VPN SERVER CREDENTIALS
============================================
Server: $PUBLIC_IP
SSH Port: $SSH_PORT
TLS Port: $TLS_PORT
User: $SSH_USER
Pass: $SSH_PASS
Root: $ROOT_PASS
V2Ray UUID: $(cat /etc/v2ray-uuid.txt 2>/dev/null || echo "check /etc/v2ray-uuid.txt on server")
Trojan Pass: $(cat /etc/trojan-password.txt 2>/dev/null || echo "check /etc/trojan-password.txt on server")
============================================
CREDEOF

echo -e "  ${GREEN}[OK]${RESET} Credentials saved: $HOME/vpn-credentials-${SERVICE_NAME}.txt"
echo ""
echo -e "${BG_BLUE}${WHITE}${BOLD}  $PUBLIC_IP:$SSH_PORT | $SSH_USER | TLS:$TLS_PORT | Squid:3128  ${RESET}"
echo ""
