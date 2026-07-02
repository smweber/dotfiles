#!/bin/bash
#
# macos-defaults.sh - Apply macOS system preferences via `defaults` etc.
#
# Invoked by bootstrap.sh on macOS hosts. Safe to re-run (idempotent).
# Most changes take effect after the affected service is restarted at the
# end of this script; a few (modifier remap, some gestures) are fully
# reliable only after logout/login.
#
# NOTE: several settings below cannot be verified from a non-macOS machine.
# The ones flagged "VERIFY" use documented-but-fragile keys / key codes and
# may need a small tweak on your Mac. See README notes at the call site.
#

set -uo pipefail

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "macos-defaults.sh: not macOS ($OSTYPE), nothing to do." >&2
    exit 0
fi

say() { printf '    - %s\n' "$1"; }

# ============================================================================
# Keyboard
# ============================================================================

# --- Caps Lock -> Control -----------------------------------------------------
# Mirror System Settings > Keyboard > Keyboard Shortcuts... > Modifier Keys.
# That pane stores a per-keyboard remap in the ByHost global domain under
#   com.apple.keyboard.modifiermapping.<VendorID>-<ProductID>-0
# as an array of {Src,Dst} dicts using HID usage codes:
#   Caps Lock    = 0x700000039 = 30064771129
#   Left Control = 0x7000000E0 = 30064771296
# We target only the built-in keyboard (AppleEmbeddedKeyboard), as requested.
# Change takes effect after the next login (System Settings also pokes IOKit
# to apply it live; a logout/login is the reliable trigger for this method).
CAPS_SRC=30064771129
CTRL_DST=30064771296

# Grab the internal keyboard's VendorID/ProductID from IOKit.
kb_vendor=$(ioreg -c AppleEmbeddedKeyboard -r 2>/dev/null | awk '/"VendorID"/  {print $NF; exit}')
kb_product=$(ioreg -c AppleEmbeddedKeyboard -r 2>/dev/null | awk '/"ProductID"/ {print $NF; exit}')

if [[ -n "$kb_vendor" && -n "$kb_product" ]]; then
    kb_id="$kb_vendor-$kb_product-0"
    say "Caps Lock -> Control (internal keyboard $kb_id; applies after logout)"
    defaults -currentHost write -g "com.apple.keyboard.modifiermapping.$kb_id" -array \
        "<dict><key>HIDKeyboardModifierMappingSrc</key><integer>$CAPS_SRC</integer><key>HIDKeyboardModifierMappingDst</key><integer>$CTRL_DST</integer></dict>"
else
    say "Caps Lock -> Control: could not detect internal keyboard via ioreg - SKIPPED"
    say "  Set it manually: System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys"
fi

# Remove the old hidutil LaunchAgent from earlier versions of this script, so
# the two mechanisms don't both try to own the remap.
OLD_LA="$HOME/Library/LaunchAgents/com.smweber.capslock-to-control.plist"
if [[ -f "$OLD_LA" ]]; then
    launchctl bootout "gui/$(id -u)/com.smweber.capslock-to-control" 2>/dev/null || \
        launchctl unload "$OLD_LA" 2>/dev/null || true
    rm -f "$OLD_LA"
    say "Removed obsolete hidutil LaunchAgent ($OLD_LA)"
fi

# --- Custom keyboard shortcuts (symbolic hotkeys) ----------------------------
# VERIFY: these use com.apple.symbolichotkeys. Parameters are
# [ASCII, keyCode, modifierMask]; Option = 524288 (0x080000).
#   "[" -> ASCII 91,  keyCode 33      "]" -> ASCII 93, keyCode 30
#   "o" -> ASCII 111, keyCode 31
# Hotkey IDs: 79 = Move left a space, 81 = Move right a space,
#             32 = Mission Control.
set_hotkey() { # id ascii keycode modmask
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
        "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>$2</integer><integer>$3</integer><integer>$4</integer></array></dict></dict>"
}

say "Switch spaces: Option+[ (left) / Option+] (right)  [VERIFY]"
set_hotkey 79 91 33 524288
set_hotkey 81 93 30 524288

say "Mission Control: Option+O  [VERIFY]"
set_hotkey 32 111 31 524288

# ============================================================================
# Desktop / Dock / Stage Manager
# ============================================================================

say "Auto-hide the Dock"
defaults write com.apple.dock autohide -bool true

say "Click wallpaper to show desktop: only in Stage Manager"
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

say "Don't show desktop widgets  [VERIFY]"
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true

say "Don't rearrange Spaces based on most recent use"
defaults write com.apple.dock mru-spaces -bool false

say "Don't switch to a Space with open windows when switching apps"
defaults write com.apple.dock workspaces-auto-swoosh -bool false

# ============================================================================
# Trackpad
# ============================================================================
# Two multitouch domains cover built-in vs Bluetooth trackpads; write both.
BT=com.apple.driver.AppleBluetoothMultitouch.trackpad
MT=com.apple.AppleMultitouchTrackpad

say "Tracking speed ~60% (com.apple.trackpad.scaling = 1.5)"
defaults write -g com.apple.trackpad.scaling -float 1.5

say "Tap to click"
defaults write "$BT" Clicking -bool true
defaults write "$MT" Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1
defaults write -g com.apple.mouse.tapBehavior -int 1

# Gesture finger counts: 2 = enabled, 0 = disabled. Use four fingers for
# both "swipe between full-screen apps" (horizontal) and "Mission Control"
# (vertical up); disable the three-finger equivalents.
say "Swipe between full-screen apps: four fingers"
defaults write "$MT" TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write "$MT" TrackpadFourFingerHorizSwipeGesture  -int 2
defaults write "$BT" TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write "$BT" TrackpadFourFingerHorizSwipeGesture  -int 2

say "Mission Control: swipe up with four fingers"
defaults write "$MT" TrackpadThreeFingerVertSwipeGesture -int 0
defaults write "$MT" TrackpadFourFingerVertSwipeGesture  -int 2
defaults write "$BT" TrackpadThreeFingerVertSwipeGesture -int 0
defaults write "$BT" TrackpadFourFingerVertSwipeGesture  -int 2

# ============================================================================
# Other
# ============================================================================

say "Show battery percentage in the menu bar / Control Center"
defaults write com.apple.controlcenter BatteryShowPercentage -bool true

# ============================================================================
# Restart affected services so changes take effect without a full logout.
# ============================================================================
say "Restarting Dock / SystemUIServer / ControlCenter and reloading settings"
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
killall Dock          2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
killall ControlCenter  2>/dev/null || true

echo ""
echo "    macOS defaults applied. A logout/login is recommended so the"
echo "    Caps Lock remap, keyboard shortcuts, and trackpad gestures fully"
echo "    settle. Verify the settings marked [VERIFY] in System Settings."
