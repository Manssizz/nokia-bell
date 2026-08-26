# STATUS - what works, what doesn't, and why (PON in particular)

This document is the honest, verified state of PON support for the XG-040G-MD in
this repository. It was written after checking the live upstream sources
(ImmortalWrt master, and naoki66's XR1710G / XG2010G / airoha-xpon-luci repos),
not from memory. Read it before opening an issue about PON.

## TL;DR

- The **ImmortalWrt variant** is the one wired for PON. Build it with
  `.github/workflows/xg-040g-md-immortalwrt.yml`.
- The **PON physical layer works out of the box** on ImmortalWrt mainline - no
  custom kernel patches are required.
- The **airoha-xpon-luci management UI installs** (as a rootfs overlay).
- **Full GPON/EPON authentication (OMCI/OAM) is NOT guaranteed**, because it needs
  proprietary Airoha vendor userspace + kernel components that are not publicly
  available. If your ISP link comes up without those, great; if it needs OMCI/OAM
  authentication, you will need the vendor stack (see below).

## PON is three independent layers

Getting "PON working in the router" means all three of these must be present. They
are separate, and this repo can only provide the first two from public sources.

### Layer 1 - PCS / SerDes physical layer  ✅ (already in mainline)

The 2.5G/10G SerDes + PCS that drives the optical module. On ImmortalWrt master
this is already in the kernel and already enabled for this device:

- `target/linux/airoha/dts/an7581.dtsi` defines `pon_pcs` and `eth_pcs`
  (`compatible = "airoha,an7581-pcs-pon"` / `"airoha,an7581-pcs-eth"`).
- The `nokia_xg-040g-md` device (which the ImmortalWrt workflow builds) uses a DTS
  that enables them:

  ```dts
  &eth_pcs { status = "okay"; };
  &pon_pcs { status = "okay"; };
  ```

Because this lives in mainline, **no download of `310-09` / `310-10` PCS patches is
needed** for the ImmortalWrt build. (Earlier notes in this project that told you to
fetch those patches were wrong: the patch numbering upstream has changed and the
driver is already merged.)

### Layer 2 - management UI (airoha-xpon-luci)  ✅ (installed as an overlay)

`naoki66/airoha-xpon-luci` is the LuCI front-end for PON authentication and status
(LOID/SN/password, VLAN services, DDM optical readings, OMCI/OAM debug).

**It is not an OpenWrt package.** It ships no `Makefile` and has no
`CONFIG_PACKAGE_luci-app-airoha-xpon` symbol. It is a plain root filesystem overlay
whose files land under `/etc`, `/usr`, `/www`, `/lib`. This repo installs it the
correct way:

- `scripts/add-pon-overlay.sh` clones it and copies the rootfs dirs into
  `openwrt/files/`, which the image builder bakes into the firmware.
- The ImmortalWrt workflow runs that script (step: *Stage PON management overlay*).
- Because it is a Lua LuCI app, `config/xg-040g-md-immortalwrt.config` enables the
  Lua runtime deps it needs: `luci-lua-runtime`, `luci-compat`, `libuci-lua`,
  `liblua`.

### Layer 3 - vendor userspace + vendor kernel data path  ❌ (not public)

This is the missing piece for full authentication. The airoha-xpon-luci scripts
call the factory command ABI under `/userfs/bin`:

```
ponmgr  ponmgr_cfg  omci  omcicfgCmd  oamcfgCmd  xponblapicmd  xponigmpcmd  epon_oam
```

and depend on the proprietary XPON kernel data path:

```
xpon_int.ko  xpon_10g.ko  xponmap.ko  ponvlan.ko  gpon_flow.ko  /dev/pon  pon/oam interfaces
```

Per the project's own `docs/immortalwrt-vendor-tools.md`, on ImmortalWrt you need a
companion `airoha-xpon-vendor-tools` package to provide that command ABI, and that
package **does not** replace the vendor-only kernel modules. Those components are
not in mainline and are not published as a buildable source package, so **this
repository cannot bake them in**, and cannot promise end-to-end GPON/EPON auth.

## What you can realistically expect from a build of this repo

| Capability | State |
|------------|-------|
| Device builds and boots | ✅ |
| LAN/WAN, Wi-Fi-less routing, proxy apps (HomeProxy/PassWall) | ✅ |
| PON PCS/SerDes physical layer present in kernel | ✅ |
| airoha-xpon-luci UI visible in LuCI | ✅ (needs the Lua runtime, which is enabled) |
| PON link where the OLT needs no OMCI/OAM auth | ⚠️ may work |
| Full GPON/EPON authentication (OMCI/OAM, LOID/SN) | ❌ needs vendor stack (Layer 3) |

## If you need full, working PON today

The most reliable public base for this SoC family is the actively maintained fork
**`naoki66/ImmortalWrt-for-Gemtek-XG2010G`**. It already carries the
`nokia_xg-040g-md` device and is the upstream of the PCS/DTS work referenced here.
It is a better starting point than bolting overlays onto this repo if PON auth is
your priority. Even there, confirm how the vendor tools are provided for your unit
before assuming OMCI/OAM will authenticate.

## Verifying on-device after flashing

```sh
# PCS / PON physical layer recognized by the kernel
dmesg | grep -iE 'pcs|pon|serdes'

# Is the pon interface present?
ip link show | grep -i pon

# Did the LuCI overlay install? (menu appears under Services -> XPON)
ls /usr/lib/lua/luci/controller/xpon.lua
ls /usr/lib/lua/luci/view/xpon/

# Vendor tools present? (expected MISSING on a pure ImmortalWrt build)
ls -l /userfs/bin/ponmgr /userfs/bin/omcicfgCmd 2>/dev/null || echo "vendor tools not present (Layer 3 missing)"
```

## Sources checked (2026-08-26)

- `immortalwrt/immortalwrt` master: `target/linux/airoha/dts/an7581.dtsi`,
  `.../dts/an7581-nokia_xg-040g-md*.dts*`, `.../image/an7581.mk` - device +
  `pon_pcs`/`eth_pcs` present and enabled.
- `naoki66/ImmortalWrt-for-Gemtek-XR1710G` `patches-6.18/` - PCS/PON patches are
  already merged upstream; the old `310-10` name no longer exists.
- `naoki66/airoha-xpon-luci` (main) - confirmed overlay layout (no Makefile) and
  the vendor-tools dependency documented in `docs/immortalwrt-vendor-tools.md`.
- `naoki66/ImmortalWrt-for-Gemtek-XG2010G` master - carries `nokia_xg-040g-md`;
  its `DEVICE_PACKAGES` do not bundle the xpon UI or vendor tools by default.
