# CHANGES - PON integration + English translation + fixes

This is the diff-in-words between the original repo and this build-ready version.
Everything was verified against live upstream sources on 2026-08-26 (see
`STATUS.md` for the source list). Bugs from earlier drafts were corrected here.

## Bugs fixed (from the earlier, incorrect PON notes)

1. **Removed the bogus PCS patch download.** Earlier guidance told you to fetch
   `310-09` / `310-10` "PCS/SerDes" patches from `naoki66/…XR1710G`. That was wrong:
   the PCS/PON driver is already merged in ImmortalWrt mainline and the `310-10`
   patch name no longer exists upstream. The ImmortalWrt build needs no such patch.

2. **Fixed the "package" mistake.** Earlier guidance said to `git clone
   airoha-xpon-luci` into `package/` and add `CONFIG_PACKAGE_luci-app-airoha-xpon=y`.
   That package symbol does not exist - airoha-xpon-luci has no Makefile and is a
   rootfs overlay, so that line would have been silently dropped by `make defconfig`
   and nothing would install. It is now staged the correct way, into `files/`.

3. **Fixed the invented device-tree node.** Earlier guidance added
   `&pon_pcs { media = "fiber"; speed = "10g"; };`. Those properties are not part of
   the binding. The real node is just `&pon_pcs { status = "okay"; };`, and it is
   already enabled on the mainline `nokia_xg-040g-md` device - so no DTS edit is
   needed for the ImmortalWrt build at all.

## Files added

- `scripts/add-pon-overlay.sh` - clones `naoki66/airoha-xpon-luci` and stages its
  rootfs dirs (`etc`, `usr`, `www`, `lib`) into `<buildroot>/files/`. Marks helper
  and init scripts executable. Skips repo cruft (docs, tools, .github).
- `STATUS.md` - honest breakdown of the three PON layers and what this repo can and
  cannot provide (Layer 3 / vendor stack is not public).
- `patch/README.md` - clarifies that `patch/` files are reference-only and are not
  applied by any workflow.
- `CHANGES.md` - this file.

## Files modified

- `.github/workflows/xg-040g-md-immortalwrt.yml`
  - New step **"Stage PON management overlay (airoha-xpon-luci)"** runs
    `add-pon-overlay.sh` against the ImmortalWrt buildroot before `make defconfig`.
  - Release notes translated to English and annotated with the PON caveat.
- `config/xg-040g-md-immortalwrt.config`
  - Appended the real Lua-runtime dependencies the overlay needs:
    `luci-lua-runtime`, `luci-compat`, `libuci-lua`, `liblua`.
    (Verified these package symbols exist upstream.)
- `scripts/update-packages.sh` - all comments translated to English (logic
  unchanged).
- `.github/workflows/xg-040g-md-openwrt-main.yml`,
  `.github/workflows/xg-040g-md-openwrt-25.12.yml` - release notes translated to
  English. (These two build the `xiangtailiang/openwrt` fork device
  `nokia_xg-040g-md-tcboot`; PON overlay is intentionally only wired into the
  ImmortalWrt variant, whose mainline device ships the PCS layer.)
- `config/xg-040g-md.config` - inline comments translated to English.
- `README.md` - rewritten in English, with a PON support section pointing to
  `STATUS.md`.
- `docs/npu-firmware-load.md` - translated to English.

## How to build (ImmortalWrt variant, the PON one)

1. Push this repo to GitHub (or run locally with an ImmortalWrt buildroot).
2. Trigger the **Build_XG_040G_MD_ImmortalWrt** workflow (Actions -> Run workflow),
   or push a change under `config/` or `scripts/` to trigger it.
3. The workflow clones ImmortalWrt master, installs third-party packages, stages the
   PON overlay into `files/`, applies `config/xg-040g-md-immortalwrt.config`, and
   builds `nokia_xg-040g-md`.
4. Flash the resulting factory image (see README). Then read the verification
   section in `STATUS.md`.

## Honest expectation

You get a bootable image with the PON PCS physical layer and the airoha-xpon-luci
UI. Whether the PON link fully authenticates depends on the proprietary Airoha
vendor stack (Layer 3 in `STATUS.md`), which is not public and cannot be bundled
from source here. If PON auth is the goal, `naoki66/ImmortalWrt-for-Gemtek-XG2010G`
is the more complete base for this device family.
