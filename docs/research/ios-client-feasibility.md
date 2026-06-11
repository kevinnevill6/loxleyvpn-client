# iOS Client Feasibility Spike

Date: 2026-06-11
Repo: `loxleyvpn-client`
Branch: `codex/loxley-android-poc`

## Summary

iOS client is technically feasible from the current Amnezia-based fork, but it is not an Android-style quick APK flow. The repository already contains an iOS app target, a Network Extension target, iOS packet tunnel code, AmneziaWG/WireGuard support, Xray support, and the shared QML/App API layer used by the Android PoC.

The first practical milestone should be an iOS PoC, not a TestFlight/App Store release:

1. Build and launch the LoxleyVPN shell on iPhone or simulator without VPN.
2. Reuse the existing App API email/auth/server/config flow.
3. Add Apple signing, bundle IDs, App Group, and Network Extension capability.
4. Then test real AmneziaWG tunnel connect on a physical iPhone.

Current blockers are environment/signing, not backend architecture.

## Current Local Environment

- macOS: 26.5.1
- Architecture: Apple Silicon arm64
- Xcode: 26.5
- iPhoneOS SDK: 26.5
- Available iOS simulators: present
- Code signing identities: none found locally
- Qt installed: `6.10.3/macos` and `6.10.3/android_arm64_v8a`
- Qt iOS kit: not installed

This means the Mac can host iOS development, but the current environment is not ready to build and install the VPN-enabled iOS app.

## Repository iOS Structure

Important existing files:

- `client/cmake/ios.cmake`
  - Defines the iOS app target.
  - Uses Xcode generator.
  - Embeds the Network Extension target.
  - Links UIKit, Foundation, NetworkExtension, StoreKit, UserNotifications, and related Apple frameworks.

- `client/ios/app/Info.plist.in`
  - iOS app plist.
  - Launch storyboard: `AmneziaVPNLaunchScreen`.
  - Document types still reference Amnezia config identifiers.
  - App Group still references upstream Amnezia naming.

- `client/ios/app/main.entitlements`
  - Main app entitlements.
  - Contains `com.apple.developer.networking.networkextension` with `packet-tunnel-provider`.
  - Contains App Group and keychain access group entries using upstream Amnezia naming.

- `client/ios/networkextension/CMakeLists.txt`
  - Defines the `networkextension` app extension target.
  - Product type: `com.apple.product-type.app-extension`.
  - Bundle extension: `appex`.
  - Uses `${BUILD_IOS_APP_IDENTIFIER}.network-extension`.

- `client/ios/networkextension/AmneziaVPNNetworkExtension.entitlements`
  - Network Extension entitlements.
  - Contains `packet-tunnel-provider`.
  - Contains App Group and keychain access group entries using upstream Amnezia naming.

- `client/ios/networkextension/Info.plist.in`
  - Extension point: `com.apple.networkextension.packet-tunnel`.
  - Principal class: `PacketTunnelProvider`.

- `client/platforms/ios/PacketTunnelProvider.swift`
  - Main packet tunnel provider.
  - Selects WireGuard, OpenVPN, or Xray based on provider configuration.

- `client/platforms/ios/PacketTunnelProvider+WireGuard.swift`
  - Starts WireGuard/AWG through the Apple packet tunnel path.

- `client/platforms/ios/PacketTunnelProvider+Xray.swift`
  - Xray tunnel path exists.

- `client/platforms/ios/ios_controller.mm`
  - Creates and manages `NETunnelProviderManager`.
  - Saves tunnel configuration.
  - Starts/stops VPN connection.

- `client/platforms/ios/VPNCController.swift`
  - Removes/clears saved tunnel managers.

## Existing Build Path

The repo has an iOS target in `deploy/build.sh`:

```bash
deploy/build.sh -t ios
```

The script expects:

- Qt iOS kit at `~/Qt/<version>/ios`
- Qt macOS host kit
- Xcode generator
- iPhoneOS SDK by default
- signing/provisioning to be valid for the app and extension

For LoxleyVPN, the build should eventually pass explicit identifiers instead of upstream defaults:

```bash
QT_ROOT_PATH="$HOME/Qt/6.10.3" \
LOXLEY_APP_API_BASE_URL="https://staging.loxleyvpn.ru" \
BUILD_IOS_APP_IDENTIFIER="com.loxleyvpn.client.ios" \
BUILD_IOS_GROUP_IDENTIFIER="group.com.loxleyvpn.client.ios" \
BUILD_VPN_DEVELOPMENT_TEAM="<apple-team-id>" \
CMAKE_BUILD_TYPE=Debug \
deploy/build.sh -t ios
```

Do not run this as the next command yet. First install Qt iOS kit and create Apple signing assets.

## Apple Requirements

For local iPhone testing with a VPN extension, LoxleyVPN needs:

- Apple Developer account access.
- A development certificate.
- The physical iPhone registered in the developer account.
- Main App ID, for example `com.loxleyvpn.client.ios`.
- Extension App ID, for example `com.loxleyvpn.client.ios.network-extension`.
- App Group, for example `group.com.loxleyvpn.client.ios`.
- Network Extension capability enabled with `packet-tunnel-provider`.
- Provisioning profiles for both the app and the extension.

Apple documents that manual development signing needs an App ID, development certificates, and registered devices. Apple also documents the Network Extension entitlement and `NEPacketTunnelProvider` API used by packet tunnel VPN extensions.

Apple Developer Program membership is the realistic route for this project because VPN, extension capabilities, registered tester devices, TestFlight later, and distribution all need the normal developer program workflow. Apple lists the program as 99 USD per membership year.

## Entitlements And Capabilities

Current entitlements already use the right class of capability:

```xml
com.apple.developer.networking.networkextension
packet-tunnel-provider
```

