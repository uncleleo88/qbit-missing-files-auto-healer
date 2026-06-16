# qBittorrent Missing Files Auto-Healer

Files often go missing on my setup for a variety of frustrating reasons. **The main reason I finally built this:** I accidentally moved a bunch of cross-seeding torrents into the same category. When I later tried to organize them by moving them into different categories, qBittorrent physically moved the underlying files for *one* of the categories, but left the other torrents completely stranded with "missing files" errors!

Other common reasons include:
* **User Error:** Accidentally renaming, moving, or deleting a file without realizing another torrent was still relying on it.
* **Database Lags:** Rebooting qBittorrent or the server before it has time to properly save a file move to its internal database.
* **The *Arr Upgrades:** Sonarr or Radarr automatically upgrading a release to a better quality, which deletes the underlying file and breaks the link for other seeding torrents.
* **Mount Race Conditions:** Docker starting qBittorrent a few seconds before the network drives or arrays fully finish mounting, causing qBittorrent to panic and mark everything as missing.

So, with the help of an LLM, I wrote this script. It can be triggered in `qui` to automatically fast-search your drives for the missing source files, **create a hardlink copy** of those files back into the correct qBittorrent save directory, trigger a force-recheck, and seamlessly auto-resume the torrents.

It acts as an enterprise-grade, self-healing safety net for qBittorrent (v5.0+), built specifically for users with heavily automated media setups to handle these exact errors flawlessly.

### ✨ Features
* **Zero-Downtime Hardlink Restoration:** Automatically searches your array cache (up to depth 6) to instantly locate unregistered physical files and perfectly restores the hardlink (`cp -alv`) without using extra disk space.
* **The SSD Trap Bypass:** Dynamically injects `setDownloadPath` and `setLocation` API payloads if qBittorrent completely forgets the hard drive mapping (the 0% progress trap).
* **Intelligent Brake & State Memory:** If a torrent was intentionally paused/stopped by the user, the script remembers the state, fixes the file, triggers the recheck, and permanently leaves it safely paused.
* **Deletion Protection:** If you intentionally delete a file forever, the script searches, realizes the data is permanently gone, hits the emergency brake, and permanently freezes the broken torrents instead of blindly re-downloading 80GB REMUXes from scratch.
* **The 95% Threshold Shield:** Protects your bandwidth. Uses `awk` float-math to verify torrent completeness post-recheck. If you intentionally deleted half a season to save space, the script aborts auto-resume if the remaining file is < 95% complete. 
* **The 12-Hour Immortal Watcher:** Completely bypasses Docker/process timeouts. Spawns an independent `nohup` watcher that tolerates extreme disk I/O API lockups and will patiently wait in queue up to 12 hours for massive REMUXes to finish checking before seamlessly auto-starting them.
* **True Atomic Block Logging:** Safely handles massive multi-season deletions. Uses `O_APPEND` atomic writes to perfectly stack formatted log boxes without a single overlapping character, even if 20 scripts fire at the exact same microsecond. 

### 🚀 Usage 
This script is designed to be triggered by `qui` (or similar monitoring tools). 

* **Manual Trigger:** You can manually execute this script via `qui` on a specific torrent whenever you notice a "missing files" error.
* **Zero-Touch Automation:** If you want to use it without any user intervention, you can create an automation in `qui` that runs this script automatically in the background the exact second a torrent enters the missing files state.

---

### 🤝 Acknowledgments & AI Disclosure
**Transparency Note:** The architecture, edge-case logic, and real-world stress testing (handling category-migration bugs, API lockups, and heavy REMUX disk queues) were developed by a human who was tired of dealing with missing file errors. The bash syntax, atomic logging, and underlying code generation were written with the assistance of an LLM.
