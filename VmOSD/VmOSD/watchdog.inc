
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
		
WDT_on:

;Watchdog interrupt routine here
WATCHDOG:
		
		reti
