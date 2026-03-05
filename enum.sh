#!/bin/bash

# ============================================================
#  MAd3 WithL0vE  —  Recon Script
# ============================================================

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

# ---- Help ----
show_help() {
  echo -e "${BOLD}${BLUE}"
  echo "  ███╗   ███╗ █████╗ ██████╗ ██████╗ "
  echo "  ████╗ ████║██╔══██╗██╔══██╗╚════██╗"
  echo "  ██╔████╔██║███████║██║  ██║ █████╔╝"
  echo "  ██║╚██╔╝██║██╔══██║██║  ██║ ╚═══██╗"
  echo "  ██║ ╚═╝ ██║██║  ██║██████╔╝██████╔╝"
  echo "  ╚═╝     ╚═╝╚═╝  ╚═╝╚═════╝ ╚═════╝ "
  echo -e "${CYAN}         MAd3 WithL0vE — Recon Script${RESET}"
  echo ""
  echo -e "${BOLD}USAGE:${RESET}"
  echo -e "  ./enum.sh <target.com> [OPTIONS]"
  echo ""
  echo -e "${BOLD}ARGUMENTS:${RESET}"
  echo -e "  ${GREEN}<target.com>${RESET}       Target domain to enumerate (required)"
  echo ""
  echo -e "${BOLD}OPTIONS:${RESET}"
  echo -e "  ${GREEN}-h, --help${RESET}         Show this help message and exit"
  echo -e "  ${GREEN}--skip-slow${RESET}        Skip slow tools: amass, nuclei"
  echo ""
  echo -e "${BOLD}RECON STAGES:${RESET}"
  echo -e "  ${CYAN}[1]${RESET} Passive Info     whois, dig, nslookup, ASN/IP lookup, WhatWeb"
  echo -e "  ${CYAN}[2]${RESET} Port Scanning    nmap top-1000 ports (-sV -T4 -Pn)"
  echo -e "  ${CYAN}[3]${RESET} Subdomain Enum   APIs: crt.sh, anubis, rapiddns, hackertarget, OTX"
  echo -e "                   Tools: findomain, subfinder, assetfinder, sublist3r, gobuster"
  echo -e "                   Slow: amass (skip with --skip-slow)"
  echo -e "  ${CYAN}[4]${RESET} Probe Alive      httpx — filters 200/301/302/401/403/405"
  echo -e "  ${CYAN}[5]${RESET} Screenshots      gowitness or aquatone"
  echo -e "  ${CYAN}[6]${RESET} URL Scraping     gau (wayback) + katana (JS crawl)"
  echo -e "                   Extracts: .js .php .aspx .jsp URLs, params, redirect/sensitive candidates"
  echo -e "  ${CYAN}[7]${RESET} Vuln Scanning    nuclei (low→critical) (skip with --skip-slow)"
  echo -e "  ${CYAN}[8]${RESET} Summary Report   summary.txt + full recon.log"
  echo ""
  echo -e "${BOLD}OUTPUT STRUCTURE:${RESET}"
  echo -e "  ${YELLOW}<target>_<timestamp>/${RESET}"
  echo -e "  ├── info/             whois, dig, nslookup, nmap, ip/asn, whatweb"
  echo -e "  ├── subdomain/        found_subdomain.txt, responsive.txt, urllist.txt"
  echo -e "  ├── directory_enum/   (reserved for future directory brute-forcing)"
  echo -e "  ├── gau_data/         gaus.txt, jsurls, phpurls, aspxurls, jspurls, paramlist"
  echo -e "  ├── screenshots/      gowitness / aquatone output"
  echo -e "  ├── vulns/            nuclei.txt, open_redirect, sensitive_files, interesting_paths"
  echo -e "  ├── summary.txt       quick-glance stats"
  echo -e "  └── recon.log         full timestamped log"
  echo ""
  echo -e "${BOLD}EXAMPLES:${RESET}"
  echo -e "  ./enum.sh example.com"
  echo -e "  ./enum.sh example.com --skip-slow"
  echo ""
  echo -e "${BOLD}REQUIRED TOOLS (passive, always):${RESET}"
  echo -e "  whois, dig, nslookup, curl, jq, nmap"
  echo ""
  echo -e "${BOLD}OPTIONAL TOOLS (gracefully skipped if missing):${RESET}"
  echo -e "  whatweb, findomain, subfinder, assetfinder, sublist3r,"
  echo -e "  gobuster, amass, httpx/httpx-toolkit, gowitness, aquatone,"
  echo -e "  gau, katana, unfurl, nuclei"
  echo ""
}

