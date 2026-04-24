Steam All Games Updater - Instructions

Files
- Steam All Games Updater
  This updater closes Steam and related Steam processes, scans all Steam library folders configured in Steam, and sets installed game manifests to instant-update mode by changing AutoUpdateBehavior to 2.

- Preview Version
  This version shows the same general prompts and final screen, but it does not change Steam files.

How To Use
1. Close any game you do not want interrupted.
2. Run the Steam All Games Updater batch file as a normal batch file.
3. When asked if Steam and all related processes and games will close, choose Yes only if you are ready.
4. Wait for the script to finish.
5. If asked whether to launch Steam now, choose Yes if you want Steam reopened automatically.

What The Steam All Games Updater Does
1. Closes Steam and related Steam processes.
2. Reads every Steam library folder configured in Steam.
3. Finds installed appmanifest_*.acf files.
4. Sets AutoUpdateBehavior to 2 for installed games.
5. Creates manifest backups before writing.
6. Can recover some empty manifests from previous backup history.
7. Attempts to relaunch Steam.

What The Preview Version Does
1. Shows the same style of prompts and ending banner.
2. Does not modify Steam manifests.
3. Does not perform the update work.

Backups And Logs
- Backup folders are created under:
  C:\Users\Yousef\Downloads\steam_manifest_backups

- Each run creates a timestamped folder that may include:
  summary.txt
  failed.txt
  copied manifest backups

Important Notes
- Run the Steam All Games Updater only when Steam can be safely closed.
- If antivirus flags the updater, that can happen because it edits files under Steam and uses PowerShell behavior that security tools may treat as suspicious.
- If a manifest is locked by another process, the updater may log a warning and continue.
- If Steam still looks wrong after a run, check the newest folder inside:
  C:\Users\Yousef\Downloads\steam_manifest_backups
