@SET AVRpath="C:\Program Files (x86)"\Atmel\Studio\7.0\toolchain\avr8\avrassembler\
@cd ..\VmOSD\VmOSD\
%AVRpath%\avrasm2.exe -D SYMBOL_NORMAL -D BITMAP_COPTER -o ../../Bin/B-uOSD_NC_v12.hex -fI main.asm
%AVRpath%\avrasm2.exe -D SYMBOL_NORMAL -D BITMAP_GOOGLES -o ../../Bin/B-uOSD_NG_v12.hex -fI main.asm
%AVRpath%\avrasm2.exe -D SYMBOL_DOUBLE -D BITMAP_COPTER -o ../../Bin/B-uOSD_DC_v12.hex -fI main.asm
%AVRpath%\avrasm2.exe -D SYMBOL_DOUBLE -D BITMAP_GOOGLES -o ../../Bin/B-uOSD_DG_v12.hex -fI main.asm
@cd ..\..\Bin