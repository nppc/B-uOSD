@SET AVRpath="C:\Program Files (x86)"\Atmel\Studio\7.0\toolchain\avr8\avrassembler\
@cd ..\VmOSD\VmOSD\
%AVRpath%\avrasm2.exe -o ../../Bin/B-uOSD_v2.hex -fI main.asm
@cd ..\..\Bin
pause