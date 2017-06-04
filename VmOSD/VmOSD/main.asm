; at 9.6mhz, 10 cycles = 1us
; PAL visible dots in 51.9us (498 cycles) or 166 dots
; PAL visible lines - 576

.EQU	FIRST_PRINT_TV_LINE = 270	; Line where we start to print
.EQU	sym_height = 12 ;(last zero is padding byte)

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
.def	itmp		=	r18	; variables to use in interrupts
.def	itmp1		=	r19	; variables to use in interrupts
.def	itmp2		=	r5	; variables to use in interrupts
.def	sym_line_nr	=	r20
.def	voltage		=	r21	; voltage in volts * 10 (dot will be printed in)
.def	TV_lineH	=	r4 ; counter for TV lines High byte.
.def	TV_lineL	=	r22 ; counter for TV lines Low byte.


.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff:			.BYTE 4
TV_line_start:	.BYTE 2	; Line number where we start print data (from EEPROM)

.CSEG
.ORG 0
		rjmp RESET ; Reset Handler
		rjmp EXT_INT0 ; IRQ0 Handler
		reti	;rjmp PCINT_int ; PCINT0 Handler
		reti	;rjmp TIM0_OVF ; Timer0 Overflow Handler
		reti	;rjmp EE_RDY ; EEPROM Ready Handler
		reti	;rjmp ANA_COMP ; Analog Comparator Handler
		reti	;rjmp TIM0_COMPA ; Timer0 CompareA Handler
		reti	;rjmp TIM0_COMPB ; Timer0 CompareB Handler
		reti	;rjmp WATCHDOG ; Watchdog Interrupt Handler
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		
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

		; set line from where to start printing (later we store this value in EEPROM)
		ldi tmp, low(FIRST_PRINT_TV_LINE)
		ldi tmp1, high(FIRST_PRINT_TV_LINE)
		sts TV_line_start, tmp
		sts TV_line_start+1, tmp1

		;initialize INT0 and PCINT0 interrupts
		; INT0 - VIDEO Sync
		; PCINT0 - Configure protocol
		ldi tmp, 1<<ISC01 || 1<<ISC00	; falling edge
		out MCUCR, tmp
		ldi tmp, 1<<INT0 || 1<<PCIE
		out GIMSK, tmp
		ldi tmp, 1<<CONF_PIN
		out PCMSK, tmp
		
		; Configure timer for CTC mode (12 us)
		ldi tmp, 1<<WGM01	; CTC mode
		out TCCR0A, tmp
		ldi tmp, 1<<CS00	; no prescaling (1)
		out TCCR0B, tmp
		ldi tmp, 115		; 12us at 9.6 mhz
		out	OCR0A, tmp
		; Do not enable timer interrupt yet. It will be enabled only during printing data.
				
		sei ; Enable interrupts
		
		
		
		
		; ### beginning of the new page
		clr sym_line_nr
		; ### Beginning of the new line
		lds tmp, buff ; (first number to print)
		mov tmp1,tmp
		ldi ZH, high(symbols << 1)
		ldi ZL, low(symbols << 1)
		; go to right symbol - multiply R18 by 12 (sym_height)
		lsl tmp1	; mult by 2
		lsl tmp1	; mult by 4
		lsl tmp1	; mult by 8
		add tmp1, tmp
		add tmp1, tmp
		add tmp1, tmp
		add tmp1, tmp
		
		add tmp1, sym_line_nr
		
		add ZL, tmp1
		adc ZH, z0
		; now we are at correct line of the symbol
		LPM tmp, Z+	; 
				
		;rcall PrintCharLine
		
		
		
PrintCharLine:
; tmp has bits for line of symbol
	clr tmp1

	bst tmp,0				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	bst tmp,1				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	bst tmp,2				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	bst tmp,3				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	bst tmp,4				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	bst tmp,5				;1
	bld tmp1,VIDEO_PIN		;1 
	out PortB, tmp1			;1

	nop						;1
	nop						;1
	out PortB,z0			;1 (clear last bit if was set)
	ret
	


	
; voltage is input parameter	
conv_num_bcd:
		ldi tmp, 11		; space
		sts buff, tmp	; clear leading 0 if needed		
		mov tmp, voltage	; number to convert
		ldi tmp1, 100
		rcall conv_d_bcd
		cp bcd, z0	;	remove leading zero
		breq clear0
		sts buff, bcd
clear0:	ldi tmp1, 10
		rcall conv_d_bcd
		sts buff+1, bcd
		sts buff+2, tmp1	; dot
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
		; initialize for new page (lines counter, fill sram with codes of printed symbols...)
		; OK stop timer and exit
		rcall start_timer
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
		brlo pcint_stop_tmr
		; calculate last line to print
		ldi itmp, sym_height
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
		rjmp pcint_stop_tmr
