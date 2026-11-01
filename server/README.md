# Test headless ENet host (Godot 4.5.2)

The production ASP.NET Core authoritative server is **not** implemented.
This service runs the same scene and GDScript as the Windows/Android clients, in headless mode, with no server player avatar.

## LAN deployment on bacus-server
1. Place official Godot 4.5.2 Linux x86_64 standard executable at `/srv/bacus/apps/eldoria-test-server/godot`.
2. Copy the version-matched `client/` game source to `/srv/bacus/apps/eldoria-test-server/client/`.
3. Set owner `mbacus`, then install `server/eldoria-test.service` as `/etc/systemd/system/eldoria-test.service`.
4. `sudo systemctl daemon-reload && sudo systemctl enable --now eldoria-test`; verify `systemctl status eldoria-test` and `ss -lun | grep :7777`.
5. Clients in the same trusted LAN enter the server's private IPv4 and join. Allow **UDP 7777** from the trusted LAN only if a firewall blocks it. Do **not** forward public WAN UDP 7777; this prototype lacks auth/anti-cheat and is not Internet-safe.

Local E2E test: `bash tests/run_dedicated_e2e.sh` runs its own server. To test an already-running LAN server and two clients instead, start two Godot test scripts with `ELDORIA_SERVER_IP=<LAN_IP>`; each script uses the same client code. Server logs report connections, movements are replicated and Wave actions broadcast.

Windows: unzip ZIP entirely, run `Eldoria.exe`. Android: install signed ARM64 debug APK. Both require the same UDP endpoint. Android localhost 127.0.0.1 never points to the PC.

Use only for controlled testing. No persistent storage, authentication or authoritative validation. Planned .NET migration needs a network contract/transport spike.
