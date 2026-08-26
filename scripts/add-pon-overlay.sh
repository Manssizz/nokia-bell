#!/bin/bash
#
# add-pon-overlay.sh
#
# Stage the naoki66/airoha-xpon-luci LuCI application into the OpenWrt/ImmortalWrt
# build tree as a root filesystem overlay (the "files/" mechanism).
#
# IMPORTANT: airoha-xpon-luci is NOT an OpenWrt package. It ships no Makefile and
# is not selectable via CONFIG_PACKAGE_*. It is a plain rootfs overlay whose files
# live under /etc, /usr, /www and /lib on the running device. Therefore we copy it
# into <buildroot>/files/ so the image builder bakes it into the firmware.
#
# This script must be run from the OpenWrt/ImmortalWrt build root (the directory
# that contains the top-level "package/", "target/" and ".config").
#
# Usage:
#   bash add-pon-overlay.sh [BUILD_ROOT]
#
# If BUILD_ROOT is omitted, the current directory is used.
#
# What full PON needs to actually work (read STATUS.md):
#   1. Kernel PCS / SerDes physical layer  -> already in ImmortalWrt mainline
#      (an7581.dtsi provides &pon_pcs / &eth_pcs with the airoha,an7581-pcs-pon
#       driver, and the nokia_xg-040g-md device enables them).
#   2. This LuCI overlay                    -> installed by this script.
#   3. Vendor userspace tools (ponmgr, omcicfgCmd, epon_oam, ...) and the
#      proprietary XPON kernel data path (xpon_int.ko, ponvlan.ko, /dev/pon, the
#      "pon"/"oam" interfaces) -> NOT public. The UI installs and the physical
#      layer works, but GPON/EPON authentication (OMCI/OAM) requires those
#      vendor components. See STATUS.md.

set -euo pipefail

BUILD_ROOT="${1:-$PWD}"
XPON_REPO="https://github.com/naoki66/airoha-xpon-luci.git"
XPON_BRANCH="main"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "=========================================="
echo "Staging airoha-xpon-luci rootfs overlay"
echo "  build root : $BUILD_ROOT"
echo "  source     : $XPON_REPO ($XPON_BRANCH)"
echo "=========================================="

if [ ! -d "$BUILD_ROOT" ]; then
	echo "ERROR: build root not found: $BUILD_ROOT"
	exit 1
fi

git clone --depth=1 --single-branch --branch "$XPON_BRANCH" "$XPON_REPO" "$TMP_DIR/airoha-xpon-luci"

SRC="$TMP_DIR/airoha-xpon-luci"
DEST="$BUILD_ROOT/files"
mkdir -p "$DEST"

# Copy ONLY the rootfs-relevant directories. Everything else in the repo
# (docs/, tools/, README.md, opensearch.xml, .github/, .git/) must NOT end up
# in the firmware image.
for d in etc usr www lib; do
	if [ -d "$SRC/$d" ]; then
		echo "  overlay: /$d"
		cp -a "$SRC/$d" "$DEST/"
	fi
done

# Make sure helper scripts and init scripts are executable.
find "$DEST/usr/bin" "$DEST/usr/libexec" "$DEST/etc/init.d" \
	"$DEST/etc/uci-defaults" "$DEST/etc/hotplug.d" "$DEST/lib/preinit" \
	-type f 2>/dev/null | while read -r f; do
	chmod +x "$f" || true
done

if [ -f "$SRC/etc/xpon-luci.version" ]; then
	echo "  installed xpon-luci version:"
	head -n1 "$SRC/etc/xpon-luci.version" | sed 's/^/    /'
fi

echo "Overlay staged into: $DEST"
echo "Done."
