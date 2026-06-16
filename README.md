# qBittorrent Cross-Seed Auto-Healer

An enterprise-grade, self-healing bash script designed to act as an automated safety net for qBittorrent (v5.0+). Built specifically for users with heavy `cross-seed` and automated media setups to handle "Missing Files" errors natively.

### ✨ Features
* **Zero-Downtime Hardlink Repair:** Automatically searches your array cache (up to depth 6) to instantly locate unregistered physical files and restores the hardlink.
* **The SSD Trap Bypass:** Dynamically injects `setDownloadPath` and `setLocation` API payloads if qBittorrent forgets where the hard drive is (0% progress trap).
* **Intelligent Brake & State Memory:** If a torrent was intentionally paused/stopped by the user, the script remembers the state, fixes the file, triggers the recheck, and permanently leaves it safely paused.
* **Cross-Seed Delete Protection:** If you intentionally delete a file from one tracker, the script searches, realizes the data is permanently gone, hits the emergency brake, and permanently freezes the cross-seeded torrents instead of re-downloading 80GB REMUXes.
* **The 95% Threshold Shield:** Protects your bandwidth. Uses `awk` float-math to verify torrent completeness post-recheck. If you intentionally deleted half a season to save space, the script aborts auto-resume if the remaining file is < 95% complete. 
* **The 12-Hour Immortal Watcher:** Completely bypasses Docker/process timeouts. Spawns an independent `nohup` watcher that tolerates extreme disk I/O API lockups and will patiently wait in queue up to 12 hours for massive REMUXes to finish checking before seamlessly resuming them.
* **True Atomic Block Logging:** Safely handles massive multi-season deletions. Uses `O_APPEND` atomic writes to perfectly stack formatted log boxes without a single overlapping character, even if 20 scripts fire at the exact same microsecond. 

### 🚀 Usage
This script is designed to be triggered automatically by `qui` (or similar monitoring tools) whenever a torrent enters the `missingFiles` state.

---

### 🤝 Acknowledgments & AI Disclosure
**Transparency Note:** The architecture, edge-case logic, and real-world stress testing (handling multi-tracker cross-seeds, API lockups, and heavy REMUX disk queues) were developed by a human who was tired of dealing with missing file errors. The bash syntax, atomic logging, and underlying code generation were written with the assistance of an LLM.
