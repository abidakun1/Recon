#!/bin/bash

# ============================================================
#  MAd3 WithL0vE — Installer
# ============================================================

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

if [[ "$(whoami)" != "root" ]]; then
  echo "Only root can run this script."
  exit 1
fi

ok()   { echo -e "${GREEN}[+] $1${RESET}"; }
warn() { echo -e "${YELLOW}[!] $1 — skipping${RESET}"; }
fail() { echo -e "${RED}[-] $1${RESET}"; }

# ============================================================
# APT PACKAGES
# New vs original: added gobuster, jq, gowitness deps, katana deps
# ============================================================
LIST_OF_APPS="
  wapiti cargo amass dirsearch sublist3r subfinder assetfinder
  nuclei httprobe dnsrecon httpx-toolkit gobuster
  nmap curl wget git unzip jq python3 python3-pip
"

apt-get update && apt-get install -y $LIST_OF_APPS
if [[ $? -ne 0 ]]; then
  fail "Failed to install apt packages. Exiting."
  exit 1
fi
ok "APT packages installed"

# ============================================================
# GO TOOLS
# New vs original: added katana, gowitness
# ============================================================
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

install_go_tool() {
  local name=$1
  local pkg=$2
  go install "$pkg" 2>/dev/null && cp "$GOPATH/bin/$(basename ${pkg%@*})" /usr/bin/ 2>/dev/null
  command -v "$(basename ${pkg%@*})" &>/dev/null && ok "$name installed" || warn "$name failed"
}

install_go_tool "gau"      "github.com/lc/gau/v2/cmd/gau@latest"
install_go_tool "katana"   "github.com/projectdiscovery/katana/cmd/katana@latest"
install_go_tool "gowitness" "github.com/sensepost/gowitness@latest"
install_go_tool "httpx"    "github.com/projectdiscovery/httpx/cmd/httpx@latest"

# ============================================================
# UNFURL (same as original, updated to newer version)
# ============================================================
UNFURL_URL="https://github.com/tomnomnom/unfurl/releases/download/v0.4.3/unfurl-linux-amd64-0.4.3.tgz"
wget -q "$UNFURL_URL" -O /tmp/unfurl.tgz && \
  tar xzf /tmp/unfurl.tgz -C /tmp && \
  mv /tmp/unfurl /usr/bin/ && \
  ok "unfurl installed" || warn "unfurl failed"

# ============================================================
# AQUATONE (same as original)
# ============================================================
wget -q "https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip" \
  -O /tmp/aquatone.zip && \
  unzip -q /tmp/aquatone.zip -d /tmp/aquatone && \
  mv /tmp/aquatone/aquatone /usr/bin/ && \
  ok "aquatone installed" || warn "aquatone failed"

# ============================================================
# FINDOMAIN (same as original but cleaner)
# ============================================================
if ! command -v findomain &>/dev/null; then
  cd /tmp && git clone -q https://github.com/Edu4rdSHL/findomain.git && \
    cd findomain && cargo build --release && \
    cp target/release/findomain /usr/bin/ && \
    ok "findomain installed" || warn "findomain build failed"
else
  ok "findomain already installed"
fi

# ============================================================
# SECLISTS (apt version is often outdated — use git)
# ============================================================
if [ ! -d "/usr/share/seclists" ]; then
  git clone -q --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists && \
    ok "SecLists installed" || warn "SecLists clone failed"
else
  ok "SecLists already present"
fi

# ============================================================
# CLEANUP
# ============================================================
rm -rf /tmp/unfurl.tgz /tmp/aquatone.zip /tmp/aquatone /tmp/findomain
apt-get autoremove -y &>/dev/null
apt-get clean &>/dev/null

echo ""
ok "ALL DONE"
exit 0
