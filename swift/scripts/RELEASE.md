# Release engineering guide — Claude MTW Replay (Swift)

This document covers the **manual** steps required to ship a signed,
notarized, auto-updating Mac build. Items marked **(automated)** are
handled by scripts in this directory; everything else requires Apple
credentials and cannot be scripted without secrets.

## Prerequisites (one-time setup)

### 1. Apple Developer Program enrollment ($99/year)
- Enroll: <https://developer.apple.com/programs/>
- In Xcode → **Settings → Accounts → Manage Certificates**, generate a
  **Developer ID Application** certificate. (This is the identity used to
  sign apps distributed outside the App Store.)
- Note your **Team ID** (10-character identifier shown in
  <https://developer.apple.com/account>).

### 2. App-specific password for notarization
- <https://account.apple.com> → **Sign-In and Security → App-Specific Passwords**
- Create one labelled e.g. `notarize-claude-replay`.
- Store it in the keychain so scripts never see the plaintext password:
  ```bash
  xcrun notarytool store-credentials "NOTARIZE" \
    --apple-id <your-apple-id@example.com> \
    --team-id <TEAMID> \
    --password <app-specific-password>
  ```
- Subsequent runs of `notarize.sh` can use `NOTARY_PROFILE=NOTARIZE`
  instead of the three env vars.

### 3. Sparkle EdDSA keys (for auto-update signing)
- Install Sparkle CLI tools: `brew install --cask sparkle`
  (or download from <https://github.com/sparkle-project/Sparkle/releases>).
- Generate a keypair (stored in keychain):
  ```bash
  generate_keys
  ```
- Copy the printed **public key** into `Info.plist` under `SUPublicEDKey`,
  and set `SUFeedURL` to your hosted `appcast.xml` URL.
- The private key never leaves your keychain.

### 4. Code-signing identity in project.yml
Edit `swift/project.yml` and replace the ad-hoc identity:
```yaml
settings:
  base:
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "Developer ID Application: <Your Name> (<TEAMID>)"
    DEVELOPMENT_TEAM: <TEAMID>
    ENABLE_HARDENED_RUNTIME: "YES"
```
Then regenerate the Xcode project:
```bash
cd swift && xcodegen
```

## Release flow

For every new version:

1. **Bump version** in `swift/project.yml` (`MARKETING_VERSION`)
   and `swift/sidecar/package.json` (`version`). Keep them in sync.
2. **Update `swift/CHANGELOG.md`** — move `[Unreleased]` entries under a
   new dated `[X.Y.Z]` heading.
3. **Build the DMG** *(automated)*:
   ```bash
   swift/scripts/build-dmg.sh
   ```
   Produces `swift/dist/Claude-MTW-Replay-<version>.dmg`. Reads version
   directly from `project.yml`.
4. **Verify universal binary** *(automated, RE4)*:
   ```bash
   swift/scripts/verify-universal.sh \
     swift/build/Build/Products/Release/'Claude MTW Replay.app'
   ```
   Must report `arm64 + x86_64`.
5. **Notarize** *(scripted, but needs Apple creds — RE2)*:
   ```bash
   NOTARY_PROFILE=NOTARIZE \
     swift/scripts/notarize.sh swift/dist/Claude-MTW-Replay-<version>.dmg
   ```
   Submits to Apple, waits for the verdict, then staples the ticket.
6. **Stage the release**:
   ```bash
   mkdir -p swift/releases
   cp swift/dist/Claude-MTW-Replay-<version>.dmg swift/releases/
   ```
7. **Refresh Sparkle appcast** *(scripted — RE3)*:
   ```bash
   swift/scripts/sparkle-appcast.sh swift/releases
   ```
   Regenerates `swift/releases/appcast.xml` with the new entry, signed
   with the keychain-resident EdDSA key.
8. **Commit and tag**:
   ```bash
   git add swift/project.yml swift/sidecar/package.json swift/CHANGELOG.md \
           swift/releases/appcast.xml
   git commit -m "release: Swift v<version>"
   git tag -a swift-v<version> -m "Swift v<version> release"
   git push origin main --tags
   ```
9. **Publish**: upload `swift/releases/Claude-MTW-Replay-<version>.dmg`
   and `swift/releases/appcast.xml` to the hosting target referenced by
   `SUFeedURL`.

## Mapping to the audit (`docs/IMPROVEMENTS_SWIFT.md` § Distribution)

| Item | Status                | Where                          |
|------|-----------------------|--------------------------------|
| RE1  | Manual — needs cert   | `project.yml` settings + Xcode |
| RE2  | Scripted, needs creds | `scripts/notarize.sh`          |
| RE3  | Scripted, needs keys  | `scripts/sparkle-appcast.sh`   |
| RE4  | Automated             | `scripts/verify-universal.sh`  |

RE1/RE2/RE3 cannot be fully automated in CI without provisioning Apple
Developer credentials and Sparkle private keys as secrets — out of scope
for this scaffold.
