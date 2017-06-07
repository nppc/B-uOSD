/*
 * tvout.inc
 *
 *  Created: 04-Jun-17
 *   Author: Pavel
 */ 

	
; this routine is called from interrupts, so use interrupt registers
; voltage is input parameter	
fill_num_buff_addr:
		clr ZH
		ldi ZL, low(buff_addr)
		ldi itmp, low(symspc << 1)		; space
		st Z, itmp
		mov itmp, voltage	; number to convert
		ldi itmp1, 100
		rcall conv_d_bcd
		cp itmp2, z0	;	remove leading zero
		breq clear0
		rcall conv_bcd_to_address
		st Z+, itmp2
clear0:	ldi itmp1, 10
		rcall conv_d_bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
		ldi itmp1, low(symdot << 1)
		st Z+, itmp1
		mov itmp2, itmp
		rcall conv_bcd_to_address
		st Z, itmp2
exitbcd:ret
conv_d_bcd:
		clr itmp2
Lbcd:	cp itmp, itmp1
		brlo exitbcd
		inc itmp2
		sub itmp, itmp1
		rjmp Lbcd


; this routine is called from interrupts, so use interrupt registers
; tmp2 contains bcd number
; Convert Char number to address
conv_bcd_to_address:		
		; use XH register just because it is free 
		ldi XH, low(symbols << 1)	; we need only low address byte, because fonts are at the beginning of the flash
mult1:	subi XH, -SYM_HEIGHT	; XH=XH+12
		dec	itmp2
		brne mult1
		mov itmp2, XH	; return value
		ret
		

; this routine is called from interrupts, so use interrupt registers
; fill data buffer with printed line of bits
; current line number in sym_line_nr
; buff_addr contains addresses of every printed char
fill_num_buff_data:
		; so, we just need to add sym_line _nr to the address and read data from flash to sram
		ldi	XL, low(buff_addr)
		clr XH
		ldi YL, low(buff_data)
		clr YH
		clr ZH
		ldi itmp1, 4	; bytes to copy
cpybuff:ld ZL, X+
		add ZL, sym_line_nr		; go to current line in char bitmap
		lpm	itmp, Z
		st Y+, itmp
		dec itmp1
		brne cpybuff
		ret
		

; Here we come every time when Horisontal sync is come.
; Per Datasheet it is good to use leading edge of the signal (falling)
; we come here only when new TV line is started. 
; So, we need to check VSOUT pin here to see, when new page will begin
; CSOUT: -----+_+-----+_+-----+_+-----+_+-----+_+-----+_+
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
		; HSOUT horisontal line routine
		adiw TV_lineH:TV_lineL, 1	; inc TV_lineL:TV_lineH
		; check current line number (we are using XH:XL just for sake of use adiw next)
		lds XL, TV_line_start
		lds XH, TV_line_start+1
		cp TV_lineL, XL
		cpc TV_lineH, XH
		brlo pcint_exit			; not needed to print yet
		; calculate last line to print
		adiw XH:XL, SYM_HEIGHT * SYMBOL_STRETCH
		cp TV_lineL, XL
		cpc TV_lineH, XH
		brsh pcint_exit		; printing is finished, just exit
		
		;  printing...
		; We will not use first 15us of the HLine. And we can't because of code running at the beginning every line :)
		; Only about 41us of Line is 100% visible on screen.
		; prepare data for printing
		rcall fill_num_buff_data	; 4.7us
		; Now is the delay to set horizontal position of the text
		lds	itmp, TV_col_start
		; 10 iterations of this loop is about 3us.
tmrcpl1:dec	itmp
		brne tmrcpl1
		; now time to start printing
		ldi ZL, low(buff_data)
		clr ZH
		ldi itmp1, 4
		clr itmp2
tmrcpl2:ld itmp, Z+
		; print one char line (about 3us)		
		; itmp has bits for line of symbol
		; ### START OF TV OUT ###
		bst itmp,7				;1
		bld itmp2,VIDEO_PIN		;1 
		out PORTB, itmp2		;1

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

		;bst itmp,2				;1
		;bld itmp2,VIDEO_PIN		;1 
		;out PORTB, itmp2		;1

		clt						;1 clear last bit if was set
		bld itmp2,VIDEO_PIN		;1
		out PORTB,itmp2			;1

		dec	itmp1
		brne tmrcpl2
		; ### END OF TV OUT ###
		
		sbi	PORTB, CONF_PIN		; restore back pullup for Configure pin
		dec sym_H_cntr
		brne pcint_exit	; skip sym_line_nr++ if sym_H_cntr not 0
		inc sym_line_nr	; go to next line of symbol
		ldi sym_H_cntr, SYMBOL_STRETCH
		
pcint_exit:
		out SREG, r_sreg
		reti

; new page routine
vsout_newpage:
		clr sym_line_nr	; Reset printing counter. Start printing from the first line of symbol bitmap
		clr TV_lineL
		clr TV_lineH
		ldi sym_H_cntr, SYMBOL_STRETCH
		rcall fill_num_buff_addr	; convert voltage to addresses of chars to print
		rjmp pcint_exit				; exit

