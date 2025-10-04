# This program was made for a client

# Roblox Tool

Roblox utility for safely deploying a custom executable (e.g. patched helper / crash handler) into the active Roblox version folder and cleaning Roblox log directories.

All logic lives in a single Python script (`roblox_tool.py`) with an optional launcher (`run.bat`) that auto-installs Python and dependencies. The interface can be interactive (arrow-key menu) or fully scripted via CLI flags.

## Key Features
- Auto-detects current Roblox client version via official API and targets the correct `Versions/<version>` directory.
- Deploy (copy or move) a selected `.exe` from the local `bin` folder (hash + size skip logic avoids redundant replacement).
- Configurable replacement mode: `copy` (default, retains source) or `move` (removes source after deploy).
- Conditional process termination with `process_kill_mode`: `if_needed` (default), `always`, or `never` for `RobloxPlayerBeta.exe`.
- Pre-check (size + SHA-256 hash) to skip killing the process and deploying when file is already identical (`SAME_FILE`).
- Log cleaner: safely purges `%LOCALAPPDATA%\Roblox\logs` (recursive) with path safety guard keywords.
- Loop mode: automatically repeat selected actions with delay, ESC to stop, statistics summary (runs, success/skip/fail counts, average duration, elapsed multi-unit time).
- Real-time JSON config persistence (`config.json`).
- Interactive arrow-key menu (toggle actions, run batch, edit config inline).
- Structured status output with operation codes (e.g. `OK`, `SAME_FILE`, `HASH_MISMATCH`, `PERMISSION_DENIED`).
- Permission pre-test (write test file) before attempting replacement.
- Minimum executable size guard (rejects suspiciously tiny files).
- Graceful handling of network failures with retry + backoff when fetching version info.

## Requirements
- Windows 10/11
- Python 3.11+ (auto-installed silently by `run.bat` if missing)
- Internet (initial version API + dependency install)

## Quick Start
1. Clone or download this repository.
2. Place your target `.exe` into the `bin` directory (auto-created) — e.g. `RobloxCrashHandler.exe`.
3. Run `run.bat` (double-click). It will:
   - Detect / install Python if missing.
   - Ensure `requests` + `psutil` are installed.
   - Launch the tool (menu if no args).
4. In the menu:
   - Toggle “Replace EXE (bin)” and/or “Clear Logs”.
   - Optionally enable Loop Mode.
   - Choose “Run Selected”.

## Command-Line Usage
Run via `run.bat` or directly `python roblox_tool.py` with equivalent flags.

Replace (copy mode):
```
run.bat --replace-exe bin\RobloxCrashHandler.exe
```

Replace using move mode (one-off):
```
run.bat --replace-exe bin\RobloxCrashHandler.exe --move
```

Clear logs only:
```
run.bat --clear-logs
```

Reset config:
```
run.bat --init-config
```

Force menu:
```
run.bat --menu
```

You can also run the Python script directly:
```
python roblox_tool.py --replace-exe bin\SomeFile.exe --move
```

## Configuration (`config.json`)
Created/updated automatically. Keys:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `roblox_versions_path` | string | `C:\\Program Files (x86)\\Roblox\\Versions` | Root folder containing version subdirectories. |
| `roblox_logs_path` | string | `%LOCALAPPDATA%\\Roblox\\logs` | Roblox log directory. |
| `roblox_api_url` | string | Official API URL | Fetches current client version. |
| `target_process` | string | `RobloxPlayerBeta.exe` | Process name to conditionally terminate. |
| `bin_path` | string | `<repo>/bin` | Source directory for candidate executables. |
| `loop_delay_seconds` | int | `5` | Delay between loop iterations. Bounds enforced. |
| `loop_reselect_exe_each_run` | bool | `false` | Re-prompt exe each loop iteration. |
| `selected_actions` | list | `["replace","logs"]` | Persisted menu selections. |
| `last_selected_exe` | string | `` | Last used executable path. |
| `replace_mode` | string | `copy` | Default deploy mode (`copy` or `move`). |
| `process_kill_mode` | string | `if_needed` | `always` / `if_needed` / `never`. |

### Process Kill Modes
| Mode | Behavior |
|------|----------|
| `if_needed` | Kill only if a replacement is required (hash/size differs). |
| `always` | Always attempt to terminate before replace. |
| `never` | Never terminate (may cause permission errors if file locked). |

### Replacement Modes
| Mode | Behavior |
|------|----------|
| `copy` | Copy source into version folder (source preserved). |
| `move` | Move (atomic if possible) then delete source (source removed). |

## Safety & Integrity
- SAME_FILE skip: size + SHA-256 hash match means no process kill (in `if_needed`) and no copy.
- Hash verification post-copy ensures integrity (copy mode). Move mode uses size check (source may no longer exist).
- Minimum size check (`512` bytes) rejects abnormal placeholders.
- Permission pre-check creates + deletes a temp file before actual write.
- Safe logs deletion: path must contain keywords (`roblox`, `logs`) to reduce accidental destructive deletes.
- Structured error codes ease debugging: `SOURCE_NOT_FOUND`, `VERSION_FOLDER_NOT_FOUND`, `HASH_MISMATCH`, etc.
- Exponential backoff on API (`1s`, `2s`, `4s`) before giving up with `NETWORK_ERROR`.

