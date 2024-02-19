#!/bin/bash

TAG="$(curl -s https://api.github.com/repos/tiann/KernelSU/releases/latest | jq -r '.tag_name')"

if [ -z "$TAG" ]; then
    echo "Vars are not set up properly!"
    exit 1
fi

KZIP="$(pwd)/Kernel"
cd ~
mkdir kernel; cd kernel
git config --global color.ui true
git config --global user.name henriqueiury5
git config --global user.email henriqueiury5m@gmail.com

n=''

echo "Starting KernelSU CI Builds ($TAG)"
today=$(date +%y%m%d)

branches=$(curl -s "https://api.github.com/repos/Gabriel2392/android_kernel_samsung_a53x_xy/branches" | jq -r '.[].name')

HOME="$(pwd)"
git clone https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r416183b "$HOME/clang-r416183b" --depth=1
git clone https://android.googlesource.com/platform/prebuilts/build-tools "$HOME/build-tools" --depth=1

export CROSS_COMPILE="$HOME/clang-r416183b/bin/aarch64-linux-gnu-"
export CC="$HOME/clang-r416183b/bin/clang"
export PLATFORM_VERSION=13
export ANDROID_MAJOR_VERSION=t
export PATH="$HOME/clang-r416183b/bin:$PATH"
export PATH="$HOME/build-tools/path/linux-x86:$PATH"
export TARGET_SOC=s5e8825
export LLVM=1 LLVM_IAS=1
export ARCH=arm64
EXTRA_FLAGS="LOCALVERSION=-KernelSU-${TAG}"

for branch in $branches; do
    rm -rf src
    git clone https://github.com/Gabriel2392/android_kernel_samsung_a53x_xy -b $branch --depth=1 src || continue
    cd src
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash - || continue
    kversion=$(awk -F= '/^VERSION =/ {v=$2} /^PATCHLEVEL =/ {p=$2} /^SUBLEVEL =/ {s=$2} END {gsub(/ /,"",v); gsub(/ /,"",p); gsub(/ /,"",s); print v"."p"."s}' Makefile | sort)
    echo "Building $kversion"
    make -j$(nproc --all) -C $(pwd) $EXTRA_FLAGS CROSS_COMPILE="$HOME/clang-r416183b/bin/aarch64-linux-gnu-" CC="$HOME/clang-r416183b/bin/clang" TARGET_SOC=s5e8825 LLVM=1 LLVM_IAS=1 ARCH=arm64 PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t KBUILD_BUILD_USER=Gabriel KBUILD_BUILD_HOST=KSUCI a53x_defconfig || continue
    make -j$(nproc --all) -C $(pwd) $EXTRA_FLAGS CROSS_COMPILE="$HOME/clang-r416183b/bin/aarch64-linux-gnu-" CC="$HOME/clang-r416183b/bin/clang" TARGET_SOC=s5e8825 LLVM=1 LLVM_IAS=1 ARCH=arm64 PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t KBUILD_BUILD_USER=Gabriel KBUILD_BUILD_HOST=KSUCI || continue
    cp "arch/arm64/boot/Image" "${KZIP}/Image"
    cd "$KZIP"
    zip -r "KernelSU_${TAG}-${kversion}.zip" ./
    # Remove the following line, as it sends the file to Telegram
    # tg_sendFile "KernelSU_${TAG}-${kversion}.zip" "KernelSU version: ${TAG}${n}Kernel version: ${kversion}${n}Branch: ${branch}" || tg_sendFile "KernelSU_${TAG}-${kversion}.zip" "KernelSU version: ${TAG}${n}Kernel version: ${kversion}${n}Branch: ${branch}" || exit 1
    rm -f Image "KernelSU_${TAG}-${kversion}.zip"
    cd "$KZIP"

# Adicione este bloco para criar uma release no GitHub
gh release create "v${TAG}-${kversion}" "${TAG}-${kversion}.zip" -t "Release v${TAG}-${kversion}" -n "Release Notes for v${TAG}-${kversion}" -R "Jacquesdemol/kernelsu_ci"

# Limpar arquivo temporário
rm -f "${TAG}-${kversion}.zip"
done
