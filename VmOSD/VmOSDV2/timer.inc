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

WDT_Start:	; with interrupt behaviour
		ldi   tmp1, (0<<WDE) | (1<<WDTIE) | (0<<WDP3) | (1<<WDP2) | (1<<WDP1) | (0<<WDP0)		; 1s
WDT_Start_code:
		wdr		; Reset Watchdog Timer
		; Start timed sequence
		in    tmp, WDTCR
		ori   tmp, (1<<WDCE) | (1<<WDE)
		out   WDTCR, tmp
		; --  Got four cycles to set the new values from here -
		out   WDTCR, tmp1
		
		clr timer_secs
		clr timer_mins
		clr timer_flag
		ret
		

; proccess timer here
Timer:
		; should we need to advance timer?
		cp timer_flag, z0
		breq Timer_exit
		
		mov tmp, timer_secs
		mov tmp1, timer_mins
		inc tmp
		cpi tmp, 60
		breq TmrMins
Tmr_cont:
		mov timer_secs, tmp
		mov timer_mins, tmp1
		clr timer_flag		
Timer_exit:
		ret		

TmrMins:
		inc tmp1
		clr tmp
		rjmp Tmr_cont

