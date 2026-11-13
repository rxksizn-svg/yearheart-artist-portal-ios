#!/bin/bash
set -euo pipefail
umask 077
[[ -n "$TEAM_ID" && -n "$CERT_B64" && -n "$CERT_PASSWORD" ]] || { echo 'Missing signing variables/secrets'; exit 1; }
if [[ "$APP" == 'YearHeart' ]]; then PROFILE="$YEARHEART_PROFILE"; BUNDLE="$YEARHEART_BUNDLE_ID"; else PROFILE="$ADA_PROFILE"; BUNDLE="$ADA_BUNDLE_ID"; fi
[[ -n "$PROFILE" && -n "$BUNDLE" && "$BUNDLE" != com.example.* ]] || { echo 'Set the real Bundle ID and App Store profile'; exit 1; }
printf '%s' "$CERT_B64" | base64 --decode > "$RUNNER_TEMP/certificate.p12"
printf '%s' "$PROFILE" | base64 --decode > "$RUNNER_TEMP/profile.mobileprovision"
security cms -D -i "$RUNNER_TEMP/profile.mobileprovision" > "$RUNNER_TEMP/profile.plist"
export BUNDLE
python3 - <<'PY'
import os,plistlib
with open(os.environ['RUNNER_TEMP']+'/profile.plist','rb') as f: p=plistlib.load(f)
assert os.environ['TEAM_ID'] in p['TeamIdentifier'], 'Profile Team ID mismatch'
assert p['Entitlements']['application-identifier'].endswith('.'+os.environ['BUNDLE']), 'Profile Bundle ID mismatch'
assert not p.get('ProvisionedDevices') and not p.get('ProvisionsAllDevices'), 'Requires App Store distribution profile'
opts={'method':'app-store-connect','signingStyle':'manual','teamID':os.environ['TEAM_ID'],'provisioningProfiles':{os.environ['BUNDLE']:p['Name']},'uploadSymbols':True}
os.makedirs('build',exist_ok=True)
with open('build/ExportOptions.plist','wb') as f: plistlib.dump(opts,f)
PY
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$RUNNER_TEMP/profile.plist")
KEYCHAIN="$RUNNER_TEMP/ipad-build.keychain-db"
KEYCHAIN_PASSWORD=$(openssl rand -hex 24)
echo "::add-mask::$KEYCHAIN_PASSWORD"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$RUNNER_TEMP/certificate.p12" -P "$CERT_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$RUNNER_TEMP/profile.mobileprovision" "$HOME/Library/MobileDevice/Provisioning Profiles/ipad-actions.mobileprovision"
xcodebuild -project PartnerApps.xcodeproj -scheme "$APP" -configuration Release -destination 'generic/platform=iOS' -archivePath "build/$APP.xcarchive" DEVELOPMENT_TEAM="$TEAM_ID" YEARHEART_BUNDLE_ID="$YEARHEART_BUNDLE_ID" ADA_BUNDLE_ID="$ADA_BUNDLE_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" archive
xcodebuild -exportArchive -archivePath "build/$APP.xcarchive" -exportOptionsPlist build/ExportOptions.plist -exportPath build/export
