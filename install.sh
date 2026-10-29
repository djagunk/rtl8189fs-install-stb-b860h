#!/usr/bin/env bash
# Install prebuilt RTL8189FS Wi-Fi module + register DKMS for the running ophub kernel.
# Run as root:  sudo /home/armbian/rtl8189fs-install/install.sh
set -euo pipefail

KVER="$(uname -r)"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KO_SRC="${HERE}/8189fs.ko"
SRC_DIR="${HERE}/driver-src"
DKMS_PKG="rtl8189fs"
DKMS_VER="5.7.9"
DKMS_SRC="/usr/src/${DKMS_PKG}-${DKMS_VER}"

[[ ${EUID} -eq 0 ]] || { echo "Run as root: sudo $0" >&2; exit 1; }

# 1) Install the prebuilt module so it loads immediately (no rebuild needed).
install -d -m 755 "/lib/modules/${KVER}/updates/dkms"
install -m 644 "${KO_SRC}" "/lib/modules/${KVER}/updates/dkms/8189fs.ko"

# 2) Register with DKMS so kernel updates rebuild it automatically.
if ! command -v dkms >/dev/null 2>&1; then
    echo "dkms not installed; skipping DKMS registration (module still installed)." >&2
else
    dkms remove -m "${DKMS_PKG}" -v "${DKMS_VER}" --all 2>/dev/null || true
    rm -rf "${DKMS_SRC}"
    install -d -m 755 "${DKMS_SRC}/driver"
    cp -a "${SRC_DIR}/." "${DKMS_SRC}/driver/"
    # dkms.conf points BUILT_MODULE_LOCATION at ./driver -> adjust MAKE path to local toolchain:
    cat > "${DKMS_SRC}/dkms.conf" <<EOF
PACKAGE_NAME="${DKMS_PKG}"
PACKAGE_VERSION="${DKMS_VER}"
BUILT_MODULE_NAME[0]="8189fs"
BUILT_MODULE_LOCATION[0]="driver"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
MAKE[0]='make -j2 -C driver ARCH=arm64 CROSS_COMPILE=/usr/local/toolchain/arm-gnu-toolchain-15.3.rel1-aarch64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- KVER=\${kernelver} KSRC=/lib/modules/\${kernelver}/build'
CLEAN="make -C driver clean"
EOF
    dkms add -m "${DKMS_PKG}" -v "${DKMS_VER}"
    dkms build -m "${DKMS_PKG}" -v "${DKMS_VER}" -k "${KVER}" || \
        echo "WARNING: dkms build failed (prebuilt module is still installed)." >&2
    dkms install -m "${DKMS_PKG}" -v "${DKMS_VER}" -k "${KVER}" --force 2>/dev/null || true
fi

# 3) Load on boot + sane module options (matches the stock Armbian 8189fs.conf).
echo "8189fs" > "/etc/modules-load.d/8189fs.conf"
echo "options 8189fs rtw_power_mgnt=0 rtw_enusbss=0" > "/etc/modprobe.d/8189fs.conf"

# 4) Refresh module deps and load now.
depmod -a "${KVER}"
modprobe 8189fs && echo "8189fs loaded."

echo
echo "=== interfaces ==="
ip -br link
echo
echo "=== dmesg (8189/wlan) ==="
dmesg | grep -iE "8189|rtw|wlan" | tail -15 || true
echo
echo "Done. If wlan0 did not appear, reboot and re-check: ip -br link"