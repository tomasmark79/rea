# REA on NixOS

This source-checkout environment targets **x86_64 Linux**. Nix supplies the
external tools separately from REA's installer. It does not activate a NixOS
configuration, install licensed providers, or start device/network services.

## Start

From the repository root:

```sh
nix-build nix --out-link .cache/nix-environment
nix-shell
npm ci
npm run build:cached
rea --help
rea doctor --provider ghidra --json
rea mcp doctor --json
```

For a shell-visible command outside `nix-shell`, create this link once:

```sh
mkdir -p ~/.local/bin
ln -s "$PWD/.cache/nix-environment/bin/rea" ~/.local/bin/rea
```

Keep the checkout and `.cache/nix-environment` in place. The latter is also a
Nix garbage-collection root. Rebuilding it refreshes the linked command. Moving
the checkout requires rebuilding the environment and updating the link. The
launcher runs the compiled checkout, so rebuild after updating REA source.

## Included tools

| Area                   | Tools                                                                                                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| REA build/runtime      | Node 24.18.0, npm 11.16.0, GCC, Make, pkg-config, Git                                                      |
| Native decompilation   | Ghidra 12.1.4, full JDK 21                                                                                 |
| ELF and recorded cores | Python with pwntools 4.15.0, pyelftools 0.33, Unicorn 2.1.2; GDB, binutils, file, patchelf, strace, ltrace |
| JavaScript/Electron    | REA's static tools, Wakaru 1.14.0                                                                          |
| Android                | JADX headless MCP 0.7.1, JADX CLI/GUI, Apktool, adb                                                        |
| Firmware               | Binwalk 3.1.0, Unblob 26.6.4 and its Nix-packaged extractors, squashfs/e2fs utilities                      |
| Web and captures       | Chromium, mitmdump/mitmproxy                                                                               |
| General inspection     | jq, ripgrep, archive/compression tools, util-linux                                                         |

The nixpkgs revision and extra upstream downloads are pinned with hashes in
`environment.nix`. The Python versions match REA's admitted ELF profile. Ghidra's
Linux native executables and downloaded native wheels are patched for NixOS by
Nix. Provider Evidence retains the actual installed executable identities.

The launcher supplies absolute provider paths, including the resource limiters
that otherwise default to `/usr/bin/prlimit`. Existing `REA_*` settings and
`GHIDRA_INSTALL_DIR` override the defaults. This environment deliberately selects
its JDK 21 instead of an inherited system `JAVA_HOME`; use
`REA_NIX_JAVA_HOME=/absolute/jdk` to choose another full JDK.

## Use

```sh
rea function /absolute/program main --provider ghidra --json
rea inspect-binary-layout /absolute/program --json
rea analyze-javascript-application /absolute/app-directory --json
rea recover-javascript-sources /absolute/bundle.js /absolute/new-output --json
rea inspect-android-package /absolute/app.apk --json
rea decode-android-resources /absolute/app.apk --json
rea inspect-firmware-regions /absolute/firmware.bin --json
rea extract-firmware /absolute/firmware.bin /absolute/new-output --json
```

See the [CLI guide](../docs/cli.md) for sessions, Evidence, provider selection,
and per-command help. Native Apple UI observation still requires macOS. Hopper,
IDA, JEB, attached Android devices, and recorded crash inputs are not supplied.

## Codex

Register the Nix launcher, so GUI clients receive the same tool environment:

```toml
[mcp_servers.rea]
command = "/absolute/home/.local/bin/rea"
args = ["mcp"]
startup_timeout_sec = 30
```

Back up an existing configuration before editing and preserve other servers.
Install the matching generated `skills/reverse-engineer-anything` directory in
the client's shared personal skills location if needed. Review and approve
configuration/skill changes as required by the repository setup policy.
Restart or reconnect Codex after registration. `rea mcp doctor --json` verifies
the actual stdio server independently of the current chat connection.

`rea update` does not update a source checkout. Update the checkout through Git,
then repeat `npm ci` and `npm run build:cached` inside `nix-shell`. Rebuild the
Nix environment when changing its pinned tools.

## Local verification

Verified on NixOS x86_64 with this checkout:

- A real Ghidra function dossier returned the compiled fixture's pseudocode.
- ELF inspection used the exact pwntools profile above.
- JADX inspected the pinned Appium ApiDemos APK; Apktool decoded its resources.
- Binwalk inspected a gzip fixture and Unblob extracted its content.
- JavaScript application analysis and Wakaru source recovery returned Evidence.
- Chromium launched headlessly through Playwright.
- Process capture recorded a real PTY run and reported completed cleanup.
- Production MCP initialization listed 170 tools and six prompts.
- The Android snapshot regression tests, typecheck, and lint passed.

These are smoke checks, not the complete provider conformance suites. Real
device operations, recorded crash inspection, live website capture, licensed
providers, and macOS/Windows workflows were not exercised. General `doctor`
still reports NixOS outside Hopper's supported automatic-installation hosts;
use `doctor --provider ghidra` to check the selected native provider.
