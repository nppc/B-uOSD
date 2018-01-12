@SET AVRpath="C:\Program Files (x86)"\Atmel\Studio\7.0\toolchain\avr8\avrassembler\
@cd ..\VmOSD\VmOSDV2\
%AVRpath%\avrasm2.exe -o ../../Bin/B-uOSD_v2_debug.hex -fI main.asm
@cd ..\..\Bin
pause