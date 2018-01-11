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
; * See <http://www.gnu.org/licenses/>.


; We need to do complicated math after text is printed.
clear_num_addr_buffer:
		clr ZH
		ldi ZL, low(buff_cur_volt)
		ldi itmp, low(symbitmap << 1)	; bitmap
		st Z+, itmp
		ldi itmp, low(symspc << 1)		; space
clr_rb:	st Z+, itmp
		cpi ZL, low(buff_cur_volt)+12		; clear 2 buffers (in case of Pilot Name we will not clear buffer, because we not change it)
		brlo clr_rb
		ret

; Run this routine right after text is printed.		
pcint_refill_buffer:
		; counter for low-bat
		cpi lowbat_cntr, 255
		breq vsonb
		dec lowbat_cntr
vsonb:	;convert voltage to addresses of chars to print
		rcall clear_num_addr_buffer
		; check for low-bat blinking
		sbrs lowbat_cntr, 5	; check bit in running number if bit toggle, then we toggle voltage output
		rjmp tvout_exit		; leave spaces in buffer
		ldi ZL, low(buff_cur_volt)+3	; point to the first digit position (+1) 
		mov itmp, voltage	; number to convert
		rcall conv_voltage_bcd
		ldi ZL, low(buff_min_volt)+3	; point to the first digit position (+1) 
		mov itmp, voltage_min	; number to convert
		rcall conv_voltage_bcd		; number digits addresses will be stored to the next 6 bytes of RAM
		cpse timer_flag, z1			; only fill timer buffer, when flag is 0
		rcall conv_timer_bcd		; Fill SRAM buffer with timer value
tvout_exit2:
		rjmp tvout_exit
		
; resets sym_line_nr for proper printing of next line
tvout_exit1:
		; should we advance Z pointer to the next block?
		cp sym_line_nr, z0
		breq tvout_exit2
		; advance to the next OSD block
		adiw ZH:ZL, 8		; Every OSD block data is 8 bytes long
		clr sym_line_nr	; Reset printing counter. Start printing from the first line of symbol bitmap
		; decide, should we refill buffers?
		ldi itmp, HIGH((OSDdata << 1) + OSDdataLen)
		cpi ZL, LOW((OSDdata << 1) + OSDdataLen)
		cpc ZH, itmp
		brlo tvout_exit2
		rjmp pcint_refill_buffer
		

; main TVOUT routine to print data on OSD		
TVOUT:
		; HSOUT horisontal line routine
		adiw TV_lineH:TV_lineL, 1	; inc TV_lineL:TV_lineH

		clr XH				; SRAM pointer. Only XL will change, so prepare XH for 16 bit operations
		lpm XL, Z+			; SRAM pointer.
		lpm itmp1, Z+		; bytes to print. If 0 then print number (6 bytes), take care of it later
		lpm osd_dot_pos, Z+	; Dot position in the nubers
		adiw ZH:ZL, 1		; reserved byte
		lpm itmp, Z+		; column
		lpm sym_H_strch, Z+	
		lpm YL, Z+			; line
		lpm YH, Z+			; line
		;revert back Z pointer
		sbiw ZH:ZL, 8		; Every OSD block data is 8 bytes long
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brlo tvout_exit2			; not needed to print yet, just exit
		; calculate last line to print
		adiw YH:YL, SYM_HEIGHT ; no double height symbols
		cpse sym_H_strch, r1
		adiw YH:YL, SYM_HEIGHT ; double height symbols
		cp TV_lineL, YL
		cpc TV_lineH, YH
		brsh tvout_exit1	; not need to print anymore, exit but check, do we need to refill buffers (end of OSD data)
		
		
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
		; buff_cur_volt, buff_min_volt etc contains addresses of every printed char
		; so, we just need to add sym_line _nr to the address and read data from flash to sram
		push ZL
		push ZH
		ldi YL, low(buff_data)
		clr YH
		clr ZH
		mov itmp2, itmp1	; bytes to copy
cpybuff:ld ZL, X+
		add ZL, sym_line_nr		; go to current line in char bitmap
		lpm	itmp, Z
		st Y+, itmp
		dec itmp2
		brne cpybuff
		pop ZH
		pop ZL
		
		; now time to start printing
		ldi XL, low(buff_data)		; Character bits (updated for every line)
		;clr XH	; not needed. It was cleared before
		;itmp1 already has quantity of chars to print
		in itmp2, PINB			; preserve other ports
		ld itmp, X+		; get line of the first symbol 
		; we have symbols with variable width (bitmap is 8 bits, dot is 2 bits. Other symbols 7 bits)
		; first symbol is a bitmap, so print full at the first iteration
		
		; print one char line		
		; itmp has bits for line of symbol
		; ### START OF TV OUT ###
TV_bmp:	bst itmp,7				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1
TV_sym:	; for 7 bit numbers
		bst itmp,6				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

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
		cp itmp1, osd_dot_pos	;1 - if not dot, then print symbol
		brne TV_sym				;1/2
		rjmp TV_dot				;2
		; ### END OF TV OUT ###

TVprnExit:		
		; update sym_H_cntr if needed
		cp sym_H_cntr, z0
		brne skp2
		mov sym_H_cntr, sym_H_strch	; reset counter for symbol stretch
skp2:	dec sym_H_cntr
		brne tvout_exit	; skip sym_line_nr++ if sym_H_cntr not 0
		inc sym_line_nr	; go to next line of symbol

tvout_exit:
		ret

		
; convert number and store to SRAM digit addresses
conv_voltage_bcd:
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
		ret

; convert time and store to SRAM digit addresses
conv_timer_bcd:
		ldi ZL, low(buff_timer)	; point to the first digit position
		mov itmp, timer_mins
		ldi itmp1, 10
		rcall conv_d_bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
		mov itmp2, itmp
		rcall conv_bcd_to_address
		st Z+, itmp2
		ldi itmp1, low(symcoln << 1)
		st Z+, itmp1
		mov itmp, timer_secs
		ldi itmp1, 10
		rcall conv_d_bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
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
