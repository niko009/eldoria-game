extends Node
# Release manifest checked on both platforms. Android update installation is always
# delegated to the browser/OS; Windows can restart through a bundled updater script.
signal update_available(version: String, message: String)
signal update_status(message: String)

const MANIFEST_URL := "https://bacus.dev/projects/eldoria/latest.json"
const WINDOWS_BASE := "https://bacus.dev/projects/eldoria/Eldoria-Windows-"
const ANDROID_BASE := "https://bacus.dev/projects/eldoria/Eldoria-"
var current_version := "0.5.2"
var latest_version := ""
var download_url := ""
var download_sha256 := ""
var updater_enabled := true
var request: HTTPRequest

func _ready() -> void:
    request = HTTPRequest.new()
    request.timeout = 12.0
    add_child(request)
    request.request_completed.connect(_manifest_response)

func check_for_updates() -> void:
    request.cancel_request()
    var url := MANIFEST_URL
    var override_url := OS.get_environment("ELDORIA_UPDATE_MANIFEST_URL")
    if not override_url.is_empty() and OS.has_feature("editor"):
        url = override_url
    var result := request.request(url, ["Cache-Control: no-cache"])
    if result != OK:
        update_status.emit("Cannot check for updates.")

func _manifest_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() > 8192:
        update_status.emit("Update check unavailable.")
        return
    var parsed := JSON.new()
    if parsed.parse(body.get_string_from_utf8()) != OK or not parsed.data is Dictionary:
        update_status.emit("Invalid update manifest.")
        return
    var manifest: Dictionary = parsed.data
    if int(manifest.get("schema", 0)) != 1:
        update_status.emit("Unsupported update manifest.")
        return
    var ver := String(manifest.get("version", ""))
    if not _valid_semver(ver):
        update_status.emit("Invalid update version.")
        return
    var key := "android" if OS.get_name() == "Android" else "windows"
    var package: Variant = manifest.get(key, {})
    if not package is Dictionary:
        update_status.emit("No update for your platform.")
        return
    var url := String(package.get("url", ""))
    var sha := String(package.get("sha256", "")).to_lower()
    var expected_name := "Eldoria-%s-debug.apk" % ver if key == "android" else "Eldoria-Windows-%s.zip" % ver
    var base := ANDROID_BASE if key == "android" else WINDOWS_BASE
    # Only allow our own release path, not arbitrary URLs from the manifest.
    if url != "https://bacus.dev/projects/eldoria/" + expected_name:
        update_status.emit("Untrusted update address.")
        return
    if sha.length() != 64 or not sha.is_valid_hex_number():
        update_status.emit("Invalid update checksum.")
        return
    if _version_number(ver) <= _version_number(current_version):
        update_status.emit("Eldoria is up to date (v%s)." % current_version)
        return
    latest_version = ver
    download_url = url
    download_sha256 = sha
    update_available.emit(ver, String(manifest.get("notes", "New version available.")))
    if OS.get_name() == "Windows" and updater_enabled:
        # Do not silently stop a running session. We download/restart at
        # launch only, before the local player joins any session.
        _run_windows_updater()

func install_update() -> void:
    if latest_version.is_empty():
        return
    if OS.get_name() == "Android":
        update_status.emit("Opening Android installer for v%s. Confirm installation in Android." % latest_version)
        OS.shell_open(download_url)
    elif OS.get_name() == "Windows":
        _run_windows_updater()

func _run_windows_updater() -> void:
    var directory := OS.get_executable_path().get_base_dir()
    var script := directory.path_join("EldoriaUpdater.ps1")
    if not FileAccess.file_exists(script):
        update_status.emit("Updater missing. Download the new ZIP from bacus.dev.")
        return
    var pid := OS.get_process_id()
    var args := PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
        "-File", script, "-GameDir", directory, "-WaitForPid", str(pid)])
    var started := OS.create_process("powershell.exe", args, false)
    if started <= 0:
        update_status.emit("Could not start updater. Download the latest ZIP manually.")
        return
    update_status.emit("Installing v%s and restarting Eldoria..." % latest_version)
    get_tree().quit()

func _valid_semver(v: String) -> bool:
    var parts := v.split(".")
    if parts.size() != 3:
        return false
    for part in parts:
        if part.is_empty() or not part.is_valid_int() or part.length() > 4 or part.begins_with("-"):
            return false
    return true

func _version_number(v: String) -> int:
    if not _valid_semver(v):
        return 0
    var p := v.split(".")
    return int(p[0]) * 100000000 + int(p[1]) * 10000 + int(p[2])
