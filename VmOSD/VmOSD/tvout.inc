; * Author of B-uOSD is Pavel Palonen
; *
; * B-uOSD is free software: you can redistribute it and/or modify
; * it under the terms of the GNU General Public License as published by
; * the Free Software Foundation, either version 3 of the License, or
; * (at your option) any later version.
; *
; * B-uOSD is distributed WITHOUT ANY WARRANTY; without even the implied warranty of
; * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; * GNU General Public License for more details.
; * this text shall be included in all
; * copies or substantial portions of the Software.
; *
; * You should have received a copy of the GNU General Public License
; * along with Cleanflight.  If not, see <http://www.gnu.org/licenses/>.


; this routine is called from interrupts, so use interrupt registers
; tmp2 contains bcd number
; Convert Char number to address
conv_bcd_to_address:		
		; use XH register just because it is free 
		ldi XH, low(symbols << 1)	; we need only low address byte, because fonts are at the beginning of the flash
mult1:	subi XH, -SYM_HEIGHT	; XH=XH+10
		dec	itmp2
		brne mult1
		mov itmp2, XH	; return value
		ret

; short way for brne commands and also resets sym_line_nr for proper printing of 2 voltages
pcint_exit1:
		clr sym_line_nr	; Reset printing counter. Start printing from the first line of symbol bitmap
		mov sym_H_cntr, sym_H_strch	; reset counter for symbol stretch
		rjmp pcint_exit		

; Here we come every time when Horizontal sync is came.
; Per Datasheet it is good to use leading edge of the signal (falling)
; we come here only when new TV line is started. 
; So, we need to check VSOUT pin here to see, when new page will begin
; HSOUT: -----+_+-----+_+-----+_+-----+_+-----+_+-----+_+
; VSOUT: ---------------------+___________________+------
EXT_INT0:
		in r_sreg, SREG
		; OK check VSOUT pin is LOW (New Page)
		; OK if no, then 
		; OK	increment line counter
		; OK	(timing for printing data should be very precise)
		; OK	if line number < line where data starts, then exit
		; OK	if line number > totl lines to print, then exit 
		; OK	Print OSD
		; OK if yes, then
		; OK initialize for new page (lines counter, fill sram with address of printed symbols...)
		; OK exit
		sbis PINB, VSOUT_PIN
		rjmp vsout_newpage
		; first voltage is double stretched
		ldi sym_H_strch, SYMBOL_STRETCH	; Double stretch
		; HSOUT horisontal line routine
		adiw TV_lineH:TV_lineL, 1	; inc TV_lineL:TV_lineH
		; preload delay value for horizontal positioning
		lds	itmp, TV_col_start
		; check current line number (we are using YH:YL just for sake of use adiw next)
		ldi XL, low(buff_addr1)	; By default - first voltage to print
		clr XH
		lds YL, TV_line_start
		lds YH, TV_line_start+1
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brlo pcint_exit1			; not needed to print yet
		; calculate last line to print
		adiw YH:YL, SYM_HEIGHT * SYMBOL_STRETCH	; double height symbols
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brlo printing		; printing...
		; first voltage is printed
#if defined(ENABLE_MINVOLT)
		; check for the second voltage
		ldi sym_H_strch, 1		; no stretch
		adiw YH:YL, 10	; vertical space between voltages
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brlo pcint_exit1			; not needed to print yet
		; calculate last line to print
		adiw YH:YL, SYM_HEIGHT ; normal height symbols
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brsh pcint_exit1		; printing is finished
		ldi XL, low(buff_addr2)	; we need to print second voltage
		subi itmp, 4	; adjust delay for proper horizontal position of second voltage
#else
		; No need to print second line
		rjmp pcint_exit1
#endif
printing:		
		;  printing...
		; We will not use first 15us of the HLine. And we can't because of code running at the beginning every line :)
		; Only about 41us of Line is 100% visible on screen.

		; Delay to set horizontal position of the text
		; 10 iterations of this loop is about 3us at 9.6 mhz.
tmrcpl1:dec	itmp
		brne tmrcpl1
		
		; prepare data for printing
		; fill data buffer with printed line of bits
		; current line number in sym_line_nr
		; buff_addr1 and 2 contains addresses of every printed char
		; so, we just need to add sym_line _nr to the address and read data from flash to sram
		ldi YL, low(buff_data)
		clr YH
		clr ZH
		ldi itmp1, 6	; bytes to copy