## Loop Mode & Statistics
When Loop Mode is enabled the tool repeats selected actions until ESC is pressed during the countdown. Displays per-iteration result plus final summary:
- Runs
- Replace success / skipped / fail counts
- Average replace duration (ms)
- Total elapsed time (multi-unit breakdown: years → seconds)

## Typical Workflows
1. One-time deploy & clean logs:
```
run.bat --replace-exe bin\Patch.exe --clear-logs
```
2. Continuous monitoring (loop) via menu (recommended: enable Loop Mode + Replace + Logs)
3. Switch to move mode permanently: edit `config.json` → `"replace_mode": "move"`
4. Avoid interrupting gameplay: set `"process_kill_mode": "never"` (will skip if locked)

## Troubleshooting
| Issue | Cause | Fix |
|-------|-------|-----|
| `VERSION_FOLDER_NOT_FOUND` | Roblox install path mismatch | Adjust `roblox_versions_path` in config/menu |
| `NETWORK_ERROR` | API blocked / offline | Check firewall / retry later |
| Always kills process | `process_kill_mode` set to `always` | Change to `if_needed` or `never` |
| Kills even when unchanged | File actually differs (hash) | Confirm same binary / compare hashes manually |
| `PERMISSION_DENIED` | Locked file + `never` mode | Use `if_needed` or close Roblox |
| Logs not clearing | Path mismatch or unsafe path rejected | Verify `roblox_logs_path` contains required keywords |
| Batch syntax error | Old `run.bat` parsing | Re-pull latest version or use `run_minimal.bat` |

## Credits
- `RobloxCrashHandler.exe` provided by **Aye Shop v99 (kiley0)**. All rights to that binary remain with its original author/owner.

## License
MIT License

## Example Code

