#!/bin/sh
name="$1"
save_path="$2"
progress="$3"
hash="$4"

# ==========================================
# 0. USER CONFIGURATION
# ==========================================
# 1. Where should the script search for missing files? (Max depth 6)
SEARCH_DIR="/mnt/library/torrents/complete"

# 2. How should the script connect to your qBittorrent WebUI?
# Default to a standard single-instance setup:
qbit_url="http://localhost:8080" 

# [ADVANCED] Dynamic Multi-Instance Routing (The Author's Setup):
# My setup extracts "qbit-X" from the save_path and dynamically routes to http://qbit-1:9001, etc.
# If the script detects "qbit-" in the path, it will OVERRIDE the default url above.
if echo "$save_path" | grep -q 'qbit-[0-9]*'; then
  instance=$(echo "$save_path" | grep -o 'qbit-[0-9]*' | head -n 1)
  num=$(echo "$instance" | sed 's/qbit-//')
  port=$((9000 + num))
  qbit_url="http://${instance}:${port}"
fi

# ==========================================
# 1. ATOMIC BLOCK LOGGING
# ==========================================
log_file="/scripts/hardlink_$(date +%F).log"
tmp_log=$(mktemp /tmp/hl_XXXXXX 2>/dev/null || echo "/tmp/hl_${hash}_$$.log")

cleanup() {
  # Disconnect live output to safely process the final file
  exec >/dev/null 2>&1
  if [ -f "$tmp_log" ]; then
    echo "============================================================" >> "$tmp_log"
    echo "" >> "$tmp_log"
    cat "$tmp_log" >> "$log_file"
    rm -f "$tmp_log"
  fi
}
trap cleanup EXIT HUP INT TERM

exec > "$tmp_log" 2>&1

echo "============================================================"
echo "🕒 $(date '+%Y-%m-%d %H:%M:%S')"
echo "🎬 Target: $name"
echo "------------------------------------------------------------"

# 2. AUTO-HEAL: Ensure curl survives container restarts
if ! command -v curl >/dev/null 2>&1; then
  echo "📦 Auto-installing curl..."
  apk add -q --no-cache curl
fi

# ==========================================
# 3. STATE MEMORY & INTELLIGENT BRAKE
# ==========================================
should_start=true

if [ -n "$qbit_url" ]; then
  initial_state=$(curl -s -m 5 "$qbit_url/api/v2/torrents/info?hashes=$hash" | grep -o '"state":"[^"]*"' | head -n 1 | cut -d '"' -f 4)
  echo "🧠 Initial qBittorrent state: $initial_state"
  
  if echo "$initial_state" | grep -qiE "paused|stopped"; then
    echo "⏸️  State Memory: Torrent was intentionally stopped. Script will respect this!"
    should_start=false
  elif echo "$initial_state" | grep -qiE "downloading|dl|checking"; then
    echo "🛑 Active state detected! Freezing torrent to prevent unwanted downloads..."
    curl -s -m 5 -X POST --data-urlencode "hashes=$hash" "$qbit_url/api/v2/torrents/stop" >/dev/null 2>&1
  else
    echo "👍 Torrent is in an error/safe state. No freeze required."
  fi
fi

mkdir -p "$save_path"

# ==========================================
# 4. LIGHTNING-FAST SEARCH
# ==========================================
echo "🔍 Fast-searching HDD for source files..."
source_path=$(find "$SEARCH_DIR" -maxdepth 6 -name "$name" 2>/dev/null | grep -vF "$save_path" | head -n 1)

if [ -z "$source_path" ]; then
  echo "❌ ERROR: Could not find this file/folder anywhere."
  echo "🛑 ABORTING: Torrent left safely exactly as it was found."
  exit 1
fi

echo "✅ Found at: $source_path"

# ==========================================
# 5. HARDLINK RESTORATION
# ==========================================
cp_output=$(cp -alv "$source_path" "$save_path/" 2>&1)
cp_status=$?

if [ $cp_status -eq 0 ]; then
  echo "🔗 Hardlinked directly to HDD: $save_path"
elif echo "$cp_output" | grep -q "are the same file"; then
  echo "🔗 Hardlink verified: Already perfectly intact on HDD."
else
  echo "🚨 ERROR: Hardlink failed to create!"
  echo "Details: $cp_output"
  echo "🛑 ABORTING: Torrent left safely."
  exit 1
fi

