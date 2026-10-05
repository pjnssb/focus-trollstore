#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Focus"
SCHEME="Focus"
PROJECT="Focus.xcodeproj"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
IPA_PATH="$ROOT_DIR/$APP_NAME.ipa"

rm -rf "$BUILD_DIR" "$IPA_PATH"
mkdir -p "$BUILD_DIR"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Archiving unsigned app"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER=""

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name "$APP_NAME.app" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "error: could not find $APP_NAME.app in archive" >&2
  exit 1
fi

echo "==> Preparing Payload"
rm -rf "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"

SIGN_APP="$BUILD_DIR/Payload/$APP_NAME.app"

find "$SIGN_APP" -name "_CodeSignature" -type d -prune -exec rm -rf {} +
find "$SIGN_APP" -name "embedded.mobileprovision" -type f -delete

sign_binary() {
  local binary="$1"
  local entitlements="$2"

  if [[ ! -f "$binary" ]]; then
    echo "warning: binary not found: $binary" >&2
    return
  fi

  if [[ ! -f "$entitlements" ]]; then
    echo "warning: entitlements not found: $entitlements" >&2
    return
  fi

  echo "ldid -S $entitlements -> $binary"
  ldid -S"$entitlements" "$binary"
}

echo "==> Signing app extensions"
sign_binary "$SIGN_APP/PlugIns/DeviceActivityMonitor.appex/DeviceActivityMonitor" \
  "$ROOT_DIR/Extensions/DeviceActivityMonitor/DeviceActivityMonitor.entitlements"

sign_binary "$SIGN_APP/PlugIns/ShieldConfiguration.appex/ShieldConfiguration" \
  "$ROOT_DIR/Extensions/ShieldConfiguration/ShieldConfiguration.entitlements"

sign_binary "$SIGN_APP/PlugIns/ShieldAction.appex/ShieldAction" \
  "$ROOT_DIR/Extensions/ShieldAction/ShieldAction.entitlements"

echo "==> Signing main app"
sign_binary "$SIGN_APP/$APP_NAME" "$ROOT_DIR/FocusApp/FocusApp.entitlements"

echo "==> Verifying entitlements"
codesign -d --entitlements :- "$SIGN_APP/$APP_NAME" 2>&1 || true
codesign -d --entitlements :- "$SIGN_APP/PlugIns/DeviceActivityMonitor.appex/DeviceActivityMonitor" 2>&1 || true
codesign -d --entitlements :- "$SIGN_APP/PlugIns/ShieldConfiguration.appex/ShieldConfiguration" 2>&1 || true
codesign -d --entitlements :- "$SIGN_APP/PlugIns/ShieldAction.appex/ShieldAction" 2>&1 || true

echo "==> Packaging IPA"
(
  cd "$BUILD_DIR"
  zip -qry "$IPA_PATH" Payload
)

echo "==> Done"
ls -lh "$IPA_PATH"
shasum -a 256 "$IPA_PATH"