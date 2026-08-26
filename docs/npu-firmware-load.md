# XG-040G-MD (AN7581) NPU firmware load error: analysis and fix notes

## Symptom

The boot log shows the NPU firmware failing to load (`-2` usually maps to `ENOENT`):

```text
airoha-npu 1e900000.npu: Direct firmware load for airoha/en7581_npu_rv32.bin failed with error -2
```

At the same time the firmware package may already show as "installed" in the system, and the firmware file does exist (for example under the read-only `/rom/lib/firmware/...`).

## Things to confirm on-device

1. The system is a SNAPSHOT build whose package manager is `apk` (not `opkg`), so "installed / present in rootfs" does not necessarily mean "readable at driver probe time".
2. The firmware file usually lives at:
   - `/rom/lib/firmware/airoha/en7581_npu_rv32.bin` (squashfs read-only root)
   - or `/lib/firmware/airoha/en7581_npu_rv32.bin` (overlay)

## Root cause

On this platform, if the NPU / Ethernet drivers are **built-in**, they can probe very early in boot and call `request_firmware()`.

OpenWrt typically disables the firmware loader's user-helper fallback (for security), for example:

```text
# CONFIG_FW_LOADER_USER_HELPER is not set
# CONFIG_FW_LOADER_USER_HELPER_FALLBACK is not set
```

If, at the moment the driver probes, the rootfs/firmware path is not yet ready, `request_firmware()` returns `-2` and produces the error above. Even after the rootfs is later mounted, the driver may not automatically retry the load.

Conclusion: this is not simply "the firmware package is missing / the file does not exist". It is more like a combination of **probing too early + no user-helper fallback + firmware living on the rootfs**.

## Fix options

Possible directions (in recommended order):

1. Recommended: build the relevant drivers as **kmod modules** so OpenWrt loads them after the system is up, ensuring the firmware path is available.
2. Not recommended: enable `FW_LOADER_USER_HELPER(_FALLBACK)` or introduce a userspace helper (security/policy concerns; usually not accepted upstream in OpenWrt).
3. Other: embed the firmware into initramfs or into the driver itself (higher maintenance cost).

This project uses option 1.

## Changes made (fork branch)

The changes live in the user's fork: `xiangtailiang/openwrt`, branch `xg040gmd-fixes`.

### 1) Ship the NPU firmware in the image and drop the pointless AFE error

Goals:
- Get `airoha/en7581_npu_rv32.bin` baked into the image (rootfs).
- When `an7581-audio ... probe ... -2` is just noise, disable that board's AFE node.

Corresponding commit:
- `ebcb80714c` `airoha: an7581: bell xg-040g-md: add NPU firmware, disable AFE`

Key file-level changes:
- `target/linux/airoha/image/an7581.mk`: `Device/bell_xg-040g-md` gains `DEVICE_PACKAGES += airoha-en7581-npu-firmware`
- `target/linux/airoha/dts/an7581-bell_xg-040g-md.dts`: add `&afe { status = "disabled"; };`

### 2) Ship the Airoha ETH/NPU drivers as kmods so early probe does not miss the firmware

Goals:
- Change `CONFIG_NET_AIROHA*` from built-in to modules.
- Introduce `kmod-airoha-npu` / `kmod-airoha-eth` with autoload so they load after the system is up.
- Add those kmods to the target's default packages.

Corresponding commit:
- `7c9ed7ad41` `airoha: an7581: ship airoha-eth/npu as kmods`

Key file-level changes:
- `target/linux/airoha/an7581/config-6.12`:
  - `CONFIG_NET_AIROHA=m`
  - `CONFIG_NET_AIROHA_NPU=m`
- `package/kernel/linux/modules/netdevices.mk`:
  - add `KernelPackage/airoha-npu` -> `kmod-airoha-npu` (autoload priority 18)
  - add `KernelPackage/airoha-eth` -> `kmod-airoha-eth` (autoload priority 19, depends on `+kmod-airoha-npu`)
- `target/linux/airoha/an7581/target.mk`:
  - add `kmod-airoha-eth kmod-airoha-npu` to the default packages (alongside the existing firmware package)

## Verification (after flashing)

On the device, confirm the firmware exists, the modules are loaded, and dmesg no longer shows `-2`:

```sh
# Firmware file
ls -l /rom/lib/firmware/airoha/en7581_npu_rv32.bin 2>/dev/null || true
ls -l /lib/firmware/airoha/en7581_npu_rv32.bin 2>/dev/null || true

# Are the modules loaded?
lsmod | grep -E 'airoha|npu' || true

# Inspect the boot log
dmesg | grep -nE 'airoha-npu|en7581_npu' || true
```

If you need to trigger a re-probe manually (for debugging):

```sh
echo 1e900000.npu > /sys/bus/platform/drivers/airoha-npu/unbind
sleep 1
echo 1e900000.npu > /sys/bus/platform/drivers/airoha-npu/bind
dmesg | tail -n 80
```

## Notes

- "LuCI shows the firmware package as installed" only means the file is present in the rootfs; it does not guarantee the filesystem was ready at the exact moment the driver probed.
- This document only covers the NPU firmware load error and its fix. NAT performance / CPU saturation (IRQ/RPS/flow offload, etc.) is a separate investigation.
