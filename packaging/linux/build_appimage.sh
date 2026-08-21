#!/usr/bin/env bash
# Packages the `flutter build linux --release` output into a portable
# Petal-x86_64.AppImage using appimagetool. Run from the repo root:
#   flutter build linux --release
#   bash packaging/linux/build_appimage.sh
#
# The raw `flutter build linux` output (build/linux/x64/release/bundle/) is
# already a runnable app on its own — this script is only needed if you
# specifically want a single-file portable .AppImage instead of a folder.
# For a .deb instead, `flutter_distributor` or `dpkg-deb` directly against
# the same bundle/ folder is the more common route — not scripted here since
# .deb metadata (maintainer, control file, dependencies) is genuinely
# project-specific and worth writing by hand rather than templating blind.
set -euo pipefail

APP_NAME="Petal"
BUNDLE_DIR="build/linux/x64/release/bundle"
APPDIR="build/linux/AppDir"
ICON_SRC="assets/icon/icon_square.png"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "error: $BUNDLE_DIR not found — run 'flutter build linux --release' first." >&2
  exit 1
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE_DIR"/* "$APPDIR/usr/bin/"
cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/512x512/apps/petal.png"
cp "$ICON_SRC" "$APPDIR/petal.png"

cat > "$APPDIR/usr/share/applications/petal.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=petal
Icon=petal
Categories=AudioVideo;Audio;Player;
Terminal=false
EOF
cp "$APPDIR/usr/share/applications/petal.desktop" "$APPDIR/petal.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/petal" "$@"
EOF
chmod +x "$APPDIR/AppRun"

if [ ! -x "appimagetool" ]; then
  echo "Downloading appimagetool..."
  curl -L -o appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x appimagetool
fi

# appimagetool is itself distributed as an AppImage, so running it normally
# needs FUSE to mount it — a real CI run failed here with "dlopen(): error
# loading libfuse.so.2 / AppImages require FUSE to run" because GitHub's
# ubuntu-latest runner image (Ubuntu 24.04) doesn't preinstall libfuse2
# (and the package itself was renamed to libfuse2t64 on 24.04, so even the
# commonly-cited `apt-get install libfuse2` fix no longer applies there).
# APPIMAGE_EXTRACT_AND_RUN sidesteps FUSE entirely — appimagetool
# self-extracts to a temp dir and runs from there instead of mounting —
# which also means this keeps working if a future ubuntu-latest bump
# changes the FUSE package situation again.
export APPIMAGE_EXTRACT_AND_RUN=1

./appimagetool "$APPDIR" "build/linux/${APP_NAME}-x86_64.AppImage"
echo "Built build/linux/${APP_NAME}-x86_64.AppImage"
