/*
 * timer.inc
 *
 *  Created: 04-Jun-17 11:00:27 AM
 *   Author: Pavel
 */ 

; this routines are called from interrupts, so use interrupt registers
stop_timer:
		; actually we only disable interrupt
		out	TIMSK0, z0
		ret

start_timer:
		out TCNT0, z0		; reset counter
		ldi itmp, 1<<OCF0A	; reset interrupt flag
		out TIFR0, itmp
		ldi itmp, 1<<OCIE0A	; enable Compare Match interrupt
		out	TIMSK0, itmp
		; we don't need to reset prescaller, because we use no prescaller :)

		
		ret