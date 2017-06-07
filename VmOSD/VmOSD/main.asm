; at 9.6mhz, 10 cycles = 1us
.EQU	CRYSTAL_FREQ 	= 9600000	; Hz
.EQU	BAUD 		 	= 19200 	; bps
.EQU 	SYMBOL_STRETCH 	= 2		; copy every line of symbol SYMBOL_STRETCH times

; PAL visible dots in 51.9us (498 cycles) or 166 dots
; PAL visible lines - 576


.EQU	FIRST_PRINT_TV_LINE 	= 200	; Line where we start to print
.EQU	FIRST_PRINT_TV_COLUMN 	= 30	; Line where we start to print
.EQU	VOLT_DIV_CONST			= 186	; To get this number use formula: 4095/(Vmax*10)*8, where Vmax=(R1+R2)*Vref/R2, where Vref=1.1v and resistor values is from divider (15K/1K)
										; Vmax=(15+1)*1.1/1=17.6
										; 4095/(17.6*10)*8=186
										; For resistors 20K/1K constant will be 141 (max 5S battery). 
										
.EQU	SYM_HEIGHT 				= 12 	;(last zero is padding byte)

.EQU	VSOUT_PIN	= PB2	; Vertical sync pin
.EQU	HSOUT_PIN	= PB1	; Horizontal sync pin (Seems CSOUT pin is more reliable)
.EQU	CONF_PIN	= PB0	; Pin for device Configuration
.EQU	VBAT_PIN	= PB3	; Resistor divider (15K/1K) for voltage measurement (4S max)
.EQU	VIDEO_PIN	= PB4	; OSD Video OUT

.def	z0			=	r0
.def	z1			=	r1
.def	r_sreg		=	r2	; Store SREG register in interrupts
.def	tmp			=	r16
.def	tmp1		=	r17
.def	tmp2		=	r3
.def	itmp		=	r18	; variables to use in interrupts
.def	itmp1		=	r19	; variables to use in interrupts
.def	itmp2		=	r4	; variables to use in interrupts
.def	voltage		=	r20	; voltage in volts * 10 (dot will be printed in)
.def	sym_line_nr	=	r5 	; line number of printed text (0 based)
.def	sym_H_cntr	=	r21	; counter for symbol stretching
;						r22
;						r23
.def	TV_lineL	=	r24 ; counter for TV lines Low byte. (don't change register mapping here)
.def	TV_lineH	=	r25 ; counter for TV lines High byte. (don't change register mapping here)
.def	adc_cntr	=	r6	; counter for ADC readings
.def	adc_sumL	=	r7	; accumulated readings of ADC (sum of 64 values)
.def	adc_sumH	=	r8	; accumulated readings of ADC (sum of 64 values)
; Variables XL:XH, YL:YH, ZL:ZH are used in interrupts, so only use them in main code when interrupts are disabled

.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff_addr:		.BYTE 4
buff_data:		.BYTE 4
TV_line_start:	.BYTE 2	; Line number where we start print data (from EEPROM)
TV_col_start:	.BYTE 1	; Column number where to start print data (from EEPROM). 
						; 10 equals about 3us.
						; useful range about 1-100
Bat_correction:	.BYTE 1 ; signed value in mV (1=100mV) for correcting analog readings (from EEPROM).

.ESEG
.ORG 5				; It is good practice do not use first bytes of EEPROM to prevet its corruption
EEPROM_Start:
EE_TV_line_start:	.BYTE 2
EE_TV_col_start:	.BYTE 1
EE_Bat_correction:	.BYTE 1 

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
		rjmp WATCHDOG ; Watchdog Interrupt Handler
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		; should be first line after interrupts vectors
.include "adc.inc"
.include "tvout.inc"
.include "s_uart.inc"
.include "eeprom.inc"
.include "watchdog.inc"

RESET:
		; change speed (ensure 9.6 mhz ossc)

		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		clr adc_cntr		; couter for ADC readings (starting from 0)
		clr sym_line_nr		; first line of the char
		ldi sym_H_cntr, SYMBOL_STRETCH	; init variable just in case

		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock change
		out CLKPR, z0		; prescaler 1

		rcall WDT_off		; just in case it left on after software reset
		
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

		;initialize INT0 
		; INT0 - VIDEO Sync
		ldi tmp, 1<<ISC01 | 1<<ISC00	; falling edge
		out MCUCR, tmp
		ldi tmp, 1<<INT0 
		out GIMSK, tmp
				
		; Configure ADC
		; Internal 1.1Vref, ADC channel, 10bit ADC result
		ldi tmp, 1<<REFS0 | 1<<MUX0 | 1<<MUX1
		out ADMUX, tmp
		; normal mode (single conversion mode), 64 prescaler (about 150khz at 9.6mhz ossc).
		ldi tmp, 1<<ADEN | 1<<ADSC | 1<<ADPS2 | 1<<ADPS1 | 0<<ADPS0
		out ADCSRA, tmp
		; turn off digital circuity in analog pin
		ldi tmp, 1<<VBAT_PIN
		out DIDR0, tmp
		
		ldi voltage, 126	; for debug

		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading

		; read ADSC bit to see if conversion finished
		;sbis ADCSRA, ADSC
		;rcall ReadVoltage
		
		; Do we need to enter Configure mode?
		sbis PINB, CONF_PIN
		rcall EnterCommandMode
		
		rjmp main_loop				
		