```py
import os, shutil, hashlib, requests, time, ctypes, json, msvcrt, psutil, argparse


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SCRIPT_DIR, "config.json")
BIN_DIR = os.path.join(SCRIPT_DIR, "bin")
DEFAULTS = {
    "roblox_versions_path": r"C:\\Program Files (x86)\\Roblox\\Versions",
    "roblox_logs_path": os.path.expandvars(r"%localappdata%\\Roblox\\logs"),
    "roblox_api_url": "https://clientsettings.roblox.com/v2/client-version/WindowsPlayer",
    "target_process": "RobloxPlayerBeta.exe",
    "bin_path": BIN_DIR,
    "loop_delay_seconds": 5,
    "loop_reselect_exe_each_run": False,
    "selected_actions": ["replace", "logs"],
    "last_selected_exe": "",
    "replace_mode": "copy",
    "process_kill_mode": "if_needed",
}

MIN_LOOP_DELAY = 1
MAX_LOOP_DELAY = 3600
SAFE_LOGS_KEYWORDS = ["roblox", "logs"]
MIN_EXE_SIZE = 512


OK = "OK"
NETWORK_ERROR = "NETWORK_ERROR"
VERSION_FETCH_FAILED = "VERSION_FETCH_FAILED"
VERSION_FOLDER_NOT_FOUND = "VERSION_FOLDER_NOT_FOUND"
SOURCE_NOT_FOUND = "SOURCE_NOT_FOUND"
SOURCE_TOO_SMALL = "SOURCE_TOO_SMALL"
SAME_FILE = "SAME_FILE"
HASH_MISMATCH = "HASH_MISMATCH"
PERMISSION_DENIED = "PERMISSION_DENIED"
PROCESS_KILL_FAILED = "PROCESS_KILL_FAILED"
LOGS_NOT_FOUND = "LOGS_NOT_FOUND"
UNSAFE_LOGS_PATH = "UNSAFE_LOGS_PATH"

API_MAX_RETRIES = 3
API_BACKOFF_SECONDS = [1, 2, 4]


def load_config():
    if not os.path.exists(CONFIG_PATH):
        save_config(DEFAULTS)
        return DEFAULTS.copy()
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}

    changed = False
    for k, v in DEFAULTS.items():
        if k not in data:
            data[k] = v
            changed = True

    try:
        delay = int(data.get("loop_delay_seconds", 5))
    except (TypeError, ValueError):
        delay = 5
    delay = max(MIN_LOOP_DELAY, min(MAX_LOOP_DELAY, delay))
    if data.get("loop_delay_seconds") != delay:
        data["loop_delay_seconds"] = delay
        changed = True

    if validate_config_schema(data):
        changed = True
    if changed:
        save_config(data)
    return data


def save_config(cfg):
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        print(f"Failed to save config: {e}")


def ensure_bin_folder(cfg):
    path = cfg.get("bin_path", BIN_DIR)
    try:
        os.makedirs(path, exist_ok=True)
    except Exception as e:
        print(f"Failed to create bin folder: {e}")
    return path


def prompt_missing_config(cfg):
    updated = False

    if not os.path.isdir(cfg["roblox_versions_path"]):
        print("Roblox versions path not found.")
        user = input(
            "Enter Roblox Versions path or leave blank to keep default: "
        ).strip()
        if user:
            cfg["roblox_versions_path"] = user
            updated = True
    if not os.path.isdir(cfg["roblox_logs_path"]):
        print("Roblox logs path not found.")
        user = input("Enter Roblox Logs path or leave blank to keep default: ").strip()
        if user:
            cfg["roblox_logs_path"] = user
            updated = True
    if updated:
        save_config(cfg)
    return cfg


def validate_config_schema(cfg):
    """Deep validation / normalization of config values. Returns True if mutated."""
    mutated = False

    must_keys = [
        "roblox_versions_path",
        "roblox_logs_path",
        "roblox_api_url",
        "target_process",
        "bin_path",
    ]
    for k in must_keys:
        if k not in cfg or not isinstance(cfg.get(k), str) or not cfg.get(k).strip():
            cfg[k] = DEFAULTS[k]
            mutated = True

    for k, v in list(cfg.items()):
        if k.endswith("_path") and isinstance(v, str):
            if (os.sep not in v) and ("%" not in v):
                cfg[k] = DEFAULTS.get(k, v)
                mutated = True

    api = cfg.get("roblox_api_url", "")
    if not (api.startswith("http://") or api.startswith("https://")):
        cfg["roblox_api_url"] = DEFAULTS["roblox_api_url"]
        mutated = True

    if not isinstance(cfg.get("loop_reselect_exe_each_run"), bool):
        cfg["loop_reselect_exe_each_run"] = bool(DEFAULTS["loop_reselect_exe_each_run"])
        mutated = True

    if not isinstance(cfg.get("selected_actions"), list):
        cfg["selected_actions"] = DEFAULTS["selected_actions"][:]
        mutated = True

    mode = cfg.get("replace_mode")
    if mode not in ("copy", "move"):
        cfg["replace_mode"] = DEFAULTS["replace_mode"]
        mutated = True

    pk = cfg.get("process_kill_mode")
    if pk not in ("always", "if_needed", "never"):
        cfg["process_kill_mode"] = DEFAULTS["process_kill_mode"]
        mutated = True
    return mutated


def get_roblox_version(api_url):
    last_error = None
    for attempt in range(API_MAX_RETRIES):
        try:
            resp = requests.get(api_url, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            return {
                "code": OK,
                "version": data["clientVersionUpload"],
                "attempts": attempt + 1,
            }
        except Exception as e:
            last_error = str(e)
            if attempt < API_MAX_RETRIES - 1:
                time.sleep(
                    API_BACKOFF_SECONDS[min(attempt, len(API_BACKOFF_SECONDS) - 1)]
                )
    return {"code": NETWORK_ERROR, "error": last_error, "attempts": API_MAX_RETRIES}


def kill_process(name):
    killed = False
    for proc in psutil.process_iter(["name"]):
        if proc.info["name"] and proc.info["name"].lower() == name.lower():
            try:
                proc.terminate()
                proc.wait(timeout=5)
                killed = True
            except Exception:
                try:
                    proc.kill()
                    killed = True
                except Exception:
                    pass
    return killed


def is_process_running(name):
    for proc in psutil.process_iter(["name"]):
        if proc.info["name"] and proc.info["name"].lower() == name.lower():
            return True
    return False


def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            h.update(chunk)
    return h.hexdigest()


def replace_exe(src, dst, silent=False, mode="copy"):
    result = {
        "code": OK,
        "source_exists": os.path.exists(src),
        "dest_exists": os.path.exists(dst),
        "skipped": False,
        "replaced": False,
        "moved": False,
        "same_hash": False,
        "source_size": 0,
        "dest_size": 0,
        "error": "",
        "duration_ms": 0,
        "mode": mode,
    }
    if not result["source_exists"]:
        result["code"] = SOURCE_NOT_FOUND
        result["error"] = "Source file not found"
        if not silent:
            print(f"Source file not found: {src}")
        return result
    try:
        start_t = time.time()
        result["source_size"] = os.path.getsize(src)
        if result["source_size"] < MIN_EXE_SIZE:
            result["code"] = SOURCE_TOO_SMALL
            result["error"] = "Source exe too small"
            return result
        dest_dir = os.path.dirname(dst)

        try:
            if not os.path.isdir(dest_dir):
                os.makedirs(dest_dir, exist_ok=True)
            temp = os.path.join(dest_dir, "__write_test.tmp")
            with open(temp, "w", encoding="utf-8") as f:
                f.write("test")
            os.remove(temp)
        except Exception:
            result["code"] = PERMISSION_DENIED
            result["error"] = "No write permission"
            return result
        if result["dest_exists"]:
            result["dest_size"] = os.path.getsize(dst)
            if result["source_size"] == result["dest_size"] and file_hash(
                src
            ) == file_hash(dst):
                result["same_hash"] = True
                result["skipped"] = True
                result["code"] = SAME_FILE
                if not silent:
                    print("File already up to date, skipping.")
                return result
            try:
                os.chmod(dst, 0o666)
            except Exception:
                pass

        op_error = None
        if mode == "move":
            try:

                if os.path.exists(dst):
                    try:
                        os.remove(dst)
                    except Exception:
                        pass
                try:
                    os.replace(src, dst)
                except Exception:

                    shutil.move(src, dst)
                result["moved"] = True
                result["replaced"] = True
            except Exception as e:
                op_error = str(e)
        else:
            try:
                shutil.copy2(src, dst)
                result["replaced"] = True
            except Exception as e:
                op_error = str(e)
        result["dest_size"] = os.path.getsize(dst) if os.path.exists(dst) else 0

        try:
            if mode == "copy":
                if file_hash(src) != file_hash(dst):
                    result["code"] = HASH_MISMATCH
                    result["error"] = "hash mismatch after copy"
            else:
                if result["source_size"] != result["dest_size"]:
                    result["code"] = HASH_MISMATCH
                    result["error"] = "size mismatch after move"
        except Exception as e:
            if not result["error"]:
                result["error"] = str(e)
        if op_error and result["replaced"] is False:
            result["code"] = "EXCEPTION"
            result["error"] = op_error
        if not silent:
            verb = "Moved" if mode == "move" else "Replaced"
            if result["replaced"]:
                print(f"{verb}: {dst}")
            else:
                print(f"Failed to {verb.lower()}: {result['error']}")
        result["duration_ms"] = int((time.time() - start_t) * 1000)
    except PermissionError as e:
        result["code"] = PERMISSION_DENIED
        result["error"] = str(e)
        if not silent:
            print(f"Permission error: {e}")
    except Exception as e:
        result["code"] = "EXCEPTION"
        result["error"] = str(e)
        if not silent:
            print(f"Replace error: {e}")
    return result


def clear_logs(logs_path, silent=False):
    result = {"path_exists": os.path.exists(logs_path), "removed": 0, "errors": []}
    if not result["path_exists"]:
        if not silent:
            print(f"Logs path not found: {logs_path}")
        return result
    for f in os.listdir(logs_path):
        fp = os.path.join(logs_path, f)
        try:
            if os.path.isfile(fp):
                os.remove(fp)
                result["removed"] += 1
        except Exception as e:
            result["errors"].append((fp, str(e)))
            if not silent:
                print(f"Failed to remove {fp}: {e}")
    if not silent:
        print(f'Roblox logs cleared ({result["removed"]} files).')
    return result


def disable_quick_edit():
    try:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        GetStdHandle = kernel32.GetStdHandle
        GetConsoleMode = kernel32.GetConsoleMode
        SetConsoleMode = kernel32.SetConsoleMode
        STD_INPUT_HANDLE = -10
        hStdin = GetStdHandle(STD_INPUT_HANDLE)
        mode = ctypes.c_uint()
        if GetConsoleMode(hStdin, ctypes.byref(mode)):
            ENABLE_QUICK_EDIT = 0x40
            new_mode = mode.value & ~ENABLE_QUICK_EDIT
            SetConsoleMode(hStdin, new_mode)
    except Exception:
        pass


def lock_console_resize():
    try:
        user32 = ctypes.WinDLL("user32", use_last_error=True)
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        GetConsoleWindow = kernel32.GetConsoleWindow
        hwnd = GetConsoleWindow()
        if not hwnd:
            return

        GWL_STYLE = -16
        GWL_EXSTYLE = -20
        WS_MAXIMIZEBOX = 0x00010000
        WS_SIZEBOX = 0x00040000

        GetWindowLongW = user32.GetWindowLongW
        SetWindowLongW = user32.SetWindowLongW
        style = GetWindowLongW(hwnd, GWL_STYLE)
        if style:
            style &= ~WS_MAXIMIZEBOX
            style &= ~WS_SIZEBOX
            SetWindowLongW(hwnd, GWL_STYLE, style)

        GetSystemMenu = user32.GetSystemMenu
        RemoveMenu = user32.RemoveMenu
        DrawMenuBar = user32.DrawMenuBar
        SC_SIZE = 0xF000
        SC_MAXIMIZE = 0xF030
        hMenu = GetSystemMenu(hwnd, False)
        if hMenu:
            RemoveMenu(hMenu, SC_SIZE, 0x0000)
            RemoveMenu(hMenu, SC_MAXIMIZE, 0x0000)
            DrawMenuBar(hwnd)
    except Exception:
        pass


def list_exe_candidates(bin_path):
    try:
        return [
            f
            for f in os.listdir(bin_path)
            if f.lower().endswith(".exe") and os.path.isfile(os.path.join(bin_path, f))
        ]
    except Exception:
        return []


def select_exe_from_bin(bin_path):
    files = list_exe_candidates(bin_path)
    if not files:
        print("No .exe files in bin folder.")
        return None
    if len(files) == 1:
        return os.path.join(bin_path, files[0])
    idx = 0
    while True:
        os.system("cls")
        print("Select exe (Enter confirm, ESC cancel)")
        for i, f in enumerate(files):
            prefix = ">" if i == idx else " "
            print(f"{prefix} {f}")
        ch = msvcrt.getwch()
        if ch == "\r":
            return os.path.join(bin_path, files[idx])
        if ch == "\x1b":
            return None
        if ch == "\xe0":
            key = msvcrt.getwch()
            if key == "H":
                idx = (idx - 1) % len(files)
            elif key == "P":
                idx = (idx + 1) % len(files)


def perform_replace(config, exe_path, silent=False, override_mode=None):
    status = {
        "requested_exe": exe_path,
        "version_folder": "",
        "version_id": "",
        "process_killed": False,
        "replace": None,
        "error": "",
        "code": OK,
        "api_attempts": 0,
        "mode": override_mode or config.get("replace_mode", "copy"),
        "process_kill_mode": config.get("process_kill_mode", "if_needed"),
        "prechecked_same": False,
    }
    try:
        api_res = get_roblox_version(config["roblox_api_url"])
        status["api_attempts"] = api_res.get("attempts", 0)
        if api_res.get("code") != OK:
            status["code"] = VERSION_FETCH_FAILED
            status["error"] = api_res.get("error", "version fetch failed")
            if not silent:
                print("Failed to get Roblox version.")
            return status
        version = api_res.get("version")
        status["version_id"] = version or ""
        version_path = os.path.join(config["roblox_versions_path"], version)
        status["version_folder"] = version_path
        if not os.path.exists(version_path):
            status["code"] = VERSION_FOLDER_NOT_FOUND
            status["error"] = "Version folder not found"
            if not silent:
                print(f"Roblox version folder not found: {version_path}")
            return status
        exe_name = os.path.basename(exe_path)
        dst_path = os.path.join(version_path, exe_name)

        need_replace = True
        if os.path.exists(dst_path) and os.path.exists(exe_path):
            try:
                src_size = os.path.getsize(exe_path)
                dst_size = os.path.getsize(dst_path)
                if src_size == dst_size and file_hash(exe_path) == file_hash(dst_path):
                    need_replace = False
                    status["prechecked_same"] = True
            except Exception:
                pass
        pk_mode = status["process_kill_mode"]
        if pk_mode == "always":
            if is_process_running(config["target_process"]):
                status["process_killed"] = kill_process(config["target_process"])
                time.sleep(0.3)
        elif pk_mode == "if_needed":
            if need_replace and is_process_running(config["target_process"]):
                status["process_killed"] = kill_process(config["target_process"])
                time.sleep(0.3)
        elif pk_mode == "never":
            pass
        if need_replace:
            status["replace"] = replace_exe(
                exe_path, dst_path, silent=silent, mode=status["mode"]
            )
        else:
            status["replace"] = {
                "code": SAME_FILE,
                "source_exists": True,
                "dest_exists": True,
                "skipped": True,
                "replaced": False,
                "moved": False,
                "same_hash": True,
                "source_size": (
                    os.path.getsize(exe_path) if os.path.exists(exe_path) else 0
                ),
                "dest_size": (
                    os.path.getsize(dst_path) if os.path.exists(dst_path) else 0
                ),
                "error": "",
                "duration_ms": 0,
                "mode": status["mode"],
            }
    except Exception as e:
        status["code"] = "EXCEPTION"
        status["error"] = str(e)
        if not silent:
            print(f"Replace error: {e}")
    return status


def clear_logs(config, silent=False):
    base = config.get("roblox_logs_path", "")
    result = {
        "removed_files": 0,
        "removed_dirs": 0,
        "errors": [],
        "code": OK,
        "skipped_in_use": 0,
        "skipped_other": 0,
        "skipped_in_use_samples": [],
    }
    try:
        if not os.path.isdir(base):
            if not silent:
                print(f"Logs path not found: {base}")
            result["errors"].append(LOGS_NOT_FOUND)
            result["code"] = LOGS_NOT_FOUND
            return result
        low = base.lower()
        if not any(k in low for k in SAFE_LOGS_KEYWORDS):
            result["errors"].append(UNSAFE_LOGS_PATH)
            result["code"] = UNSAFE_LOGS_PATH
            if not silent:
                print("Unsafe logs path, abort clear.")
            return result
        for root, dirs, files in os.walk(base, topdown=False):
            for f in files:
                fp = os.path.join(root, f)
                try:
                    os.remove(fp)
                    result["removed_files"] += 1
                except Exception as e:
                    msg = str(e)
                    if "WinError 32" in msg or "being used by another process" in msg:
                        result["skipped_in_use"] += 1
                        if len(result["skipped_in_use_samples"]) < 5:
                            result["skipped_in_use_samples"].append(fp)
                    else:
                        result["errors"].append(msg)
                        result["skipped_other"] += 1
            for d in dirs:
                dp = os.path.join(root, d)
                try:
                    os.rmdir(dp)
                    result["removed_dirs"] += 1
                except OSError:
                    pass
        if not silent:
            extra = ""
            if result["skipped_in_use"] or result["skipped_other"]:
                extra = f" (in-use skipped={result['skipped_in_use']} other skipped={result['skipped_other']})"
            print(
                f"Logs cleared: files={result['removed_files']} dirs={result['removed_dirs']}{extra}"
            )
    except Exception as e:
        result["errors"].append(str(e))
        result["code"] = "EXCEPTION"
        if not silent:
            print(f"Clear logs error: {e}")
    return result


def edit_config_menu(config):
    keys = [
        k
        for k in config.keys()
        if k.endswith("_path")
        or k.endswith("_url")
        or k in ("target_process", "loop_delay_seconds", "loop_reselect_exe_each_run")
    ]
    idx = 0
    while True:
        os.system("cls")
        print("Edit Config")
        print("Enter=Edit  ESC=Back  Up/Down=Navigate")
        print()
        for i, k in enumerate(keys):
            prefix = ">" if i == idx else " "
            print(f"{prefix} {k}: {config.get(k)}")
        ch = msvcrt.getwch()
        if ch == "\x1b":
            return
        if ch == "\r":
            key = keys[idx]
            new_val = input(f"New value for {key} (blank = keep): ").strip()
            if new_val:
                if key == "loop_delay_seconds":
                    try:
                        config[key] = max(1, int(new_val))
                    except ValueError:
                        print("Invalid integer. Keeping old value.")
                        time.sleep(1)
                elif key == "loop_reselect_exe_each_run":
                    if new_val.lower() in ("true", "1", "yes", "y", "on"):
                        config[key] = True
                    elif new_val.lower() in ("false", "0", "no", "n", "off"):
                        config[key] = False
                    else:
                        print("Invalid boolean. Use true/false.")
                        time.sleep(1)
                else:
                    config[key] = new_val
                save_config(config)
        elif ch == "\xe0":
            keyc = msvcrt.getwch()
            if keyc == "H":
                idx = (idx - 1) % len(keys)
            elif keyc == "P":
                idx = (idx + 1) % len(keys)


def resize_console(width, height):
    try:
        width = max(80, min(160, width))
        height = max(25, min(60, height))
        os.system(f"mode con: cols={width} lines={height}")

        lock_console_resize()
    except Exception:
        pass


def interactive_menu(config):
    persisted = set(config.get("selected_actions", []))
    actions = [
        {
            "name": "Replace EXE (bin)",
            "desc": "Deploy exe to current Roblox version",
            "key": "replace",
            "selected": "replace" in persisted,
        },
        {
            "name": "Clear Logs",
            "desc": "Delete Roblox log files",
            "key": "logs",
            "selected": "logs" in persisted,
        },
        {
            "name": "Loop Mode",
            "desc": "Repeat actions automatically",
            "key": "loop",
            "selected": "loop" in persisted,
        },
        {
            "name": "Edit Config",
            "desc": "Modify settings",
            "key": "config",
            "selected": False,
        },
        {
            "name": "Run Selected",
            "desc": "Execute chosen actions",
            "key": "run",
            "selected": False,
        },
        {"name": "Exit", "desc": "Quit program", "key": "exit", "selected": False},
    ]
    idx = 0
    status_summary = {}
    iteration = 0
    last_exe_used = config.get("last_selected_exe", "") or ""
    while True:
        longest_line = max(len(a["name"]) + 10 + len(a["desc"]) for a in actions)
        width = min(160, longest_line + 14)
        height = len(actions) + 22
        resize_console(width, height)
        os.system("cls")
        print("Roblox Tool DelShop")
        print("Up/Down Enter=Toggle/Run ESC=Exit")
        print(
            f"Delay: {config.get('loop_delay_seconds',5)}s | Reselect each run: {config.get('loop_reselect_exe_each_run', False)}"
        )
        if last_exe_used:
            print(f"Last exe: {os.path.basename(last_exe_used)}")
        print()
        for i, act in enumerate(actions):
            selectable = act["key"] not in ("run", "exit", "config")
            mark = (
                "[x]"
                if act["selected"] and selectable
                else ("[ ]" if selectable else "   ")
            )
            prefix = ">" if i == idx else " "
            sel_mark = "*" if act["selected"] and selectable else " "
            print(f"{prefix} {sel_mark} {act['name']} - {act['desc']}")

        ch = msvcrt.getwch()
        if ch == "\x1b":
            return
        if ch == "\r":
            current = actions[idx]

            if current["key"] in ("replace", "logs", "loop"):
                current["selected"] = not current["selected"]
                config["selected_actions"] = [
                    a["key"]
                    for a in actions
                    if a["selected"] and a["key"] not in ("run", "exit", "config")
                ]
                save_config(config)
            elif current["key"] == "config":
                edit_config_menu(config)
                continue
            elif current["key"] == "exit":
                return
            elif current["key"] == "run":
                loop_mode = any(a["key"] == "loop" and a["selected"] for a in actions)
                first = True
                selected_exe = (
                    config.get("last_selected_exe")
                    if not config.get("loop_reselect_exe_each_run")
                    else None
                )
                status_summary = {}
                iteration = 0
                loop_start = time.time()
                stats = {
                    "runs": 0,
                    "replace_success": 0,
                    "replace_skipped": 0,
                    "replace_fail": 0,
                    "total_replace_duration_ms": 0,
                }
                while True:
                    replace_selected = any(
                        a["key"] == "replace" and a["selected"] for a in actions
                    )
                    if replace_selected:
                        if (
                            first
                            or config.get("loop_reselect_exe_each_run", False)
                            or not selected_exe
                        ):
                            selected_exe = select_exe_from_bin(config["bin_path"])
                            if selected_exe:
                                config["last_selected_exe"] = selected_exe
                                save_config(config)
                        if not selected_exe:
                            status_summary["replace"] = {"error": "no exe selected"}
                            if loop_mode:
                                loop_mode = False
                        else:
                            status_summary["replace"] = perform_replace(
                                config, selected_exe, silent=True
                            )
                            last_exe_used = selected_exe
                            rep_block = status_summary["replace"].get("replace") or {}
                            if rep_block.get("code") == OK and rep_block.get(
                                "replaced"
                            ):
                                stats["replace_success"] += 1
                                stats["total_replace_duration_ms"] += rep_block.get(
                                    "duration_ms", 0
                                )
                            elif rep_block.get("code") == SAME_FILE:
                                stats["replace_skipped"] += 1
                            else:
                                if rep_block.get("code") not in (OK, SAME_FILE, None):
                                    stats["replace_fail"] += 1
                    if any(a["key"] == "logs" and a["selected"] for a in actions):
                        status_summary["logs"] = clear_logs(config, silent=True)

                    iteration += 1
                    stats["runs"] += 1

                    width = min(160, longest_line + 26)
                    height = 28
                    resize_console(width, height)
                    os.system("cls")
                    title = (
                        "Run Result"
                        if not loop_mode
                        else f"Roblox Tool DelShop\nLoop Iter {iteration}"
                    )
                    print(title)
                    selected_keys = [a["key"] for a in actions if a["selected"]]
                    print(
                        "Selected: "
                        + (", ".join(selected_keys) if selected_keys else "None")
                    )
                    print()
                    rep_stat = status_summary.get("replace")
                    if rep_stat:
                        rep = rep_stat.get("replace") or {}
                        r_lines = ["[REPLACE]"]
                        r_lines.append(
                            f"Executable: {os.path.basename(selected_exe) if selected_exe else 'N/A'}"
                        )
                        r_lines.append(
                            f"Version ID: {rep_stat.get('version_id','?')} (API attempts: {rep_stat.get('api_attempts','?')})"
                        )
                        r_lines.append(
                            f"Version Folder: {os.path.basename(rep_stat.get('version_folder','')) or 'N/A'}"
                        )
                        r_lines.append(f"Mode: {rep.get('mode')}")
                        r_lines.append(
                            f"ProcessKillMode: {rep_stat.get('process_kill_mode')}"
                        )
                        if isinstance(rep_stat.get("process_killed"), dict):
                            pk = rep_stat["process_killed"]
                            r_lines.append(
                                f"Process Kill Code: {pk.get('code')} Killed: {pk.get('killed')}"
                            )
                        else:
                            r_lines.append(
                                f"Process Killed: {rep_stat.get('process_killed')}"
                            )
                        if rep:
                            r_lines.append(f"Result Code: {rep.get('code')}")
                            r_lines.append(
                                f"Replaced: {rep.get('replaced')}  Moved: {rep.get('moved')}  Skipped: {rep.get('skipped')}  SameHash: {rep.get('same_hash')}"
                            )
                            r_lines.append(
                                f"SourceSize: {rep.get('source_size')}  DestSize: {rep.get('dest_size')}"
                            )
                            dur = rep.get("duration_ms")
                            if dur:
                                r_lines.append(f"Duration: {dur} ms")
                        if rep_stat.get("code") and rep_stat.get("code") != OK:
                            r_lines.append(f"Op Code: {rep_stat.get('code')}")
                        if rep_stat.get("error"):
                            r_lines.append(f"Error: {rep_stat.get('error')}")
                        print("\n".join(r_lines))
                    log_stat = status_summary.get("logs")
                    if log_stat:
                        l_lines = ["[LOGS]"]
                        l_lines.append(f"Code: {log_stat.get('code')}")
                        l_lines.append(
                            f"Files Removed: {log_stat.get('removed_files',0)}  Dirs Removed: {log_stat.get('removed_dirs',0)}  Errors: {len(log_stat.get('errors',[]))}"
                        )
                        siu = log_stat.get("skipped_in_use", 0)
                        sio = log_stat.get("skipped_other", 0)
                        if siu or sio:
                            l_lines.append(
                                f"Skipped In-Use: {siu}  Skipped Other: {sio}"
                            )
                        samples = log_stat.get("skipped_in_use_samples") or []
                        if samples:
                            l_lines.append(
                                "In-Use Samples: "
                                + "; ".join(os.path.basename(p) for p in samples)
                            )
                        if log_stat.get("errors"):
                            l_lines.append(
                                "Errors Detail: "
                                + "; ".join(log_stat.get("errors")[:3])
                            )
                        print("\n".join(l_lines))
                    print(
                        "\n"
                        + (
                            "Press any key to return."
                            if not loop_mode
                            else "ESC to stop loop | waiting"
                        )
                    )
                    if not loop_mode:
                        print("\nPress any key to return to menu.")
                        msvcrt.getwch()

                        if stats["runs"] > 1 or any(
                            [
                                stats["replace_success"],
                                stats["replace_skipped"],
                                stats["replace_fail"],
                            ]
                        ):
                            os.system("cls")
                            avg = 0
                            if stats["replace_success"]:
                                avg = int(
                                    stats["total_replace_duration_ms"]
                                    / stats["replace_success"]
                                )

                            elapsed = int(time.time() - loop_start)
                            y = elapsed // (365 * 24 * 3600)
                            rem = elapsed % (365 * 24 * 3600)
                            mo = rem // (30 * 24 * 3600)
                            rem %= 30 * 24 * 3600
                            d = rem // (24 * 3600)
                            rem %= 24 * 3600
                            h = rem // 3600
                            rem %= 3600
                            m = rem // 60
                            s = rem % 60
                            print("Loop Summary")
                            print(f"Runs: {stats['runs']}")
                            print(f"Replace Success: {stats['replace_success']}")
                            print(f"Replace Skipped: {stats['replace_skipped']}")
                            print(f"Replace Fail: {stats['replace_fail']}")
                            print(f"Avg Replace Duration (ms): {avg}")
                            print(f"Elapsed: {y}y {mo}mo {d}d {h}h {m}m {s}s")
                            print("Press any key to continue.")
                            msvcrt.getwch()
                        break

                    delay = config.get("loop_delay_seconds", 5)
                    for remaining in range(delay, 0, -1):
                        print(f"Next loop in {remaining}s...   ", end="\r")
                        start_tick = time.time()
                        while time.time() - start_tick < 1:
                            if msvcrt.kbhit():
                                key2 = msvcrt.getwch()
                                if key2 == "\x1b":
                                    loop_mode = False
                                    break
                            time.sleep(0.05)
                        if not loop_mode:
                            break
                    if not loop_mode:
                        print("\nLoop stopped. Press any key for summary.")
                        msvcrt.getwch()
                        os.system("cls")
                        avg = 0
                        if stats["replace_success"]:
                            avg = int(
                                stats["total_replace_duration_ms"]
                                / stats["replace_success"]
                            )
                        elapsed = int(time.time() - loop_start)
                        y = elapsed // (365 * 24 * 3600)
                        rem = elapsed % (365 * 24 * 3600)
                        mo = rem // (30 * 24 * 3600)
                        rem %= 30 * 24 * 3600
                        d = rem // (24 * 3600)
                        rem %= 24 * 3600
                        h = rem // 3600
                        rem %= 3600
                        m = rem // 60
                        s = rem % 60
                        print("Loop Summary")
                        print(f"Runs: {stats['runs']}")
                        print(f"Replace Success: {stats['replace_success']}")
                        print(f"Replace Skipped: {stats['replace_skipped']}")
                        print(f"Replace Fail: {stats['replace_fail']}")
                        print(f"Avg Replace Duration (ms): {avg}")
                        print(f"Elapsed: {y}y {mo}mo {d}d {h}h {m}m {s}s")
                        print("Press any key to continue.")
                        msvcrt.getwch()
                        break
                    first = False

        elif ch == "\xe0":
            keyc = msvcrt.getwch()
            if keyc == "H":
                idx = (idx - 1) % len(actions)
            elif keyc == "P":
                idx = (idx + 1) % len(actions)


def main():
    disable_quick_edit()
    lock_console_resize()
    config = load_config()
    ensure_bin_folder(config)
    config = prompt_missing_config(config)
    parser = argparse.ArgumentParser(
        description="Roblox Tool DelShop - Replace .exe and clear logs"
    )
    parser.add_argument(
        "--replace-exe",
        metavar="EXE_PATH",
        help="Replace .exe in Roblox version folder",
    )
    parser.add_argument("--clear-logs", action="store_true", help="Clear Roblox logs")
    parser.add_argument(
        "--init-config", action="store_true", help="Reset config to default JSON"
    )
    parser.add_argument("--menu", action="store_true", help="Force interactive menu")
    parser.add_argument(
        "--move", action="store_true", help="Use move mode (remove source after deploy)"
    )
    args = parser.parse_args()

    if args.init_config:
        save_config(DEFAULTS)
        print("Config reset to default.")
        return

    did_action = False
    override_mode = None
    if args.move:
        override_mode = "move"
    if args.replace_exe:
        perform_replace(config, args.replace_exe, override_mode=override_mode)
        did_action = True
    if args.clear_logs:
        clear_logs(config)
        did_action = True

    if not did_action or args.menu:
        interactive_menu(config)


if __name__ == "__main__":
    main()
```