# patch/ - reference material only (NOT applied by the build)

The files in this directory are **reference copies** of the device-support work
that was upstreamed into the `xiangtailiang/openwrt` fork. **None of the CI
workflows in this repository copy or apply them.** They are kept for provenance
and for anyone who wants to read how the board was brought up.

| File | What it is | Where it actually lives now |
|------|------------|-----------------------------|
| `an7581-bell_xg-040g-md.dts` | Original `bell,xg-040g-md` device tree | Upstreamed to the OpenWrt source tree; the ImmortalWrt build uses the mainline `nokia_xg-040g-md` DTS instead |
| `an7581.mk` | Image/build target definition | Upstreamed to `target/linux/airoha/image/an7581.mk` |
| `600-mtd-spinand-add-skyhigh-robust-read-workaround.patch` | SkyHigh SPI-NAND robust-read workaround | Upstreamed as a kernel patch |
| `02_network` | Default network UCI defaults | Upstreamed to the device profile |

## Important for PON

Do **not** try to enable PON by editing `an7581-bell_xg-040g-md.dts` here - it is
never compiled by the build. On the ImmortalWrt variant, the device that is
actually built is `nokia_xg-040g-md`, whose device tree already lives in
ImmortalWrt mainline and already enables the PON PCS layer:

```dts
&eth_pcs { status = "okay"; };
&pon_pcs { status = "okay"; };
```

See `../STATUS.md` for the full PON picture.
