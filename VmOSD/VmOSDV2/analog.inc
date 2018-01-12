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

; Here we come every time when any H/V sync is came.
; We need first determine is this Hsync (new line) or Vsync (new frame)
; seems easier way is just to measure delay between pulses to determine Hsync or Vsync. It will cost us 1 tvline.
; Our watchdog (independent from osccal) is occupied already, so, we need to work with normal timers.
; So, now we should take care about timing while capturing syncs.
; If timer overflows (more that 50us) then we captured first line

ANA_COMP:
		; we should be very accurate here with timing
		in r_sreg, SREG
		; first read capture flag 
		in itmp1, TIFR0
		; we will use the timer without the interrupt. Just reset it every time we enter ANA_COMP
		; restart the HW timer
		ldi itmp, 1<<PSR10
		out GTCCR, itmp		; reset prescaller
		out TCNT0, z0		; reset timer counter
		ldi itmp, 1<<OCF0A
		out TIFR0, itmp		; Clear Output Compare flag of the timer
		; now check flags, did we got H/V syncs?
		; V syncs occurs multiple times, so, we need to wait while all short syncs (less than 50us) are gone.
		andi itmp1, 1<<OCF0A		; check for overflow flag. If set, then we are in printing area. (we check Z flag. Z flag is set, when OCF0A is 0)
		breq vsout_newpage	; check Z flag and jump if 1...
		; we are in printing area, so, proceed to tvout routine
		rcall TVOUT
ana_cmp_exit:		
		out SREG, r_sreg
		reti

; new page routine
vsout_newpage:
		clr TV_lineL
		clr TV_lineH
		; initialize pointer for OSD print data structure
		ldi ZL, LOW(OSDdata << 1)
		ldi ZH, HIGH(OSDdata << 1)
		rjmp ana_cmp_exit		; exit
