#!/bin/sh
cd ../VmOSD/VmOSDV2/
avra main.asm
mv main.hex ../../Bin/B-uOSD_v2_debug.hex
rm main.cof
rm main.eep.hex
rm main.obj