# ==========================================
# 6. API INJECTION & INTELLIGENT RESUME
# ==========================================
if [ -n "$qbit_url" ]; then
  
  if [ "$progress" = "0" ] || [ "$progress" = "0.00" ] || [ "$progress" = "0.0" ]; then
    echo "⚠️ Torrent at 0%. Initiating API Path Injection..."
    echo "⚙️ Disabling Auto TMM..."
    curl -s -m 5 -X POST --data-urlencode "hashes=$hash" --data-urlencode "enable=false" "$qbit_url/api/v2/torrents/setAutoManagement" >/dev/null 2>&1
    echo "💉 Injecting Download Path..."
    curl -s -m 5 -X POST --data-urlencode "hashes=$hash" --data-urlencode "id=$hash" --data-urlencode "path=$save_path" "$qbit_url/api/v2/torrents/setDownloadPath" >/dev/null 2>&1
    echo "💉 Injecting Final Save Path..."
    curl -s -m 5 -X POST --data-urlencode "hashes=$hash" --data-urlencode "location=$save_path" "$qbit_url/api/v2/torrents/setLocation" >/dev/null 2>&1
  else
    echo "👍 Torrent > 0%. Skipping path injection."
  fi

  # INTELLIGENT RECHECK
  if echo "$initial_state" | grep -qiE "missingfiles|error|stopped|paused|downloading|dl|checking" || [ "$progress" = "0" ] || [ "$progress" = "0.00" ] || [ "$progress" = "0.0" ]; then
    
    echo "🔄 Triggering Force Recheck to clear errors/update progress..."
    curl -s -m 5 -X POST --data-urlencode "hashes=$hash" "$qbit_url/api/v2/torrents/recheck" >/dev/null 2>&1
    
    if [ "$should_start" = true ]; then
      echo "🕵️ Spawning Invincible Background Watcher to monitor checking progress..."
      
      # ==========================================
      # 7. THE 12-HOUR IMMORTAL WATCHER
      # ==========================================
      watcher_script=$(mktemp /tmp/hl_watcher_XXXXXX.sh 2>/dev/null || echo "/tmp/hl_watcher_${hash}_$$.sh")
      
      cat << 'EOF_WATCHER' > "$watcher_script"
#!/bin/sh
qbit_url="$1"
hash="$2"
name="$3"
log_file="$4"

# 1. Grace Period: Wait up to 60 seconds for qBittorrent to fully enter the "checking" state
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  status=$(curl -s -m 5 "$qbit_url/api/v2/torrents/info?hashes=$hash" | grep -o '"state":"[^"]*"' | head -n 1 | cut -d '"' -f 4)
  if echo "$status" | grep -qi "checking"; then break; fi
  sleep 5
done

# 2. Main Monitoring Loop (Timeout bumped to 12 HOURS for massive queues)
count=0
fail_count=0

while [ $count -lt 8640 ]; do
  sleep 5
  
  api_response=$(curl -s -m 10 "$qbit_url/api/v2/torrents/info?hashes=$hash")
  
  if [ -z "$api_response" ]; then 
    fail_count=$((fail_count + 1))
    if [ $fail_count -ge 12 ]; then break; fi
    continue
  else
    fail_count=0
  fi
  
  if [ "$api_response" = "[]" ]; then break; fi
  
  status=$(echo "$api_response" | grep -o '"state":"[^"]*"' | head -n 1 | cut -d '"' -f 4)
  
  if echo "$status" | grep -qi "checking"; then
    count=$((count + 1))
    continue
  fi
  
  # Check is completely finished! Evaluate!
  current_prog=$(echo "$api_response" | grep -o '"progress":[^,}]*' | head -n 1 | cut -d ':' -f 2)
  if [ -n "$current_prog" ]; then
    prog_percent=$(awk -v p="$current_prog" 'BEGIN { printf "%.1f", p * 100 }')
    
    # TRUE ATOMIC BLOCK LOGGING FOR WATCHER
    box_log=$(mktemp /tmp/hl_wbox_XXXXXX 2>/dev/null || echo "/tmp/hl_wbox_${hash}_$$.log")
    
    echo "============================================================" > "$box_log"
    echo "🕒 $(date '+%Y-%m-%d %H:%M:%S')" >> "$box_log"
    echo "🕵️ [WATCHER FINAL REPORT]: $name" >> "$box_log"
    echo "------------------------------------------------------------" >> "$box_log"
    if awk -v p="$current_prog" 'BEGIN { exit (p >= 0.95 ? 0 : 1) }'; then
      echo "✅ Check finished at $prog_percent%. Threshold met." >> "$box_log"
      echo "🚀 Auto-starting torrent..." >> "$box_log"
      curl -s -m 5 -X POST --data-urlencode "hashes=$hash" "$qbit_url/api/v2/torrents/start" >/dev/null 2>&1
    else
      echo "⚠️ Check finished at $prog_percent%." >> "$box_log"
      echo "🛑 BELOW 95% THRESHOLD! Torrent left safely stopped." >> "$box_log"
    fi
    echo "============================================================" >> "$box_log"
    echo "" >> "$box_log"
    
    cat "$box_log" >> "$log_file"
    rm -f "$box_log"
  fi
  break
done

rm -f "$0"
EOF_WATCHER

      chmod +x "$watcher_script"
      nohup sh "$watcher_script" "$qbit_url" "$hash" "$name" "$log_file" >/dev/null 2>&1 &
      
      echo "🎉 Repair complete! Watcher running natively in background. Will auto-start when >= 95%."
    else
      echo "⏸️  MEMORY: Torrent was manually stopped before script ran. Leaving it stopped!"
    fi
  else
    echo "🥷 NINJA MODE: qBittorrent didn't know it was missing! Bypassing Recheck."
    
    if [ "$should_start" = false ]; then
      echo "⏸️  MEMORY: Leaving torrent stopped."
    else
      echo "▶️ Restarting torrent back to normal operations..."
      curl -s -m 5 -X POST --data-urlencode "hashes=$hash" "$qbit_url/api/v2/torrents/start" >/dev/null 2>&1
      echo "🎉 Repair complete!"
    fi
  fi

else
  echo "🚨 AUTOMATION SKIPPED: Could not establish qBittorrent URL."
fi
