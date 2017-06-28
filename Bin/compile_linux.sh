#!/bin/sh

cd ../VmOSD/VmOSD/
avra -D SYMBOL_NORMAL -D BITMAP_COPTER main.asm
mv main.hex ../../Bin/B-uOSD_NC_v12.hex
avra -D SYMBOL_NORMAL -D BITMAP_GOOGLES main.asm
mv main.hex ../../Bin/B-uOSD_NG_v12.hex
avra -D SYMBOL_DOUBLE -D BITMAP_COPTER main.asm
mv main.hex ../../Bin/B-uOSD_DC_v12.hex
avra -D SYMBOL_DOUBLE -D BITMAP_GOOGLES main.asm
mv main.hex ../../Bin/B-uOSD_DG_v12.hex
rm main.cof
rm main.eep.hex
rm main.obj

