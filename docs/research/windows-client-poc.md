# GuardoVPN Windows Client PoC

## Status

Android beta is already in tester handoff. iOS is waiting for Apple Developer Program activation before real VPN tunnel work. Windows can start in parallel as a build/readiness PoC.

This document covers Windows preparation only. It does not describe production release, code signing, or public distribution.

## Target

Initial Windows target:

- Windows 10 x64
- Windows 11 x64

Windows ARM64 is out of scope for the first PoC. The first practical release should focus on normal Intel/AMD Windows PCs.

## Existing Windows Support

The Amnezia-based client already contains Windows-specific code:

- `deploy/build.bat` - Windows build entrypoint.
- `client/platforms/windows/` - Windows utilities, service manager, route monitor, firewall, tunnel service.
- `client/platforms/windows/daemon/` - Windows tunnel daemon pieces.
- `client/core/protocols/ikev2VpnProtocolWindows.*` - Windows-specific protocol implementation.
- `cmake/CPack.cmake` - Windows installer packaging through IFW/WiX.
- `deploy/data/windows/` - Windows post-install and uninstall hooks.

The shared GuardoVPN QML/App API layer should be reusable on Windows:

- email login;
- one-time code flow;
- profile/subscription status;
- device limits;
- locations list;
- backend-driven config request.

## Build Dependencies

For a local Windows build, the expected dependencies are:

- Windows 10/11 x64;
- Visual Studio 2022 Build Tools with MSVC C++ toolchain;
- CMake 3.25+;
- Python 3.14 or compatible Python 3.x;
- Conan 2.x;
- Qt 6.10.x for `msvc2022_64`;
- Qt modules:
  - Qt Remote Objects;
  - Qt 5 Compatibility Module;
  - Qt Shader Tools;
  - Qt Quick / Quick Controls;
  - Qt SVG;
  - Qt Linguist Tools.

Installer builds additionally need:

- Qt Installer Framework for IFW `.exe`;
- WiX Toolset for `.msi`;
- Windows code signing certificate for tester-friendly distribution.

Code signing is not required for the first compile PoC, but unsigned builds can trigger Windows SmartScreen warnings.

## GitHub Actions PoC Build

Manual workflow:

```text
.github/workflows/windows-poc-build.yml
```

It builds Windows x64 on a GitHub-hosted Windows runner and uploads the build folder as an artifact.

Run it from GitHub:

1. Open `Actions`.
2. Select `Windows PoC Build`.
3. Click `Run workflow`.
4. Choose `Debug` for the first run.
5. Download the artifact after the job finishes.

The workflow does not:

- deploy anything;
- publish a release;
- sign binaries;
- create production installers;
- touch backend;
- use VPN configs or secrets.

## Local Windows Build Command

From a Windows developer shell with MSVC available:

```bat
deploy\build.bat --config Debug --architecture amd64
```

Release compile check:

```bat
deploy\build.bat --config Release --architecture amd64
```

Installer build is a later step:

```bat
deploy\build.bat --config Release --architecture amd64 --installer all
```

Do not start with installer/signing work until the plain Windows app build is confirmed.

## Real Windows Test Checklist

For a tester or a temporary Windows PC:

- Windows 10/11 x64;
- local administrator rights;
- normal internet connection;
- no corporate VPN/proxy/firewall restrictions if possible;
- install/run GuardoVPN build;
- app opens without crash;
- email login works;
- code verification works;
- profile shows active subscription;
- device limit is displayed;
- locations load from staging;
- selecting location requests config;
- Android/iOS-only wording is not visible;
- VPN permission/service prompts are understandable;
- AmneziaWG connect reaches connected state;
- disconnect works;
- restart app and reconnect;
- reboot Windows and reconnect.

## Risks

- Windows VPN path may require admin rights and service installation.
- Unsigned binaries may be blocked or warned by SmartScreen.
- Installer packaging may still contain upstream Amnezia names/icons.
- Some Windows daemon/service paths may assume upstream product identifiers.
- VPN connect cannot be validated on GitHub-hosted runners.
- A real Windows x64 machine is required before calling the Windows client usable.

## Next Steps

1. Run `Windows PoC Build` on GitHub.
2. Fix compile errors if any.
3. Produce a temporary unsigned build artifact.
4. Test launch/App API on a real Windows x64 PC.
5. Test AmneziaWG connect on that PC.
6. After real connect works, prepare installer branding and code signing.
