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

.include "tn13Adef.inc"

;***** BITMAP before voltage ******
;** uncomment one of the defines **
#define BITMAP_COPTER
;#define BITMAP_GOOGLES
;#define BITMAP_NONE
	

;---- END of configurable defines ----

 ; at 9.6mhz, 10 cycles = 1us
.EQU	OVERCLOCK_VAL	= 24		; How much to add to OSCCAL for overclocking
									; 8 is about 10.4 mhz.
									; 16 is about 11.5 mhz.
									; 24 is about 13 mhz.

									; PAL visible dots in 51.9us (498 cycles) or 166 dots at 9.6mhz
; PAL visible lines - 576 (interleased is half of that)

;************ CONFIGURATION ***************
; !!!!!This is user adjustable section!!!!!

; *** VOLTAGE SECTION
; Low Battery voltage value. Below this voltage, OSD voltage will start to blink
.EQU	LOW_BAT_VOLTAGE		= 30	; means 3.0 volts

; If your multimeter measurement will be different from OSD measurement, then correction can be made here.
; For example, if your multimeter shows, 11.5 volts, but OSD shows 11.7 volts, then enter here -2 (-0.2v).
.EQU	BAT_CORRECTION		= 0		; Signed int8 value for voltage readings correction


;*** PILOT NAME SYMBOLS
; Define here all characters, that will be printed as a pilot name.
#define SYM_P
#define SYM_A
#define SYM_V
#define SYM_E
#define SYM_L

;******************************************
; Show/Hide OSD elements configured 
; at the end of this file 
;******* END OF CONFIGURATION PART 1 *********


; If you did not changed hardware, then you don't need to change this...
.EQU	VOLT_DIV_CONST		= 186	; To get this number use formula (for 4S max): 
										; 4095/(Vmax*10)*8, where Vmax=(R1+R2)*Vref/R2, where Vref=1.1v 
										; and resistor values is from divider (15K/1K)
										; Vmax=(15+1)*1.1/1=17.6
										; 4095/(17.6*10)*8=186
										; For resistors 20K/1K constant will be 141 (max 5S battery). 
