# xraywrap

A macOS wrapper around your Xray (VLESS + Reality) client that can force
**all** of your Mac's traffic through it, or just set it as the system
proxy — managed with simple commands, with automatic rollback if anything
goes wrong.

## One-time setup

```bash
sudo ./install.sh
```

This downloads `xray` + `tun2socks` and symlinks `xraywrap` onto your PATH
(`/usr/local/bin/xraywrap`). From then on, run it as a plain command from
anywhere:

```
xraywrap start           # tun mode: whole machine, on by default
xraywrap start socks     # lighter alternative: system SOCKS proxy only
xraywrap status
xraywrap stop
xraywrap doctor
xraywrap panic           # hard reset if something's stuck
sudo xraywrap enable     # start tun mode automatically at boot (launchd)
sudo xraywrap disable    # stop doing that
```

(`start`/`stop`/`restart`/`enable`/`disable`/`panic`/`uninstall` need `sudo`
since they touch routes / system network settings — `xraywrap` re-checks
this itself and tells you if you forgot.)

Config lives in `etc/config.env` (gitignored — it holds your VLESS UUID and
Reality keys; `install.sh` creates it from `etc/config.env.example` on first
run if it's missing) — edit it, then `sudo xraywrap restart`.

Didn't run the installer? Everything above also works as
`sudo /Users/budd/dev/xraywrap/bin/xraywrap <command>`.

## How "tun" mode works

1. `xray` runs unprivileged, listening as a SOCKS5 server on `127.0.0.1`
   only — same VLESS+Reality client config validated earlier.
2. `tun2socks` opens a virtual `utunN` interface and feeds everything it
   receives on that interface to the local SOCKS5 proxy.
3. We assign the tun interface `198.18.0.1` and add routes for the bulk of
   IPv4 space (the exact partition [tun2socks' own maintainers document for
   macOS](https://github.com/xjasonlyu/tun2socks/wiki/Examples)) pointing at
   it. Your existing LAN routes (e.g. `192.168.1.0/24`) are more specific and
   keep winning on longest-prefix-match, so local devices/printers/etc. stay
   reachable normally.
4. DNS (optional, `TUN_DNS_SERVERS` in config) gets pointed at public
   resolvers so lookups are tunneled too, not leaked to your ISP.

## Avoiding the loop

Xray's own outbound connection to your VPS (`v2ray.budd.codes:8443`) is a
normal process socket subject to the same routing table as everything else.
Once the wide tun routes are in place, that connection would get recaptured
and sent back into the tunnel it's trying to establish — infinite loop.

Before installing the wide routes, xraywrap resolves your server's IP and
adds an explicit host route for it via your *original* gateway/interface.
That's more specific than any of the wide tun routes, so Xray's own traffic
to the VPS always goes out directly, never through the tunnel.

`xraywrap doctor` checks this route is actually present and flags it as a
loop risk if it's missing.

## Safety model

- `start` prints exactly what it's about to change and asks for
  confirmation (skip with `--yes`).
- Right after coming up, it runs a live connectivity check. If that fails,
  it automatically rolls back every change it made (routes, DNS, processes)
  before exiting — you should never be left stranded.
- The state file (`var/run/state.env`) records exactly what was changed, so
  `stop` reverses precisely that, in reverse order.
- `panic` ignores the state file and force-restores networking anyway:
  kills known processes, removes the known route partition, resets DNS and
  the system SOCKS proxy on every network service. Use it if `stop` won't
  work or you're not sure what state things are in.
- Nothing here uses `pf`/firewall rules or touches your default route
  directly — only additive, individually-reversible route entries.

## Modes

| | `tun` | `socks` |
|---|---|---|
| Forces | every process, all protocols | only proxy-aware apps |
| Needs root | yes (routes, utun, DNS) | yes (`networksetup`) |
| Loop risk | mitigated via bypass route | none (no routing changes) |
| Good for | "force the whole PC" | quick/low-risk testing |

## Boot-time service

`sudo xraywrap enable` installs a LaunchDaemon
(`/Library/LaunchDaemons/com.xraywrap.tunnel.plist`) that runs
`xraywrap start tun --yes` once at boot, as root, with `KeepAlive` off (it's
a one-shot trigger — xray/tun2socks daemonize themselves; launchd isn't
supervising them long-term). It's opt-in: `install.sh` never enables it for
you. `sudo xraywrap disable` removes the job (the running tunnel itself, if
any, is untouched — `xraywrap stop` that separately). Logs from the boot run
land in `var/log/launchd.log`.

## Requirements

- macOS (uses `utun` + BSD `route`; won't work on Linux/Windows as-is).
- No Homebrew dependency — `install` fetches both binaries straight from
  their GitHub releases for your CPU architecture.

## Files

```
bin/xraywrap        the CLI
etc/config.env       your server + behavior config
vendor/              downloaded xray + tun2socks binaries
var/run/             pidfiles + state.env (what's currently applied)
var/log/             xray.log, tun2socks.log
```
