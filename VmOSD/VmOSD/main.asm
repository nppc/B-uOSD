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

;********* CONFIGURATION disable **************
;** Removes support for serial configuration **
#define NOCONFIG

;********** Show PILOT NAME on OSD *************
;** To enable this feature, uncomment it here **
#define PILOTNAME	; This feature can't work together with CONFIG feature
; Also define needed letters (not more than 10) and construct a string from them at the end of this file
#if defined(PILOTNAME)
#define SYM_P
#define SYM_A
#define SYM_V
#define SYM_E
#define SYM_L
#endif
	

;---- END of configurable defines ----

 ; at 9.6mhz, 10 cycles = 1us
.EQU	OVERCLOCK_VAL	= 24		; How much to add to OSCCAL for overclocking
									; 8 is about 10.4 mhz.
									; 16 is about 11.5 mhz.
									; 24 is about 13 mhz.
#if !defined(NOCONFIG)
.EQU	BAUD 		 	= 19200 	; bps
#endif

; PAL visible dots in 51.9us (498 cycles) or 166 dots at 9.6mhz
; PAL visible lines - 576 (interleased is half of that)

; Predefined configurable parameters
.EQU	PRINT_VOLT_LINE 	= 240	; Line where we start to print
.EQU	PRINT_VOLT_COLUMN	= 140	; Column where we start to print
.EQU	LOW_BAT_VOLTAGE		= 30	; means 10.5 volts
.EQU	BAT_CORRECTION		= 0		; Signed value for correction voltage readings
#if defined(PILOTNAME)
.EQU	PRINT_PILOT_LINE 	= 40	; Line where we start to print
.EQU	PRINT_PILOT_COLUMN	= 60	; Column where we start to print
.EQU	PILOTNAME_LEN 		= 8		; Length of Pilot Name. - don't change this...
#endif
; If you did not changed hardware, then you don't need to change this...
.EQU	VOLT_DIV_CONST		= 186	; To get this number use formula (for 4S max): 
										; 4095/(Vmax*10)*8, where Vmax=(R1+R2)*Vref/R2, where Vref=1.1v 
										; and resistor values is from divider (15K/1K)
										; Vmax=(15+1)*1.1/1=17.6
										; 4095/(17.6*10)*8=186
										; For resistors 20K/1K constant will be 141 (max 5S battery). 

; END OF predefined configurable parameters
										
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
#if !defined(NOCONFIG)
.def	OSCCAL_nom	=	r10	; preserve here Factory value for nominal freq
#endif

.DSEG
.ORG 0x60
; we need buffer in SRAM for printing numbers (total 4 bytes with dot)
buff_addr1:		.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
buff_addr2:		.BYTE 6	; We have 6 symbols to print. Bitmap, space, voltage (nn.n)
#if defined(PILOTNAME)
buff_addr3:		.BYTE PILOTNAME_LEN + 2	; We need 2 more symbols for reusing numbers printing routine (.N)
buff_data:		.BYTE PILOTNAME_LEN + 2	; We need 2 more symbols for reusing numbers printing routine (.N)
#else
buff_data:		.BYTE 6	; We have 6 symbols to print
#endif

#if !defined(NOCONFIG)
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
#endif

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
#if !defined(NOCONFIG)
		mov adc_cntr,z1	;Watchdog Interrupt Handler. just update adc variable, because WDT only enabled in Command mode, so, no ADC readings occur
#else
		reti
#endif
		reti	;rjmp ADC ; ADC Conversion Handler

.include "font.inc"		; should be first line after interrupts vectors
.include "adc.inc"
.include "tvout.inc"
#if !defined(NOCONFIG)
.include "s_uart.inc"
.include "eeprom.inc"
.include "watchdog.inc"
#endif

RESET:
		ldi tmp, low(RAMEND); Main program start
		out SPL,tmp ; Set Stack Pointer to top of RAM
		
		;init variables
		clr z0
		clr z1
		inc z1
		;clr adc_cntr		; couter for ADC readings. No need to initialize. Anyway we give some time for ADC to initialize all variables and states
		clr sym_line_nr		; first line of the char
		ldi lowbat_cntr, 254	; We want to start this counter to make a delay for voltage stabilizing
		;mov voltage_min, lowbat_cntr	; store big (255) value. Variable will be updated later
		mov sym_H_cntr, z1	; init variable
#if !defined(NOCONFIG)
		in OSCCAL_nom, OSCCAL		; preserve nominal frequency calibration value
#endif
		
		; change speed (ensure 9.6 mhz ossc)
		ldi tmp, 1<<CLKPCE	
		out CLKPR, tmp		; enable clock change
		out CLKPR, z0		; prescaler 1
		
#if !defined(NOCONFIG)
		rcall WDT_off		; just in case it left on after software reset
#endif

		; Configure Video pin as OUTPUT (LOW)
		sbi	DDRB, VIDEO_PIN
		; Enable pullup on Configure Pin. We will enter configure mode if this pin will go LOW (by PCINT interrupt)
		sbi	PORTB, CONF_PIN
		
#if !defined(NOCONFIG)
		rcall EEPROM_read_settings
#endif
		
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

#if defined(PILOTNAME)		
		rcall FillPilotNameBuffer
#endif

		; Wait for voltage stabilizing and ADC warmup
strt_wt:sbic ADCSRA, ADSC
		rjmp strt_wt
		; ADC is ready
		rcall ReadVoltage
		dec lowbat_cntr
		brne strt_wt	; read ADC 255 times
		; now our voltage and voltage_min is messed. Lets reset at least voltage_min.
		ldi voltage_min, 255
		
		sei ; Enable interrupts

main_loop:
		; in the main loop we can run only not timing critical code like ADC reading


#if !defined(NOCONFIG)
		; Do we need to enter Configure mode?
		sbis PINB, CONF_PIN
		rcall EnterCommandMode
#endif
		sleep
		cpi TV_lineL, 30		; first 30 lines is non-printing lines. Timing there is not critical
		cpc TV_lineH, z0
		brsh main_loop		; only read adc while first non-printing TV lines
		; read ADSC bit to see if conversion finished
		sbis ADCSRA, ADSC
		rcall ReadVoltage
		rjmp main_loop				
		
#if !defined(NOCONFIG)
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
#else
; If no CINFIG feature, then we need only OverclockMCU function
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
#endif

#if defined(PILOTNAME)
FillPilotNameBuffer:
		ldi ZL, low(PilotNameCharsAddrs << 1)
		ldi ZH, high(PilotNameCharsAddrs << 1)
		ldi YL, low(buff_addr3)
		clr YH
		ldi tmp, PILOTNAME_LEN + 2
FPNB1:	lpm tmp1, Z+
		st Y+, tmp1
		dec tmp
		brne FPNB1
		ret

PilotNameCharsAddrs:	; Here we put Characters addresses of Pilot Name
	; Here we have 10 bytes of data. But remember, first 8 chars printed with 7 bit width, 9th char is 2 bits, 10th is again 7 bit.
	; So, to use all 10 bytes in the name, you should put 9th char as dot or space (for example "BADPILOT 1" or "BADPILOT.1")
	.DB symP<<1,symA<<1,symV<<1,symE<<1,symL<<1,symspc<<1,symspc<<1,symspc<<1,symspc<<1,symspc<<1						
#endif
