#!/bin/bash
set -eo pipefail

[[ $# -ge 1 ]] && shift 1
if [[ $# -ge 0 ]]; then
  armbian_extra_flags=("$@")
  echo "Passing additional args to Armbian ${armbian_extra_flags[*]}"
else
  armbian_extra_flags=("")
fi

C=$(pwd)
A=../armbian-rockchip64
B="current"
K="rockchip64"
T="nanopim4"

KERNELPATCH="no"
PATCH_PREFIX="xvolumio-"
KERNELCONFIGURE="no"


# Make sure we grab the right version
ARMBIAN_VERSION=$(cat ${A}/VERSION)
export INSTALL_MOD_STRIP=1

# Custom patches
echo "Adding custom patches"

mkdir -p "${A}"/userpatches/kernel/"${K}"-"${B}"/
rm -rf "${A}"/userpatches/kernel/"${K}"-"${B}"/*.patch
FILES="${C}"/patches/*.patch
shopt -s nullglob
for file in $FILES; do
  cp $file "${A}"/userpatches/kernel/"${K}"-"${B}"/
done

# Custom kernel Config
if [ -e "${C}"/kernel-config/linux-"${K}"-"${B}".config ]
then
  echo "Copy custom Kernel config"
  rm -rf  "${A}"/userpatches/linux-"${K}"-"${B}".config
  cp "${C}"/kernel-config/linux-"${K}"-"${B}".config "${A}"/userpatches/
fi

# Select specific Kernel and/or U-Boot version
rm -rf "${A}"/userpatches/lib.config
if [ -e "${C}"/kernel-ver/"${K}".config ]
then
  echo "Copy specific kernel/uboot version config"
  cp "${C}"/kernel-ver/"${K}"*.config "${A}"/userpatches/lib.config
fi

if [ -d "${A}"/output/debs ]; then
  echo "Cleaning previous .deb builds"
  rm "${A}"/output/debs/*
fi

cd ${A}
ARMBIAN_HASH=$(git rev-parse --short HEAD)
echo "Building for $T -- with Armbian ${ARMBIAN_VERSION} -- $B"

./compile.sh ARTIFACT_IGNORE_CACHE=yes BOARD=${T} BRANCH=${B} uboot 

if [ $KERNELPATCH == yes ]; then
  ./compile.sh ARTIFACT_IGNORE_CACHE=yes BOARD=${T2} BRANCH=${B} kernel-patch 
# Note: armbian patch files are applied in alphabetic order!!!
# To make sure that user patches are applied after Armbian's own patches, use a unique pre-fix"
  if [ -f "${A}"/output/patch/kernel-"${K}"-"${B}".patch ]; then
    cp "${A}"/output/patch/kernel-"${K}"-"${B}".patch "${C}"/patches/"${PATCH_PREFIX}"-kernel-"${K}"-"${B}".patch
    cp "${C}"/patches/"${PATCH_PREFIX}"-kernel-"${K}"-"${B}".patch "${A}"/userpatches/kernel/"${K}"-"${B}"/
    rm "${A}"/output/patch/kernel-"${K}"-"${B}".patch
  fi
fi

./compile.sh CLEAN_LEVEL=images,debs,make-kernel ARTIFACT_IGNORE_CACHE=yes BOARD=${T} BRANCH=${B} kernel

./compile.sh ARTIFACT_IGNORE_CACHE=yes BOARD=${T} BRANCH=${B} firmware 

echo "Done!"

cd "${C}"
echo "Creating platform ${T} files"
[[ -d ${T} ]] && rm -rf "${T}"
mkdir -p "${T}"/boot/overlay-user
mkdir -p "${T}"/lib/firmware
mkdir -p "${T}"/lib/systemd/system/
mkdir -p "${T}"/u-boot
mkdir -p "${T}"/var/lib/alsa

# Copy asound.state
if [ -f "${C}/audio-routing/${T}-asound.state" ]; then
  cp "${C}/audio-routing/${T}-asound.state" "${T}"/var/lib/alsa/asound.state
fi

# Keep a copy for later just in case
#cp "${A}/output/debs/linux-headers-${B}-${K}_${ARMBIAN_VERSION}"* "${C}"

echo "${A}/output/debs/linux-dtb-${B}-${K}_${ARMBIAN_VERSION}"*.deb
dpkg-deb -x "${A}/output/debs/linux-dtb-${B}-${K}_${ARMBIAN_VERSION}"*.deb "${T}"
echo "${A}/output/debs/linux-image-${B}-${K}_${ARMBIAN_VERSION}"*.deb
dpkg-deb -x "${A}/output/debs/linux-image-${B}-${K}_${ARMBIAN_VERSION}"*.deb "${T}"
echo "${A}/output/debs/linux-u-boot-${T}-${B}_${ARMBIAN_VERSION}"*.deb
dpkg-deb -x "${A}/output/debs/linux-u-boot-${T}-${B}_${ARMBIAN_VERSION}"*.deb "${T}"
echo "${A}/output/debs/armbian-firmware_${ARMBIAN_VERSION}"*.deb
dpkg-deb -x "${A}/output/debs/armbian-firmware_${ARMBIAN_VERSION}"*.deb "${T}"
echo "Remove unused firmware"
rm -r "${T}"/lib/firmware/qcom
rm "${T}"/lib/firmware/dvb*


cp "${T}"/usr/lib/linux-u-boot-${B}-${T}/* "${T}/u-boot/"
cp "${T}"/usr/lib/u-boot/platform_install.sh "${T}/u-boot/"

mv "${T}"/boot/dtb* "${T}"/boot/dtb
mv "${T}"/boot/vmlinuz* "${T}"/boot/Image

# Copy any additional firmware
cp -r "${C}"/firmware "${T}"/lib

echo "Add 'brcmfmac43456-sdio.friendlyarm,nanopim4' smlinks" 
ln -s "${T}"/lib/firmware/brcm/brcmfmac43456-sdio.bin "${T}"/lib/firmware/brcm/brcmfmac43456-sdio.friendlyarm,nanopi4.bin 
ln -s "${T}"/lib/firmware/brcm/brcmfmac43456-sdio.txt "${T}"/lib/firmware/brcm/brcmfmac43456-sdio.friendlyarm,nanopi4.txt 

# Add additional services
# Bluetooth for most of others (custom patchram is needed only in legacy)
cp "${A}"/packages/bsp/rk3399/brcm_patchram_plus_rk3399 "${T}"/usr/bin
cp "${A}"/packages/bsp/rk3399/rk3399-bluetooth.service "${T}"/lib/systemd/system/

# Clean up unneeded parts
rm -rf "${T}/lib/firmware/.git"
rm -rf "${T:?}/usr" "${T:?}/etc"

# Compile and copy over overlay(s) files
for dts in "${C}"/overlay-user/overlays-"${T}"/*.dts; do
  dts_file=${dts%%.*}
  if [ -s "${dts_file}.dts" ]
  then
    echo "Compiling ${dts_file}"
    dtc -O dtb -o "${dts_file}.dtbo" "${dts_file}.dts"
    cp "${dts_file}.dtbo" "${T}"/boot/overlay-user
  fi
done

# Copy and compile boot script
if [ -f "${C}"/bootparams/boot-"${T}".cmd ]; then
  cp "${C}"/bootparams/boot-"${T}".cmd "${T}"/boot/boot.cmd
else
  cp "${A}"/config/bootscripts/boot-"${K}".cmd "${T}"/boot/boot.cmd
fi
mkimage -C none -A arm -T script -d "${T}"/boot/boot.cmd "${T}"/boot/boot.scr

# Signal mainline kernel
touch "${T}"/boot/.next

# Prepare boot parameters
cp "${C}"/bootparams/armbianEnv-"${T}".txt "${T}"/boot/armbianEnv.txt


# Signal mainline kernel
touch "${T}"/boot/.next

# Prepare boot parameters
ls 
cp "${C}"/bootparams/armbianEnv-"${T}".txt "${T}"/boot/armbianEnv.txt

echo "Creating device tarball.."
tar cJf "${T}_${B}.tar.xz" "$T"

echo "Renaming tarball for Build scripts to pick things up"
mv "${T}_${B}.tar.xz" "${T}.tar.xz"
KERNEL_VERSION="$(basename ./"${T}"/boot/config-*)"
KERNEL_VERSION=${KERNEL_VERSION#*-}
echo "Creating a version file Kernel: ${KERNEL_VERSION}"
cat <<EOF >"${C}/version"
BUILD_DATE=$(date +"%m-%d-%Y")
ARMBIAN_VERSION=${ARMBIAN_VERSION}
ARMBIAN_HASH=${ARMBIAN_HASH}
KERNEL_VERSION=${KERNEL_VERSION}
EOF

echo "Cleaning up.."
rm -rf "${T}"
