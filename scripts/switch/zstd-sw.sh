#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:/opt/devkitpro/tools/bin:$PATH
export DEVKITPRO=/opt/devkitpro
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build
curl -L --retry 3 -m 240 -o zstd.tar.gz https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-1.5.6.tar.gz && tar xzf zstd.tar.gz
cd zstd-1.5.6/lib
CC=$DEVKITPRO/devkitA64/bin/aarch64-none-elf-gcc.exe
AR=$DEVKITPRO/devkitA64/bin/aarch64-none-elf-gcc-ar.exe
mkdir -p ../o && rm -f ../o/*.o
for f in common/*.c compress/*.c decompress/*.c; do
  $CC -O2 -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIC -ffunction-sections -fdata-sections -D__SWITCH__ -DZSTD_MULTITHREAD=0 -DZSTD_DISABLE_ASM=1 -DXXH_NAMESPACE=ZSTD_ -I. -Icommon -c $f -o ../o/$(basename $f .c).o || exit 1
done
P=$DEVKITPRO/portlibs/switch
$AR rcs $P/lib/libzstd.a ../o/*.o && cp zstd.h zstd_errors.h $P/include/
ls -l $P/lib/libzstd.a
echo ZSTD_DONE