But they still use upstream identifiers:

- upstream app bundle id defaults;
- upstream App Group;
- upstream keychain group;
- upstream development team in CMake defaults;
- upstream launch/storyboard/document type names.

Before the first real iPhone VPN test, replace these with LoxleyVPN identifiers through CMake variables and, where the plist/entitlement files contain literal values, through code changes.

Needed capabilities:

- Network Extensions / Packet Tunnel Provider
- App Groups
- Keychain Sharing if the current shared storage path needs it

The main app and the extension must share compatible App Group and keychain settings, otherwise the extension may build but fail to access saved tunnel/config state.

## Reuse From Android Work

Reusable as-is or with small adjustments:

- QML LoxleyVPN shell: `client/ui/qml/Pages2/PageSetupWizardConfigSource.qml`
- App API controller: `client/ui/controllers/appApiUiController.cpp`
- Email auth flow
- `/me`, `/servers`, `/config` flow
- Device identity concept, although iOS device UUID storage should be verified
- Import pipeline: `ImportController.extractConfigFromData()` and `ImportController.importConfig()`
- Connection entrypoint: `ConnectionController.openConnection()`
- App API base URL build override: `LOXLEY_APP_API_BASE_URL`

Requires verification on iOS:

- Whether the Android-tested AmneziaWG config import shape becomes `Proto::Awg` or `Proto::WireGuard` in the iOS path.
- Whether `ios_controller.mm` receives all obfuscation fields required by AmneziaWG.
- Whether the current Loxley QML shell fits iPhone safe areas and keyboard behavior.
- Whether split tunneling for Russian services maps correctly to iOS `excludeIPs` / provider configuration.

## Important Security Cleanup Before iOS VPN Test

Some iOS tunnel code currently logs config-related details for debugging. Before testing real configs on iPhone, review and remove/redact config previews from:

- `client/platforms/ios/PacketTunnelProvider.swift`
- `client/platforms/ios/PacketTunnelProvider+WireGuard.swift`
- `client/platforms/ios/PacketTunnelProvider+OpenVPN.swift`

Do this before any real staging config is passed into iOS logs.

## First iOS PoC Plan

Recommended separate branch:

```bash
git checkout -b codex/loxley-ios-poc
```

Do not continue iOS work directly on the Android beta branch once code changes start.

### Phase 1: Environment

1. Install Qt 6.10.3 iOS kit into `~/Qt/6.10.3/ios`.
2. Confirm `~/Qt/6.10.3/ios/lib/cmake/Qt6/qt.toolchain.cmake` exists.
3. Add Apple Developer account in Xcode.
4. Create or download development signing certificate.
5. Register test iPhone UDID.

### Phase 2: Loxley Identifiers

1. Main bundle ID: `com.loxleyvpn.client.ios`.
2. Extension bundle ID: `com.loxleyvpn.client.ios.network-extension`.
3. App Group: `group.com.loxleyvpn.client.ios`.
4. Enable Network Extension / packet tunnel capability.
5. Enable App Groups.
6. Generate development provisioning profiles for both targets.

### Phase 3: UI-Only Build

Goal: launch the app shell before touching real VPN.

1. Build iOS app with Loxley bundle IDs.
2. Run on simulator or iPhone.
3. Verify:
   - app opens;
   - LoxleyVPN splash/login/home/locations/profile render;
   - no old Amnezia shell is visible;
   - keyboard/safe areas are acceptable.

### Phase 4: App API

1. Set default backend to staging with `LOXLEY_APP_API_BASE_URL`.
2. Test email auth.
3. Test `/me`.
4. Test `/servers`.
5. Test device limit handling.
6. Test `/config` response without printing token/config.

### Phase 5: VPN Tunnel

1. Sanitize iOS tunnel logs.
2. Import real staging AmneziaWG config through existing pipeline.
3. Trigger `ConnectionController.openConnection()`.
4. Confirm iOS system VPN permission prompt.
5. Confirm packet tunnel starts.
6. Confirm VPN status in iOS settings/status bar.
7. Cleanup staging access/peer through existing backend lifecycle.

## Main Risks

- Signing/provisioning is the biggest short-term blocker.
- Network Extension capability must be enabled on the correct App IDs.
- VPN extensions cannot be tested like Android APK distribution.
- Physical iPhone testing is required for the real VPN tunnel.
- Simulator can help UI work, but it is not enough for the final tunnel proof.
- Upstream Amnezia identifiers remain in several iOS plist/entitlement/document-type fields.
- Current iOS code includes StoreKit files; beta should keep payment copy as website/Telegram and avoid Apple IAP until product policy is decided.
- App Store review may scrutinize VPN behavior, privacy policy, logging, and account/subscription flow.
- GPL-3.0 obligations remain: the client fork must be open-source if distributed.

## Feasibility Verdict

Yes, start iOS now, but as a separate iOS PoC branch.

Fastest realistic path:

1. Install Qt iOS kit.
2. Set up Apple Developer signing/capabilities.
3. Rebrand iOS bundle IDs/app group/entitlements.
4. Build UI-only app.
5. Connect App API.
6. Then test real AmneziaWG tunnel.

Expected effort:

- UI-only first launch: 1-2 focused sessions after Qt iOS kit and signing are ready.
- App API parity with Android: likely 1-2 sessions because the controller/QML flow is shared.
- Real VPN connect: 2-5 sessions depending on signing, entitlement, AWG config mapping, and iOS-specific tunnel errors.

## Sources

- Apple Developer Program: https://developer.apple.com/programs/
- Apple membership pricing: https://developer.apple.com/support/compare-memberships/
- Development provisioning profile: https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/
- Network Extension entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension
- NEPacketTunnelProvider: https://developer.apple.com/documentation/NetworkExtension/NEPacketTunnelProvider
