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

.include "tn13Adef.inc"

;***** Enable second line for min voltage ******
;** lowest measured voltage will be displayed **
;#define ENABLE_MINVOLT	; Enable second line for minimal measured voltage

;***** Symbol height for printing voltage ******
;******** uncomment one of the defines *********
;#define SYMBOL_NORMAL ; 6bit wide
;#define SYMBOL_DOUBLE ; double height font (7bit wide)

;***** BITMAP before voltage ******
;** uncomment one of the defines **
;#define BITMAP_COPTER
;#define BITMAP_GOOGLES
;#define BITMAP_NONE	

;---- END of configurable defines ----
 
 ; at 9.6mhz, 10 cycles = 1us
.EQU	OVERCLOCK_VAL	= 24		; How much to add to OSCCAL for overclocking
									; 8 is about 10.4 mhz.
									; 16 is about 11.5 mhz.
									; 24 is about 13 mhz.
.EQU	BAUD 		 	= 19200 	; bps

; PAL visible dots in 51.9us (498 cycles) or 166 dots at 9.6mhz
; PAL visible lines - 576 (interleased is half of that)


.EQU	FIRST_PRINT_TV_LINE 	= 240	; Line where we start to print
.EQU	FIRST_PRINT_TV_COLUMN 	= 140	; Column where we start to print
.EQU	VOLT_DIV_CONST			= 186	; To get this number use formula (for 4S max): 
										; 4095/(Vmax*10)*8, where Vmax=(R1+R2)*Vref/R2, where Vref=1.1v 
										; and resistor values is from divider (15K/1K)
										; Vmax=(15+1)*1.1/1=17.6
										; 4095/(17.6*10)*8=186
										; For resistors 20K/1K constant will be 141 (max 5S battery). 
.EQU	LOW_BAT_VOLTAGE			= 105	; means 10.5 volts
										
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
.def	lowbat_cntr	=	r21	; counter for blinking voltage when it gets low
.def	sym_H_strch	=	r22	; value for symbol stretching
.def	sym_H_cntr	=	r6	; counter for symbol stretching
;						r23
.def	TV_lineL	=	r24 ; counter for TV lines Low byte. (don't change register mapping here)
.def	TV_lineH	=	r25 ; counter for TV lines High byte. (don't change register mapping here)
; Variables XL:XH, YL:YH, ZL:ZH are used in interrupts, so only use them in main code when interrupts are disabled
.def	adc_cntr	=	r7	; counter for ADC readings
.def	adc_sumL	=	r8	; accumulated readings of ADC (sum of 64 values)
.def	adc_sumH	=	r9	; accumulated readings of ADC (sum of 64 values)
.def	OSCCAL_nom	=	r10	; preserve here Factory value for nominal freq
.def	voltage_min	=	r11	; Minimum detected voltage. voltage in volts * 10 (dot will be printed in)

.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff_addr1:		.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
buff_addr2:		.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
buff_data:		.BYTE 6	; We have 6 symbols to print
Configuration_settings:	; From here  starts SRAM, that will be preserved in EEPROM
TV_line_start:	.BYTE 2	; Line number where we start print data (Configurable)
TV_col_start:	.BYTE 1	; Column number where to start print data (Configurable). 
						; 10 equals about 3us.
						; useful range about 1-100
Bat_correction:	.BYTE 1 ; signed value in mV (1=100mV) for correcting analog readings (Configurable).
Bat_low_volt:	.BYTE 1 ; value in mV (1=100mV) for signalling low voltage.

.ESEG
.ORG 5				; It is good practice do not use first bytes of EEPROM to prevet its corruption
EEPROM_Start:
EE_TV_line_start:	.DW 0
EE_TV_col_start:	.DB 0
EE_Bat_correction:	.DB 0 
EE_Bat_low_volt:	.DB 0

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
		mov adc_cntr,z1	;Watchdog Interrupt Handler. just update adc variable, because WDT only enabled in Command mode, so, no ADC readings occur
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		; should be first line after interrupts vectors
.include "adc.inc"
.include "tvout.inc"
.include "s_uart.inc"
.include "eeprom.inc"
.include "watchdog.inc"

RESET:
		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		clr adc_cntr		; couter for ADC readings (starting from 0)
		clr sym_line_nr		; first line of the char
		ldi lowbat_cntr, 255	; No blink 
		mov voltage_min, lowbat_cntr	; store maximal (255) value. Variable will be updated after first ADC reading
		mov sym_H_cntr, z1	; init variable
		in OSCCAL_nom, OSCCAL		; preserve nominal frequency calibration value
		
		; change speed (ensure 9.6 mhz ossc)
		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock change
		out CLKPR, z0		; prescaler 1
		
		rcall WDT_off		; just in case it left on after software reset

		; Configure Video pin as OUTPUT (LOW)
		sbi	DDRB, VIDEO_PIN
		; Enable pullup on Configure Pin. We will enter configure mode if this pin will go LOW (by PCINT interrupt)
		sbi	PORTB, CONF_PIN
		
		rcall EEPROM_read_settings
		
		;initialize INT0 
		; INT0 - H VIDEO Sync
		ldi tmp, 1<<ISC01 | 1<<ISC00 | 1<<SE	; falling edge, sleep mode enable
		out MCUCR, tmp
		ldi tmp, 1<<INT0 
		out GIMSK, tmp
				
		; Configure ADC
		; Internal 1.1Vref, ADC channel, 10bit ADC result
		ldi tmp, 1<<REFS0 | 1<<MUX0 | 1<<MUX1
		out ADMUX, tmp
		; normal mode (single conversion mode), 128 prescaler (about 75khz at 9.6mhz ossc).
		ldi tmp, 1<<ADEN | 1<<ADSC | 1<<ADPS2 | 1<<ADPS1 | 1<<ADPS0
		out ADCSRA, tmp
		; turn off digital circuity in analog pin
		sbi DIDR0, VBAT_PIN
		
		rcall OverclockMCU

		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading


		; Do we need to enter Configure mode?
		sbis PINB, CONF_PIN
		rcall EnterCommandMode
		sleep
		cpi TV_lineL, 30		; first 30 lines is non-printing lines. Timing there is not critical
		cpc TV_lineH, z0
		brsh main_loop		; only read adc while first non-printing TV lines
		; read ADSC bit to see if conversion finished
		sbis ADCSRA, ADSC
		rcall ReadVoltage
		rjmp main_loop				
		

OverclockMCU:
		; overclock cpu from 9.6mhz
		; need to do it slowly
		in tmp2, OSCCAL
		cp tmp2, OSCCAL_nom
		brne OSC_exit	; already overclocked
		ldi tmp1, 1			; increment
OSC_gen:
		ldi tmp, OVERCLOCK_VAL
OSC_ch:	add tmp2, tmp1		; We can't use here inc command because this part of code used as "dec" too.
		out OSCCAL, tmp2
		dec tmp
		brne OSC_ch
OSC_exit:
		ret
		
SlowdownMCU:
		; slowdown CPU to 9.6mhz (for safe EEPROM writes and serial transmission.)
		; need to do it slowly
		in tmp2, OSCCAL
		cp tmp2, OSCCAL_nom
		breq OSC_exit	; already slow
		ldi tmp1, 255
		rjmp OSC_gen
