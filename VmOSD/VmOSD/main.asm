; at 9.6mhz, 10 cycles = 1us
; PAL visible dots in 51.9us (498 cycles) or 166 dots
; PAL visible lines - 576

.EQU	FIRST_PRINT_TV_LINE = 270	; Line where we start to print
.EQU	FIRST_PRINT_TV_COLUMN = 10		; Line where we start to print
.EQU	SYM_HEIGHT = 12 ;(last zero is padding byte)

.EQU	VSOUT_PIN	= PB2	; Vertical sync pin
.EQU	HSOUT_PIN	= PB1	; Horizontal sync pin
.EQU	CONF_PIN	= PB0	; Pin for device Configuration
.EQU	VBAT_PIN	= PB3	; Resistor divider for voltage measurement
.EQU	VIDEO_PIN	= PB4	; OSD Video OUT

.def	z0			=	r0
.def	z1			=	r1
.def	r_sreg		=	r2	; Store SREG register in interrupts
.def	bcd			=	r3	; temp variable for BCD conversion
.def	tmp			=	r16
.def	tmp1		=	r17
.def	tmp2		=	r4
.def	itmp		=	r18	; variables to use in interrupts
.def	itmp1		=	r19	; variables to use in interrupts
.def	itmp2		=	r5	; variables to use in interrupts
.def	sym_line_nr	=	r20 ; line number of printed text (0 based)
.def	voltage		=	r21	; voltage in volts * 10 (dot will be printed in)
.def	TV_lineH	=	r6 ; counter for TV lines High byte.
.def	TV_lineL	=	r22 ; counter for TV lines Low byte.


.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff_addr:		.BYTE 4
buff_data:		.BYTE 4
TV_line_start:	.BYTE 2	; Line number where we start print data (from EEPROM)
TV_col_start:	.BYTE 1	; Column number where to start print data (from EEPROM). 
						; 10 equals about 3us.
						; useful range about 1-100

.CSEG
.ORG 0
		rjmp RESET ; Reset Handler
		rjmp EXT_INT0 ; IRQ0 Handler
		reti	;rjmp PCINT_int ; PCINT0 Handler
		reti	;rjmp TIM0_OVF ; Timer0 Overflow Handler
		reti	;rjmp EE_RDY ; EEPROM Ready Handler
		reti	;rjmp ANA_COMP ; Analog Comparator Handler
		rjmp TIM0_COMPA ; Timer0 CompareA Handler
		reti	;rjmp TIM0_COMPB ; Timer0 CompareB Handler
		reti	;rjmp WATCHDOG ; Watchdog Interrupt Handler
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		; should be first line after interrupts vectors
.include "timer.inc"

RESET:
		; change speed (ensure 9.6 mhz ossc)
		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock cgange
		out CLKPR, z0		; prescaler 1

		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		;clr sym_line_nr	; this variable will be initialized with new page routine
		ldi voltage, 126	; for debug

		; set line from where to start printing (later we store this value in EEPROM)
		ldi tmp, low(FIRST_PRINT_TV_LINE)
		ldi tmp1, high(FIRST_PRINT_TV_LINE)
		sts TV_line_start, tmp
		sts TV_line_start+1, tmp1
		ldi tmp, low(FIRST_PRINT_TV_COLUMN)
		sts TV_col_start, tmp

		;initialize INT0 and PCINT0 interrupts
		; INT0 - VIDEO Sync
		; PCINT0 - Configure protocol
		ldi tmp, 1<<ISC01 || 1<<ISC00	; falling edge
		out MCUCR, tmp
		ldi tmp, 1<<INT0 || 1<<PCIE
		out GIMSK, tmp
		ldi tmp, 1<<CONF_PIN
		out PCMSK, tmp
		
		; Configure timer for CTC mode (10 us)
		ldi tmp, 1<<WGM01	; CTC mode
		out TCCR0A, tmp
		ldi tmp, 1<<CS00	; no prescaling (1)
		out TCCR0B, tmp
		ldi tmp, 96		; 10us at 9.6 mhz
		out	OCR0A, tmp
		; Do not enable timer interrupt yet. It will be enabled only during printing data.
				
		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading

		rjmp main_loop				
		
; print one char line (about 3us)		
PrintCharLine:
; itmp has bits for line of symbol
	clr itmp2

	bst itmp,0				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	bst itmp,1				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	bst itmp,2				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	bst itmp,3				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	bst itmp,4				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	bst itmp,5				;1
	bld itmp2,VIDEO_PIN		;1 
	out PortB, itmp2		;1

	nop						;1
	nop						;1
	out PortB,z0			;1 (clear last bit if was set)
	ret
	


	
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
mult1:	add itmp1, itmp2
		dec	itmp
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
		clr ZH
		ldi itmp1, 4	; bytes to copy
cpybuff:ld ZL, X+
		add ZL, sym_line_nr		; go to current line in char bitmap
		lpm	itmp, Z
		st Y+, itmp
		dec itmp1
		brne cpybuff
		;inc sym_line_nr	; go to next number
		ret

; Here we come every time when Horisontal sync is come.
; Per Datasheet it is good to use leading edge of the signal (falling)
; we come here only when new TV line is started. 
; So, we need to check VSOUT pin here to see, when new page will begin
; HSOUT: -----+_+-----+_+-----+_+-----+_+-----+_+-----+_+
; VSOUT: ---------------------+___________________+------
EXT_INT0:
		in r_sreg, SREG
		; OK start timer for 12us (in CTC mode).
		; OK check VSOUT pin is LOW (New Page)
		; OK if no, then 
		; OK	increment line counter
		; OK	(timing for printing data should be very precise, so, we will use a timer)
		; OK	if line number < line where data starts, then stop timer and exit
		; OK	if line number > totl lines to print, then stop timer and exit 
		; OK	exit (printing will be done in Timer Compare Match interrupt)
		; OK if yes, then
		; OK initialize for new page (lines counter, fill sram with address of printed symbols...)
		; OK stop timer and exit
		sbis PINB, VSOUT_PIN
		rjmp vsout_newpage
		; HSOUT horisontal line routine
		rcall start_timer
		add	TV_lineL, z1	; +1
		adc	TV_lineH, z0
		; check current line number
		lds itmp1, TV_line_start
		lds itmp2, TV_line_start+1
		cp TV_lineL, itmp1
		cpc TV_lineH, itmp2
		brlo pcint_stop_tmr
		; calculate last line to print
		ldi itmp, SYM_HEIGHT
		inc itmp			; +1 for brlo comparing
		add	itmp1, itmp
		adc	itmp2, z0
		cp TV_lineL, itmp1
		cpc TV_lineH, itmp2
		brlo pcint_exit		; here we exit, because we are printing
		; no printing... exit
pcint_stop_tmr:
		rcall stop_timer
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


; Here we comming 10us later after Hsync captured.
; We will not use first 15us of the HLine. 
; Only about 41us of Line is 100% visible on screen.
TIM0_COMPA:
		; Timing here is realy critical. 
		; So, be very efficient and precise with the code
		in r_sreg, SREG
		; prepare data for printing
		rcall fill_num_buff_data	; 4.7us
		; Now is the delay to set horizontal position of the text
		lds	itmp, TV_col_start
		; 10 iterations of this loop is about 3us.
tmrcpl1:dec	itmp
		brne tmrcpl1
		; now time to start printing
		ldi ZL, buff_data
		ldi itmp1, 4
tmrcpl2:ld itmp, Z+
		rcall PrintCharLine
		dec	itmp1
		brne tmrcpl2
		inc sym_line_nr
		out SREG, r_sreg
		reti