.EQU	BUFFER_LEN	 		= 10	; Length of the SRAM buffers fro text printing. - don't change this...

										
.EQU	TEST_PIN	= PB2	; For testing purposes will output V/H sync
;.EQU	HSOUT_PIN	= PB1	; Horizontal sync pin (Seems CSOUT pin is more reliable)
;.EQU	CONF_PIN	= PB0	; Pin for device Configuration
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
.def	voltage		=	r5	; voltage in volts * 10 (dot will be printed in)
.def	voltage_min	=	r20	; Minimum detected voltage. voltage in volts * 10 (dot will be printed in)
.def	sym_line_nr	=	r6 	; line number of printed text (0 based)
.def	lowbat_cntr	=	r21	; counter for blinking voltage when it gets low
.def	sym_H_strch	=	r22	; value for symbol stretching
.def	sym_H_cntr	=	r7	; counter for symbol stretching
.def	adc_cntr	=	r23	; counter for ADC readings
.def	TV_lineL	=	r24 ; counter for TV lines Low byte. (don't change register mapping here)
.def	TV_lineH	=	r25 ; counter for TV lines High byte. (don't change register mapping here)
; Variables XL:XH, YL:YH, ZL:ZH are used in interrupts, so only use them in main code when interrupts are disabled
.def	adc_sumL	=	r8	; accumulated readings of ADC (sum of 64 values)
.def	adc_sumH	=	r9	; accumulated readings of ADC (sum of 64 values)
.def	osd_dot_pos	=	r10	; Position of the dot(.) in printed line. For numbers it is 2. For text it is 0.
.def	timer_flag	=	r11	; not 0 if we need to advance the timer
.def	timer_secs	=	r12	; Seconds of the timer
.def	timer_mins	=	r13	; Seconds of the timer
;.def	is_h_sync 	=	r14 ; Flags for H/V sync detection 

.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff_cur_volt:	.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
buff_min_volt:	.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
buff_timer:		.BYTE 5	; 5 symbols for timer 00:00
buff_cross:		.BYTE 1
buff_name:		.BYTE BUFFER_LEN
buff_data:		.BYTE BUFFER_LEN

.CSEG
.ORG 0
		rjmp RESET ; Reset Handler
		reti	;rjmp EXT_INT0 ; IRQ0 Handler
		reti	;rjmp PCINT_int ; PCINT0 Handler
		reti	;rjmp TIM0_OVF ; Timer0 Overflow Handler
		reti	;rjmp EE_RDY ; EEPROM Ready Handler
		rjmp ANA_COMP ; Analog Comparator Handler
		reti	;rjmp TIM0_COMPA ; Timer0 CompareA Handler
		reti	;rjmp TIM0_COMPB ; Timer0 CompareB Handler
		inc timer_flag	;rjmp WATCHDOG
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		; should be first line after interrupts vectors
.include "adc.inc"
.include "tvout.inc"
.include "timer.inc"
.include "analog.inc"
.include "calibration.inc"

RESET:
		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		;clr adc_cntr		; couter for ADC readings. No need to initialize. Anyway we give some time for ADC to initialize all variables and states
		;clr is_h_sync		; clear all H/V sync flags
		clr sym_line_nr		; first line of the char
		ldi lowbat_cntr, 254	; We want to start this counter to make a delay for voltage stabilizing
		;mov voltage_min, lowbat_cntr	; store big (255) value. Variable will be updated later
		mov sym_H_cntr, z0	; init variable. If 0 then we need update it.
		
		; change speed (ensure 9.6 mhz ossc)
		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock change
		out CLKPR, z0		; prescaler 1
		
		; Configure Video pin as OUTPUT (LOW)
		sbi	DDRB, VIDEO_PIN
				
		; Configure Analog Comparator (Interrupt on rising edge of Output)
		ldi tmp, 1<<ACIE | 1<<ACIS1 | 1<<ACIS0
		out ACSR, tmp
		
		; Configure ADC
		; Internal 1.1Vref, ADC channel, 10bit ADC result
		ldi tmp, 1<<REFS0 | 1<<MUX0 | 1<<MUX1
		out ADMUX, tmp
		; normal mode (single conversion mode), 128 prescaler (about 75khz at 9.6mhz ossc).
		ldi tmp, 1<<ADEN | 1<<ADSC | 1<<ADPS2 | 1<<ADPS1 | 1<<ADPS0
		out ADCSRA, tmp
		
		; turn off digital circuity on analog pins
		ldi tmp, 1<<VBAT_PIN | 1<<AIN1D | 1<<AIN0D
		out DIDR0, tmp
		
		rcall OverclockMCU

		rcall FillPilotNameBuffer
		
		; fill CrossHair symbol SRAM Buffer
		ldi tmp, (symCross << 1)
		sts buff_cross, tmp

		; Wait for voltage stabilizing and ADC warmup
strt_wt:sbic ADCSRA, ADSC
		rjmp strt_wt
		; ADC is ready
		rcall ReadVoltage
		dec lowbat_cntr
		brne strt_wt	; read ADC 255 times
		; now our voltage and voltage_min is messed. Lets reset at least voltage_min.
		ldi voltage_min, 255
		
		rcall OCR0A_Calibration	; get OCR0A value
		; result is returned in tmp variable
		;ldi tmp, 82								; about 50us in CTC mode
		out OCR0A, tmp
		;start HW timer for H/V sync detection
		ldi tmp, 1<<WGM01
		out TCCR0A, tmp							; CTC mode to reduce the resolution of timer to measure 50us
		ldi tmp, 0<<CS02 | 1<<CS01 | 0<<CS00	; 8 prescaller (at 13Mhz it overflows every 156us)
		out TCCR0B, tmp
		
		rcall WDT_Start	; start OSD timer
		
		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading
		sleep
		cpi TV_lineL, 20		; first 20 lines is normally non-printing lines. Timing there is not critical
		cpc TV_lineH, z0
		brsh main_loop		; only read adc while first non-printing TV lines
		; read ADSC bit to see if conversion finished
		sbis ADCSRA, ADSC
		rcall ReadVoltage
		rcall Timer
		rjmp main_loop				
		
OverclockMCU:
		; overclock cpu from 9.6mhz
		; need to do it slowly
		in tmp2, OSCCAL
		ldi tmp, OVERCLOCK_VAL
OSC_ch:	inc tmp2
		out OSCCAL, tmp2
		dec tmp
		brne OSC_ch
		ret

FillPilotNameBuffer:
		ldi ZL, low(PilotNameCharsAddrs << 1)
		ldi ZH, high(PilotNameCharsAddrs << 1)
		ldi YL, low(buff_name)
		clr YH
		ldi tmp, BUFFER_LEN
FPNB1:	lpm tmp1, Z+
		st Y+, tmp1
		dec tmp
		brne FPNB1
		ret


;******* CONFIGURATION PART 2 *********		

; *** HOW many elements is showed on OSD. 
; For example, if you need to show 4 elements (Timer, Crosshair, Voltage and Min Voltage) 
; then EQU will look like this: OSDdataLen	= 4 * 8
.EQU	OSDdataLen	= 4 * 8	; 4 sections by 8 bytes each

; *** OSD Elements
; Comment unneeded blocks
OSDdata:
	; print Name (10 symbols max)
	.DB buff_name, 5		; buffer from where to print data, len of the printed text (6 for voltage)
	.DB 0, 0				; dot position from right (0 for text), reserved
	.DB 60, 1				; column to print and Symbol stretch (1 or 2)
	.DW 25					; line to print

	; print timer
	.DB buff_timer, 5		; buffer from where to print data, len of the printed text (6 for voltage)
	.DB 3, 0				; dot position from right (0 for text), reserved
	.DB 62, 1				; column to print and Symbol stretch (1 or 2)
	.DW 40					; line to print

	; print crosshair
;	.DB buff_cross, 1		; buffer from where to print data, len of the printed text (6 for voltage)
;	.DB 0, 0				; dot position from right (0 for text), reserved
;	.DB 103, 1				; column to print and Symbol stretch (1 or 2)
;	.DW 135					; line to print

	; print current voltage
	.DB buff_cur_volt, 6	; buffer from where to print data, len of the printed text (6 for voltage)
	.DB 2, 0				; dot position from right (0 for text), reserved
	.DB 140, 2				; column to print and Symbol stretch (1 or 2)
	.DW 230					; line to print

	; print min voltage
	.DB buff_min_volt, 6	; buffer from where to print data, len of the printed text (6 for voltage)
	.DB 2, 0				; dot position from right (0 for text), reserved
	.DB 140, 1				; column to print and Symbol stretch (1 or 2)
	.DW 260					; line to print
	

; *** PILOTNAME STRING
; maximum is 10 characters.	
; If you don't need Pilot Name on OSD, then comment out the .DB line (PilotNameCharsAddrs: label should not be commented)
PilotNameCharsAddrs:
	.DB symP<<1,symA<<1,symV<<1,symE<<1,symL<<1,symspc<<1

;*********** END OF CONFIGURATION *************