# ---- Usage & Validation ----
if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  [ -z "$1" ] && exit 1 || exit 0
fi

TARGET=$1
SKIP_SLOW=$2  # pass --skip-slow to skip amass/nuclei
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DOMAIN="${TARGET}_${TIMESTAMP}"
INFO_PATH="$DOMAIN/info"
SUBDOMAIN_PATH="$DOMAIN/subdomain"
DIRECTORY_ENUM="$DOMAIN/directory_enum"
GAU_PATH="$DOMAIN/gau_data"
SCREENSHOT="$DOMAIN/screenshots"
VULN_PATH="$DOMAIN/vulns"

# ---- Tool check ----
check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${YELLOW}[!] $1 not found — skipping${RESET}"
    return 1
  fi
  return 0
}

# ---- Setup directories ----
for dir in "$DOMAIN" "$INFO_PATH" "$SUBDOMAIN_PATH" "$DIRECTORY_ENUM" "$GAU_PATH" "$SCREENSHOT" "$VULN_PATH"; do
  mkdir -p "$dir"
done

LOG="$DOMAIN/recon.log"
exec > >(tee -a "$LOG") 2>&1
echo -e "${GREEN}[*] Starting recon on $TARGET at $TIMESTAMP${RESET}"
echo -e "${GREEN}[*] Output folder: $DOMAIN${RESET}"

