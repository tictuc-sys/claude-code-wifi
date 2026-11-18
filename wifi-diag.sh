#!/usr/bin/env bash
# Diagnostic Wi-Fi local (macOS / Linux). Lecture seule : ne modifie rien.
# Usage : bash wifi-diag.sh > rapport.txt 2>&1
set -u
OS="$(uname -s)"
hr(){ printf '\n===== %s =====\n' "$1"; }

hr "Système"; date; uname -a

hr "Passerelle (routeur)"
if [ "$OS" = Darwin ]; then
  GW="$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')"
  IF="$(route -n get default 2>/dev/null | awk '/interface/{print $2}')"
else
  GW="$(ip route | awk '/^default/{print $3; exit}')"
  IF="$(ip route | awk '/^default/{print $5; exit}')"
fi
echo "Routeur : ${GW:-inconnu}   Interface : ${IF:-inconnue}"

hr "Lien Wi-Fi (signal, bruit, canal, débit PHY)"
if [ "$OS" = Darwin ]; then
  # 'airport' a été retiré dans macOS récents ; system_profiler fonctionne partout
  system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Current Network Information/,/Other Local Wi-Fi Networks/p'
  command -v wdutil >/dev/null && echo "(Pour plus de détails : sudo wdutil info)"
else
  if command -v iw >/dev/null && [ -n "${IF:-}" ]; then iw dev "$IF" link; iw dev "$IF" info; fi
  command -v nmcli >/dev/null && nmcli -f IN-USE,SSID,CHAN,FREQ,RATE,SIGNAL,SECURITY dev wifi list
fi

hr "Réseaux voisins (congestion des canaux)"
if [ "$OS" = Darwin ]; then
  system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Other Local Wi-Fi Networks/,$p' | grep -E 'Channel|Signal|^ {10}[^ ]' | head -80
else
  command -v nmcli >/dev/null && nmcli -f SSID,CHAN,SIGNAL dev wifi list | sort -k2 -n
fi

hr "Latence et pertes vers le routeur (Wi-Fi seul)"
[ -n "${GW:-}" ] && ping -c 30 -i 0.2 "$GW" | tail -3

hr "Latence et pertes vers Internet"
ping -c 20 -i 0.2 1.1.1.1 | tail -3

hr "Résolution DNS"
for d in google.com apple.com wikipedia.org; do
  /usr/bin/time -p nslookup "$d" >/dev/null 2>/tmp/dns.$$; printf '%-15s %ss\n' "$d" "$(awk '/real/{print $2}' /tmp/dns.$$)"
done; rm -f /tmp/dns.$$
cat /etc/resolv.conf 2>/dev/null | grep nameserver

hr "Débit et réactivité sous charge (bufferbloat)"
if [ "$OS" = Darwin ] && command -v networkQuality >/dev/null; then
  networkQuality -v
else
  echo "Linux : installer 'speedtest-cli' ou tester sur https://www.waveform.com/tools/bufferbloat"
fi

hr "Appareils visibles sur le réseau local (table ARP)"
arp -a 2>/dev/null | head -60

hr "Fin du rapport"
