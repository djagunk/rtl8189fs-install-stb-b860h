# RTL8189FS Wi-Fi — ZTE B860H (Amlogic S905X, Armbian/ophub, kernel 6.12.109-ophub)

Chip Wi-Fi: **Realtek RTL8189FS** (SDIO `024c:f179`, root node OPhub `/soc/apb@d0000000/mmc@70000/wifi@1`).
Kernel ophub tidak meng-compile `rtl8189fs`, jadi `wlan0` tidak pernah muncul. Paket ini sudah
berisi modul yang **sudah terkompilasi untuk kernel yang berjalan** + driver source yang sudah dipatch.

## Isi
- `8189fs.ko`      — modul jadi (vermagic `6.12.109-ophub ... aarch64`, alias `sdio:c*v024CdF179*`)
- `driver-src/`    — sumber driver (sudah dipatch untuk kernel ini)
- `install.sh`     — installer (butuh root)
- `dkms.conf`      — referensi

## Cara pasang (butuh root)
```bash
sudo /home/armbian/rtl8189fs-install/install.sh
```
Script akan:
1. menaruh `8189fs.ko` di `/lib/modules/6.12.109-ophub/updates/dkms/`
2. mendaftarkan DKMS agar build ulang otomatis saat kernel update
3. menulis `/etc/modules-load.d/8189fs.conf` + `/etc/modprobe.d/8189fs.conf`
4. `depmod -a`, `modprobe 8189fs`, lalu menampilkan `ip -br link` dan dmesg

Cek hasil: `ip -br link` harus memunculkan `wlan0`. Kalau belum: `sudo reboot`.

Scan & konek (NetworkManager):
```bash
nmcli device wifi list
sudo nmcli device wifi connect "SSID" password "PASSWORD"
```

## Catatan penting — build dari sumber (DKMS)
`dkms.conf` menunjuk toolchain di `/usr/local/toolchain/arm-gnu-toolchain-15.3.rel1-aarch64-aarch64-none-linux-gnu`.
Kernel ophub dibangun dengan **ARM GNU Toolchain 15.3** dan butuh flag `-fmin-function-alignment=4`
yang **tidak ada di gcc 12** (gcc default Armbian). Tanpa toolchain itu, build gagal:
`gcc: error: unrecognized command-line option '-fmin-function-alignment=4'`.

Kalau toolchain belum ada, salin dari cache hasil build:
```bash
sudo mkdir -p /usr/local/toolchain
sudo cp -a /home/armbian/.hermes/cache/scratch/tcroot/arm-gnu-toolchain-15.3.rel1-aarch64-aarch64-none-linux-gnu /usr/local/toolchain/
```
(atau unduh: https://github.com/ophub/kernel/releases/download/toolchain/arm-gnu-toolchain-15.3.rel1-aarch64-aarch64-none-linux-gnu.tar.xz )

## Dua patch yang diperlukan (sudah diterapkan di driver-src)
1. `os_dep/linux/ioctl_cfg80211.c` — `set_monitor_channel` dapat parameter `struct net_device *dev`
   sejak kernel 6.9 (header ophub 6.12 sudah 3-arg), tapi driver hanya menambahnya untuk `>= 6.13`.
   Diubah guard `KERNEL_VERSION(6,13,0)` -> `KERNEL_VERSION(6,12,0)`.
2. `modpost` bawaan `/usr/src/linux-headers-6.12.109-ophub/scripts/mod/modpost` dibangun untuk
   glibc 2.38; OS ini bookworm (glibc 2.36) -> `version GLIBC_2.38 not found`. Solusi: build ulang
   `modpost` dari source headers dengan gcc host:
   ```bash
   gcc -O2 -std=gnu11 -o modpost scripts/mod/{modpost,file2alias,sumversion,symsearch}.c \
       -I scripts/mod -I scripts/include
   ```
   lalu timpa `scripts/mod/modpost` dan bangun modul dengan `KSRC=<salinan headers yang writable>`.

## Rebuild modul (manual, tanpa DKMS)
```bash
TC=/usr/local/toolchain/arm-gnu-toolchain-15.3.rel1-aarch64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
cd driver-src
make ARCH=arm64 CROSS_COMPILE=$TC KVER=$(uname -r) KSRC=<writable-headers-copy> -j3
```# rtl8189fs-install-stb-b860h
# rtl8189fs-install-stb-b860h
