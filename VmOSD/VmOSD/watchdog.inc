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

 
; ensure, that Interrupts are disabled before calling one of the routines here
WDT_Start_4s:	; with interrupt behaviour
		ldi   tmp1, (0<<WDE) | (1<<WDTIE) | (1<<WDP3) | (0<<WDP2) | (0<<WDP1) | (0<<WDP0)		; 4s
		rjmp WDT_Start_code
WDT_Start_16ms:	; with reset bwhaviour
		ldi   tmp1, (1<<WDE) | (0<<WDTIE) | (0<<WDP3) | (0<<WDP2) | (0<<WDP1) | (0<<WDP0)		; 16ms
WDT_Start_code:
		wdr		; Reset Watchdog Timer
		; Start timed sequence
		in    tmp, WDTCR
		ori   tmp, (1<<WDCE) | (1<<WDE)
		out   WDTCR, tmp
		; --  Got four cycles to set the new values from here -
		out   WDTCR, tmp1
		ret
		
WDT_off:
		wdr		; Reset Watchdog Timer
		; Clear WDRF in MCUSR
		in    tmp, MCUSR
		andi  tmp, (0xff - (1<<WDRF))
		out   MCUSR, tmp
		; Write logical one to WDCE and WDE
		; Keep old prescaler setting to prevent unintentional time-out
		in    tmp, WDTCR
		ori   tmp, (1<<WDCE) | (1<<WDE)
		out   WDTCR, tmp
		; Turn off WDT
		out   WDTCR, z0
		ret
		
;Watchdog interrupt routine here
WATCHDOG:
		;in r_sreg, SREG
		mov adc_cntr,z1		; just update adc variable, because WDT only enabled in Command mode, so, no ADC readings occur
		;out SREG, r_sreg	
		reti
