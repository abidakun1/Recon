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
# FIX GO PATH (sudo loses the user's PATH)
# ============================================================
# Try common Go install locations
for GO_CANDIDATE in /usr/local/go/bin/go /usr/bin/go /snap/bin/go; do
  if [ -x "$GO_CANDIDATE" ]; then
    export PATH="$(dirname $GO_CANDIDATE):$PATH"
    break
  fi
done

# If Go still not found, install it
if ! command -v go &>/dev/null; then
  warn "Go not found — installing Go 1.22"
  wget -q https://go.dev/dl/go1.22.4.linux-amd64.tar.gz -O /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
  # Persist for future shells
  echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile.d/golang.sh
  ok "Go installed: $(go version)"
else
  ok "Go found: $(go version)"
fi

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# ============================================================
# APT PACKAGES
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
# ============================================================
install_go_tool() {
  local name=$1
  local pkg=$2
  local bin=$(basename ${pkg%@*})
  go install "$pkg" 2>/dev/null
  # Copy to /usr/bin so it works for all users without Go in PATH
  [ -f "$GOPATH/bin/$bin" ] && cp "$GOPATH/bin/$bin" /usr/bin/ && ok "$name installed" || warn "$name failed"
}

install_go_tool "gau"       "github.com/lc/gau/v2/cmd/gau@latest"
install_go_tool "katana"    "github.com/projectdiscovery/katana/cmd/katana@latest"
install_go_tool "gowitness" "github.com/sensepost/gowitness@latest"
install_go_tool "httpx"     "github.com/projectdiscovery/httpx/cmd/httpx@latest"

# ============================================================
# UNFURL
# ============================================================
wget -q "https://github.com/tomnomnom/unfurl/releases/download/v0.4.3/unfurl-linux-amd64-0.4.3.tgz" \
  -O /tmp/unfurl.tgz && \
  tar xzf /tmp/unfurl.tgz -C /tmp && \
  mv /tmp/unfurl /usr/bin/ && \
  ok "unfurl installed" || warn "unfurl failed"

# ============================================================
# AQUATONE
# ============================================================
wget -q "https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip" \
  -O /tmp/aquatone.zip && \
  unzip -q /tmp/aquatone.zip -d /tmp/aquatone && \
  mv /tmp/aquatone/aquatone /usr/bin/ && \
  ok "aquatone installed" || warn "aquatone failed"

# ============================================================
# FINDOMAIN
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
# SECLISTS — skip if already installed via apt (Kali has it)
# ============================================================
if [ ! -d "/usr/share/seclists" ] && [ ! -d "/usr/share/wordlists/seclists" ]; then
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
ok "ALL DONE — re-open your terminal or run: source /etc/profile.d/golang.sh"
exit 0
