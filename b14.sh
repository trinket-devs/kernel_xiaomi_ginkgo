#!/bin/bash
#
# Compile script for ginkgo kernel
# Copyright (C) 2020-2021 Adithya R.

# Setup environment
TC_DIR="$HOME/tc/azure-clang"
AK3_DIR="$HOME/tc/AnyKernel3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
SECONDS=0 # builtin bash timer
ZIPNAME="Ryzen-Unified-ginkgo-$(date '+%Y%m%d-%H%M').zip"

export PATH="$TC_DIR/bin:$PATH" 
#export KBUILD_BUILD_USER=adithya
#export KBUILD_BUILD_HOST=ghostrider_reborn
#export LD_LIBRARY_PATH="$TC_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_COMPILER_STRING="$($TC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"

# Check if toolchain is exist
if ! [ -d "$TC_DIR" ]; then
		echo "Proton clang not found! Cloning to $TC_DIR..."
		if ! git clone -q --single-branch --depth 1 -b main https://gitlab.com/Panchajanya1999/azure-clang $TC_DIR; then
				echo "Cloning failed! Aborting..."
				exit 1
		fi
fi

# Delete old file before build
if [[ $1 = "-c" || $1 = "--clean" ]]; then
		rm -rf out
fi

# Make out folder
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

# Regened defconfig
if [[ $1 == "-r" || $1 == "--regen" ]]; then
		   cp out/.config arch/arm64/configs/$DEFCONFIG
		   echo -e "\nRegened defconfig succesfully!"
		   exit 0
else
		echo -e "\nStarting compilation...\n"
		make -j15 O=out ARCH=arm64 \
		CC=clang \
		LD=ld.lld \
		AR=llvm-ar \
		AS=llvm-as \
		NM=llvm-nm \
		OBJCOPY=llvm-objcopy \
		OBJDUMP=llvm-objdump \
		STRIP=llvm-strip \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE=aarch64-linux-gnu- \
		CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb dtbo.img
fi

# Creating zip flashable file
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
		 echo -e "\nKernel compiled succesfully! Zipping up...\n"

		# Check if AK3 exist	
		if ! [ -d "$AK3_DIR" ]; then
				echo "$AK3_DIR not found! Cloning to $AK3_DIR..."
				if ! git clone -q --single-branch --depth 1 -b master https://github.com/aryaman895/AnyKernel3 $AK3_DIR; then
						echo "Cloning failed! Aborting..."
						exit 1
				fi
		fi

		#Copy AK3 to out/Anykernel13
		cp -r $AK3_DIR AnyKernel3
		cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
		cp out/arch/arm64/boot/dtbo.img AnyKernel3

		# Change dir to AK3 to make zip kernel
		cd AnyKernel3
		zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder

		#Back to out folder and clean
		cd ..
		rm -rf AnyKernel3
		rm -rf out/arch/arm64/boot
		echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
		echo "Zip: $ZIPNAME"
		if ! [[ $HOSTNAME = "RyzenBeast" && $USER = "adithya" ]]; then
				curl --upload-file $ZIPNAME http://transfer.sh/$ZIPNAME; echo
		fi
else
		echo -e "\nUpload failed!"
fi