# ---- Helper: timestamped section header ----
section() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BLUE} $1${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# ============================================================
# PASSIVE INFO GATHERING
# ============================================================
section "WHOIS / DIG / NSLOOKUP"
whois "$TARGET" > "$INFO_PATH/whois.txt" && echo -e "${GREEN}[+] whois done${RESET}"
dig "$TARGET" any > "$INFO_PATH/dig.txt" && echo -e "${GREEN}[+] dig done${RESET}"
nslookup "$TARGET" > "$INFO_PATH/nslookup.txt" && echo -e "${GREEN}[+] nslookup done${RESET}"

# ASN / IP info
section "IP & ASN INFO"
IP=$(dig +short "$TARGET" | head -1)
echo "IP: $IP" | tee "$INFO_PATH/ip_asn.txt"
curl -s "https://ipinfo.io/$IP/json" | tee -a "$INFO_PATH/ip_asn.txt"
curl -s "https://api.hackertarget.com/aslookup/?q=$IP" | tee -a "$INFO_PATH/ip_asn.txt"

# ---- WhatWeb ----
section "WHATWEB"
if check_tool whatweb; then
  whatweb -a 3 "$TARGET" | tee "$INFO_PATH/whatweb.txt"
fi

# ============================================================
# PORT SCANNING
# ============================================================
section "NMAP"
if check_tool nmap; then
  # Quick top-ports scan first
  nmap -sV -T4 -Pn --top-ports 1000 "$TARGET" -oA "$INFO_PATH/nmap_quick" | \
    grep -E 'open|filtered' | tee "$INFO_PATH/nmap.txt"
fi

# ============================================================
# SUBDOMAIN ENUMERATION
# ============================================================
section "PUBLIC API SUBDOMAIN ENUM"

# Helper: strip leading dots, blank lines, and entries that don't end in target
clean_subs() {
  grep -E "\.?[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.$TARGET$" | \
    sed 's/^\.//' | grep -v "^\." | sort -u
}

# Passive APIs (run in parallel, output only to file — no terminal spam)
(
  curl -s "https://jldc.me/anubis/subdomains/$TARGET" | jq -r '.[]' 2>/dev/null | clean_subs
) >> "$SUBDOMAIN_PATH/found_subdomain.txt" &

(
  curl -s "https://rapiddns.io/subdomain/$TARGET?full=1" | grep -oE "[a-zA-Z0-9][\.a-zA-Z0-9-]*\.$TARGET" | clean_subs
) >> "$SUBDOMAIN_PATH/found_subdomain.txt" &

(
  curl -s "https://crt.sh/?q=%25.$TARGET" | grep -oE "[a-zA-Z0-9][\.a-zA-Z0-9-]*\.$TARGET" | clean_subs
) >> "$SUBDOMAIN_PATH/found_subdomain.txt" &

(
  curl -s "https://api.hackertarget.com/hostsearch/?q=$TARGET" | cut -d',' -f1 | clean_subs
) >> "$SUBDOMAIN_PATH/found_subdomain.txt" &

(
  curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$TARGET/passive_dns" | \
    jq -r '.passive_dns[].hostname' 2>/dev/null | clean_subs
) >> "$SUBDOMAIN_PATH/found_subdomain.txt" &

wait
echo -e "${GREEN}[+] Passive API collection done${RESET}"

section "TOOL-BASED SUBDOMAIN ENUM"
check_tool findomain   && findomain -t "$TARGET" -q 2>/dev/null | clean_subs >> "$SUBDOMAIN_PATH/found_subdomain.txt"
check_tool subfinder   && subfinder -silent -d "$TARGET" 2>/dev/null | clean_subs >> "$SUBDOMAIN_PATH/found_subdomain.txt"
check_tool assetfinder && assetfinder --subs-only "$TARGET" 2>/dev/null | clean_subs >> "$SUBDOMAIN_PATH/found_subdomain.txt"
check_tool sublist3r   && sublist3r -d "$TARGET" -o "$SUBDOMAIN_PATH/sublist3r.txt" -q 2>/dev/null && \
  clean_subs < "$SUBDOMAIN_PATH/sublist3r.txt" >> "$SUBDOMAIN_PATH/found_subdomain.txt"

# DNS brute (faster wordlist by default)
if check_tool gobuster; then
  WORDLIST="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
  [ ! -f "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/dirb/common.txt"
  gobuster dns -d "$TARGET" -w "$WORDLIST" -q 2>/dev/null | \
    grep -oE "[a-zA-Z0-9][\.a-zA-Z0-9-]*\.$TARGET" | clean_subs >> "$SUBDOMAIN_PATH/found_subdomain.txt"
fi

# Amass — slow, skip with --skip-slow
if [ "$SKIP_SLOW" != "--skip-slow" ] && check_tool amass; then
  section "AMASS (passive)"
  amass enum -passive -d "$TARGET" 2>/dev/null | clean_subs >> "$SUBDOMAIN_PATH/found_subdomain.txt"
fi

# Deduplicate
sort -u "$SUBDOMAIN_PATH/found_subdomain.txt" -o "$SUBDOMAIN_PATH/found_subdomain.txt"
TOTAL=$(wc -l < "$SUBDOMAIN_PATH/found_subdomain.txt")
echo -e "${GREEN}[+] $TOTAL unique subdomains found${RESET}"

# ============================================================
# PROBE ALIVE SUBDOMAINS
# ============================================================
section "PROBING ALIVE SUBDOMAINS"
if check_tool httpx-toolkit || check_tool httpx; then
  HTTPX=$(command -v httpx-toolkit || command -v httpx)
  cat "$SUBDOMAIN_PATH/found_subdomain.txt" | \
    $HTTPX -mc 200,301,302,403,401,405 -silent -threads 50 | \
    tee "$SUBDOMAIN_PATH/responsive.txt"

  # Clean URL list (strip protocol)
  sed -E 's|https?://||g' "$SUBDOMAIN_PATH/responsive.txt" | sort -u > "$SUBDOMAIN_PATH/urllist.txt"
  echo -e "${GREEN}[+] $(wc -l < "$SUBDOMAIN_PATH/urllist.txt") live subdomains${RESET}"
fi

# ============================================================
# SCREENSHOTS
# ============================================================
section "SCREENSHOTS"
if check_tool gowitness; then
  gowitness file -f "$SUBDOMAIN_PATH/responsive.txt" -P "$SCREENSHOT" --no-http
elif check_tool aquatone; then
  cat "$SUBDOMAIN_PATH/responsive.txt" | aquatone -silent -out "$SCREENSHOT"
fi

# ============================================================
# GAU / URL SCRAPING
# ============================================================
section "GAU - WAYBACK SCRAPING"
if check_tool gau; then
  cat "$SUBDOMAIN_PATH/urllist.txt" | gau --threads 5 | tee "$GAU_PATH/gaus.txt"

  # Also try katana for JS crawling
  if check_tool katana; then
    cat "$SUBDOMAIN_PATH/responsive.txt" | katana -silent -jc | tee -a "$GAU_PATH/gaus.txt"
  fi

  sort -u "$GAU_PATH/gaus.txt" -o "$GAU_PATH/gaus.txt"

  # Extract interesting URLs by type
  grep -P "\w+\.js(\?|$)"   "$GAU_PATH/gaus.txt" | sort -u > "$GAU_PATH/jsurls.txt"
  grep -P "\w+\.php(\?|$)"  "$GAU_PATH/gaus.txt" | sort -u > "$GAU_PATH/phpurls.txt"
  grep -P "\w+\.aspx(\?|$)" "$GAU_PATH/gaus.txt" | sort -u > "$GAU_PATH/aspxurls.txt"
  grep -P "\w+\.jsp(\?|$)"  "$GAU_PATH/gaus.txt" | sort -u > "$GAU_PATH/jspurls.txt"

  # Parameters & endpoints
  check_tool unfurl && cat "$GAU_PATH/gaus.txt" | unfurl --unique keys > "$GAU_PATH/paramlist.txt"

  # Interesting patterns — potential vulns
  grep -iE "redirect|url=|next=|return=|goto=" "$GAU_PATH/gaus.txt" | sort -u > "$VULN_PATH/open_redirect_candidates.txt"
  grep -iE "\.sql|\.bak|\.env|\.log|\.conf|\.zip|\.tar" "$GAU_PATH/gaus.txt" | sort -u > "$VULN_PATH/sensitive_file_candidates.txt"
  grep -iE "admin|dashboard|panel|config|backup|\.git" "$GAU_PATH/gaus.txt" | sort -u > "$VULN_PATH/interesting_paths.txt"

  for f in jsurls phpurls aspxurls jspurls paramlist; do
    COUNT=$(wc -l < "$GAU_PATH/${f}.txt" 2>/dev/null || echo 0)
    [ "$COUNT" -gt 0 ] && echo -e "${GREEN}[+] $COUNT entries → $GAU_PATH/${f}.txt${RESET}"
  done
fi

# ============================================================
# VULNERABILITY SCANNING
# ============================================================
if [ "$SKIP_SLOW" != "--skip-slow" ]; then
  section "NUCLEI SCANNING"
  if check_tool nuclei; then
    # Severity-filtered, skip info noise
    nuclei -l "$SUBDOMAIN_PATH/urllist.txt" \
      -severity low,medium,high,critical \
      -silent \
      -o "$VULN_PATH/nuclei.txt" \
      -stats
    echo -e "${GREEN}[+] Nuclei done → $VULN_PATH/nuclei.txt${RESET}"
  fi
fi

# ============================================================
# SUMMARY REPORT
# ============================================================
section "SUMMARY"
SUMMARY="$DOMAIN/summary.txt"
{
  echo "===== RECON SUMMARY: $TARGET ====="
  echo "Date: $TIMESTAMP"
  echo ""
  echo "Subdomains found:  $(wc -l < "$SUBDOMAIN_PATH/found_subdomain.txt" 2>/dev/null || echo 0)"
  echo "Live subdomains:   $(wc -l < "$SUBDOMAIN_PATH/urllist.txt" 2>/dev/null || echo 0)"
  echo "Total URLs (gau):  $(wc -l < "$GAU_PATH/gaus.txt" 2>/dev/null || echo 0)"
  echo "JS URLs:           $(wc -l < "$GAU_PATH/jsurls.txt" 2>/dev/null || echo 0)"
  echo "Parameters:        $(wc -l < "$GAU_PATH/paramlist.txt" 2>/dev/null || echo 0)"
  echo "Nuclei findings:   $(wc -l < "$VULN_PATH/nuclei.txt" 2>/dev/null || echo 0)"
  echo ""
  echo "Open redirect candidates: $(wc -l < "$VULN_PATH/open_redirect_candidates.txt" 2>/dev/null || echo 0)"
  echo "Sensitive files:          $(wc -l < "$VULN_PATH/sensitive_file_candidates.txt" 2>/dev/null || echo 0)"
  echo "Interesting paths:        $(wc -l < "$VULN_PATH/interesting_paths.txt" 2>/dev/null || echo 0)"
  echo ""
  echo "Output directory: $DOMAIN/"
} | tee "$SUMMARY"

echo -e "\n${GREEN}[✓] DONE — full log at $LOG${RESET}\n"
exit 0
