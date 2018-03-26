#!/bin/sh
cd ../VmOSD/VmOSD/
avra main.asm
mv main.hex ../../Bin/B-uOSD_v1.hex
rm main.cof
rm main.eep.hex
rm main.obj

