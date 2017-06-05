; at 9.6mhz, 10 cycles = 1us
.equ	CRYSTAL_FREQ = 9600000	; Hz
; PAL visible dots in 51.9us (498 cycles) or 166 dots
; PAL visible lines - 576


.EQU	FIRST_PRINT_TV_LINE 	= 270	; Line where we start to print
.EQU	FIRST_PRINT_TV_COLUMN 	= 10	; Line where we start to print
.EQU	VOLT_DIV_CONST			= 186	; To get this number use formula: 4095/(Vmax*10)*8, where Vmax=(R1+R2)*Vref/R2, where Vref=1.1v and resistor values is from divider (15K/1K)
										; Vmax=(15+1)*1.1/1=17.6
										; 4095/(17.6*10)*8=186
										; For resistors 20K/1K constant will be 141 (max 5S battery). 
										
.EQU	SYM_HEIGHT 				= 12 ;(last zero is padding byte)

.EQU	VSOUT_PIN	= PB2	; Vertical sync pin
.EQU	HSOUT_PIN	= PB1	; Horizontal sync pin
.EQU	CONF_PIN	= PB0	; Pin for device Configuration
.EQU	VBAT_PIN	= PB3	; Resistor divider (15K/1K) for voltage measurement (4S max)
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
.def	TV_lineH	=	r6 	; counter for TV lines High byte.
.def	TV_lineL	=	r22 ; counter for TV lines Low byte.
.def	adc_cntr	=	r7	; counter for ADC readings
.def	adc_sumL	=	r8	; accumulated readings of ADC (sum of 64 values)
.def	adc_sumH	=	r9	; accumulated readings of ADC (sum of 64 values)

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
.include "adc.inc"
.include "tvout.inc"
.include "s_uart.inc"

RESET:
		; change speed (ensure 9.6 mhz ossc)
		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock change
		out CLKPR, z0		; prescaler 1

		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		clr adc_cntr		; couter for ADC readings (starting from 0)
		;clr sym_line_nr	; this variable will be initialized with new page routine

		; Configure Video pin as OUTPUT (LOW)
		sbi	DDRB, VIDEO_PIN
		; Enable pullup on Configure Pin. We will enter configure mode if this pin will go LOW (by PCINT interrupt)
		sbi	PORTB, CONF_PIN
		
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
		ldi tmp, 1<<INT0 ;|| 1<<PCIE - PCINT enabe not yet
		out GIMSK, tmp
		; PCINT enabe not yet
		;ldi tmp, 1<<CONF_PIN
		;out PCMSK, tmp
		
		; Configure timer for CTC mode (10 us)
		ldi tmp, 1<<WGM01	; CTC mode
		out TCCR0A, tmp
		ldi tmp, 1<<CS00	; no prescaling (1)
		out TCCR0B, tmp
		ldi tmp, 96		; 10us at 9.6 mhz
		out	OCR0A, tmp
		; Do not enable timer interrupt yet. It will be enabled only during printing data.
		
		; Configure ADC
		; Internal 1.1Vref, ADC channel, 10bit ADC result
		ldi tmp, 1<<REFS0 || 1<<MUX0 || 1<<MUX1
		out ADMUX, tmp
		; normal mode (single conversion mode), 64 prescaler (about 150khz at 9.6mhz ossc).
		ldi tmp, 1<<ADEN || 1<<ADSC || 1<<ADPS2 || 1<<ADPS1 || 0<<ADPS0
		out ADCSRA, tmp
		; turn off digital circuity in analog pin
		ldi tmp, 1<<VBAT_PIN
		out DIDR0, tmp
		
		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading
		ldi voltage, 126	; for debug

		; read ADSC bit to see if conversion finished
		sbis ADCSRA, ADSC
		rcall ReadVoltage
		
		; Do we need to enter Configure mode?
		sbis PINB, CONF_PIN
		rcall EnterCommandMode
		
		rjmp main_loop				
		

