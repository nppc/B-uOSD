## fast routine with using T register (3 cycles per dot)
; at 9.6mhz, 10 cycles = 1us
; PAL visible dots in 51.9us (498 cycles) or 166 dots
; PAL visible lines - 576

.EQU sym_height = 11

.def	z0			=	r0
.def	z1			=	r1
.def	bcd			=	r2	; temp variable for BCD conversion
.def	tmp			=	r16
.def	tmp1		=	r17
.def	sym_line_nr	=	r19
.def	voltage		=	r20	; voltage in volts * 10 (dot will be printed in)


.DSEG
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff:	.BYTE 4

.CSEG
symbols:
sym0:	.DB 0b00100000	;0
		.DB 0b01110000
		.DB 0b11011000
		.DB 0b10001000
		.DB 0b10001000
		.DB 0b10001000
		.DB 0b10001000
		.DB 0b10001000
		.DB 0b11011000
		.DB 0b01110000
		.DB 0b00100000

sym1:	.DB 0b00100000	;1
		.DB 0b01100000
		.DB 0b11100000
		.DB 0b00100000
		.DB 0b00100000
		.DB 0b00100000
		.DB 0b00100000
		.DB 0b00100000
		.DB 0b00100000
		.DB 0b11111000
		.DB 0b11111000
		
symdot:	.DB 0b00000000	;10
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b10000000
		.DB 0b10000000
		.DB 0b10000000

symspc:	.DB 0b00000000	;11
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		.DB 0b00000000
		


		; ### beginning of the new page
		clr sym_line_nr
		; ### Beginning of the new line
		lds tmp, buff ; (first number to print)
		mov r18,tmp
		ldi ZH, high(symbols << 1)
		ldi ZL, low(symbols << 1)
		; go to right symbol - multiply R18 by 11 (sym_height)
		lsl r18	; mult by 2
		lsl r18	; mult by 4
		lsl r18	; mult by 8
		add r18, tmp
		add r18, tmp
		add r18, tmp
		
		add r18, sym_line_nr
		
		add ZL, r18
		adc ZH, z0
		; now we are at correct line of the symbol
		LPM r16, Z+
				
		;rcall PrintCharLine
		
		
		
PrintCharLine:
; r16 has bits for line of symbol
	clr r17

	bst r16,0		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	bst r16,1		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	bst r16,2		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	bst r16,3		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	bst r16,4		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	bst r16,5		;1
	bld r17,3		;1 (bit number of pin)
	out PortB, r17	;1

	nop
	nop
	out PortB,z0	;1 (clear last bit if was set)
	ret
	


	
; voltage is input parameter	
conv_num_bcd:
		ldi tmp, 11		; space
		sts buff, tmp	; clear leading 0 if needed		
		mov tmp, voltage	; number to convert
		ldi, tmp1, 100
		rcall conv_d_bcd
		cp bcd, z0	;	remove leading zero
		breq clear0
		sts buff, bcd
clear0:	ldi, tmp1, 10
		rcall conv_d_bcd
		sts buff+1, bcd
		sts buff+2, 10	; dot
		sts buff+3, tmp	; the rest of number
ret

	
conv_d_bcd:
		clr bcd
Lbcd:	cp tmp, tmp1
		brlo exitbcd
		inc bcd
		sub tmp, tmp1
		rjmp Lbcd
exitbcd:ret


		
		
	