cpybuff:ld ZL, X+
		add ZL, sym_line_nr		; go to current line in char bitmap
		lpm	itmp, Z
		st Y+, itmp
		dec itmp1
		brne cpybuff
		
		; now time to start printing
		ldi XL, low(buff_data)		; Character bits (updated for every line)
		;clr XH	; not needed. It was cleared before
		ldi itmp1, 6	; 6 characters to print
		clr itmp2		; bitmap line
		ld itmp, X+		; get line of the first symbol 
		; we have symbols with variable width (bitmap is 8 bits, dot is 2 bits. Other symbols 5 bits)
		; first symbol is a bitmap, so print full at the first iteration
		
		; print one char line		
		; itmp has bits for line of symbol
		; ### START OF TV OUT ###
TV_bmp:	bst itmp,7				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1
#if defined(SYMBOL_DOUBLE)
TV_sym:	; for 7 bit numbers
#endif
		bst itmp,6				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1
#if defined(SYMBOL_NORMAL)
TV_sym: ; for 6 bit numbers
#endif
		bst itmp,5				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

		bst itmp,4				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

		bst itmp,3				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

		bst itmp,2				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

TV_dot:	bst itmp,1				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

		bst itmp,0				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

		ld itmp, X+				;2 get line for the next symbol 
		out PORTB,z0			;1 clear last bit if was set

		
		dec	itmp1				;1
		breq TVprnExit			;1/2
		cpi itmp1, 2			;1 - if not dot, then print symbol
		brne TV_sym				;1/2
		rjmp TV_dot				;2
		; ### END OF TV OUT ###

TVprnExit:		
		sbi	PORTB, CONF_PIN		; restore back pullup for Configure pin
		dec sym_H_cntr
		brne pcint_exit	; skip sym_line_nr++ if sym_H_cntr not 0
		inc sym_line_nr	; go to next line of symbol
		mov sym_H_cntr, sym_H_strch	; reset counter for symbol stretch
		
pcint_exit:
		out SREG, r_sreg
		reti

; new page routine
vsout_newpage:
		;clr sym_line_nr	; Reset printing counter. Start printing from the first line of symbol bitmap
		clr TV_lineL
		clr TV_lineH
		; counter for low-bat
		cpi lowbat_cntr, 255
		breq vsonb
		dec lowbat_cntr
vsonb:	;convert voltage to addresses of chars to print
		rcall clear_num_addr_buffer
		; check for low-bat blinking
		sbrs lowbat_cntr, 5	; check bit in running number if bit toggle, then we toggle voltage output
		rjmp pcint_exit		; leave spaces in buffer
		ldi ZL, low(buff_addr1)+3	; point to the first digit position (+1) 
		mov itmp, voltage	; number to convert
		rcall conv_num_bcd
		ldi ZL, low(buff_addr2)+3	; point to the first digit position (+1) 
		mov itmp, voltage_min	; number to convert
		rcall conv_num_bcd		; number digits addresses will be stored to the next 6 bytes of RAM
		rjmp pcint_exit				; exit

; convert number and store to SRAM digit addresses
conv_num_bcd:
		ldi itmp1, 100
		rcall conv_d_bcd
		cp itmp2, z0	;	remove leading zero
		breq clear0
		rcall conv_bcd_to_address
		sbiw ZH:ZL,1
		st Z+, itmp2
clear0:	ldi itmp1, 10
		rcall conv_d_bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
		ldi itmp1, low(symdot << 1)
		st Z+, itmp1
		mov itmp2, itmp
		rcall conv_bcd_to_address
		st Z+, itmp2
l_ret:	ret

; convert one digit		
conv_d_bcd:
		clr itmp2
Lbcd:	cp itmp, itmp1
		brlo l_ret			; just use some ret to preserve FLASH
		inc itmp2
		sub itmp, itmp1
		rjmp Lbcd
		
clear_num_addr_buffer:
		clr ZH
		ldi ZL, low(buff_addr1)
		ldi itmp, low(symbitmap << 1)	; bitmap
		st Z+, itmp
		ldi itmp, low(symspc << 1)		; space
clr_rb:	st Z+, itmp
		cpi ZL, low(buff_addr1)+12		; clear 2 buffers
		brlo clr_rb
		ret

