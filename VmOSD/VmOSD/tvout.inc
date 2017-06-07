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
		cp bcd, z0	;	remove leading zero
		breq clear0
		mov itmp2, bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
clear0:	ldi itmp1, 10
		rcall conv_d_bcd
		mov itmp2, bcd
		rcall conv_bcd_to_address
		st Z+, itmp2
		ldi itmp1, low(symdot << 1)
		st Z+, itmp1
		mov itmp2, itmp
		rcall conv_bcd_to_address
		st Z, itmp2
exitbcd:ret
conv_d_bcd:
		clr bcd
Lbcd:	cp itmp, itmp1
		brlo exitbcd
		inc bcd
		sub itmp, itmp1
		rjmp Lbcd


; this routine is called from interrupts, so use interrupt registers
; tmp2 contains bcd number
; Convert Char number to address
conv_bcd_to_address:		
		push itmp
		push itmp1
		ldi itmp1, low(symbols << 1)	; we need only low address byte, because fonts are at the beginning of the flash
		ldi itmp, SYM_HEIGHT
mult1:	add itmp1, itmp
		dec	itmp2
		brne mult1
		mov itmp2, itmp1	; return value
		pop itmp1
		pop itmp
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
		;clr ZH
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
		; OK	if line number < line where data starts, then stop timer and exit
		; OK	if line number > totl lines to print, then stop timer and exit 
		; OK	exit (printing will be done in Timer Compare Match interrupt)
		; OK if yes, then
		; OK initialize for new page (lines counter, fill sram with address of printed symbols...)
		; OK exit
		sbis PINB, VSOUT_PIN
		rjmp vsout_newpage
		; HSOUT horisontal line routine
		add	TV_lineL, z1	; +1
		adc	TV_lineH, z0
		; check current line number
		lds itmp1, TV_line_start
		lds itmp2, TV_line_start+1
		cp TV_lineL, itmp1
		cpc TV_lineH, itmp2
		brlo pcint_exit			; not needed to print yet
		; calculate last line to print
		ldi itmp, SYM_HEIGHT
		inc itmp			; +1 for brlo comparing
		add	itmp1, itmp
		adc	itmp2, z0
		cp TV_lineL, itmp1
		cpc TV_lineH, itmp2
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
		ldi itmp1, 4
		mov itmp2, z1			; Configure PIN is HIGH (preserve pullup)
tmrcpl2:ld itmp, Z+
		; this routine is called from interrupts, so use interrupt registers
		; print one char line (about 3us)		
		; itmp has bits for line of symbol
		; ### START OF TV OUT ###
		bst itmp,7				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		bst itmp,6				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		bst itmp,5				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		bst itmp,4				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		bst itmp,3				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		bst itmp,2				;1
		bld itmp2,VIDEO_PIN		;1 
		out PortB, itmp2		;1

		nop						;1
		nop						;1
		out PortB,z1			;1 (clear last bit if was set, preserving Configure Pin pullup)

		dec	itmp1
		brne tmrcpl2
		; ### END OF TV OUT ###
		
		inc sym_line_nr	; go to next line of symbol
		
pcint_exit:
		out SREG, r_sreg
		reti

; new page routine
vsout_newpage:
		clr sym_line_nr	; start printing from the first line of symbol bitmap
		clr TV_lineL
		clr TV_lineH
		rcall fill_num_buff_addr	; convert voltage to addresses of chars to print
		rjmp pcint_stop_tmr			; just to make sure timer is stopped

