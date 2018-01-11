; Calibrate Compare Match value for capturing video sync signal
OCR0A_Calibration:
		ldi   tmp1, (0<<WDE) | (1<<WDTIE) | (0<<WDP3) | (0<<WDP2) | (0<<WDP1) | (0<<WDP0)		; 16ms (16000us)
		rcall WDT_Start_code
		;count timer0 ticks for while 16ms.
		cli					; we don't want any interrupts now
		ldi tmp, 1<<CS02 | 0<<CS01 | 1<<CS00	; 1024 prescaller (at 13Mhz it overflows after about 20ms)
		out TCCR0B, tmp
		ldi itmp, 1<<PSR10
		out GTCCR, itmp		; reset prescaller
		out TCNT0, z0		; reset timer counter
		wdr					; reset watchdog
		; now wait for watchdog interrupt flag
wt_calib:
		in tmp, WDTCR
		andi tmp, 1<<WDTIF
		brne wt_calib
		; now lets see how much we got in timer0 counter
		in tmp1, TCNT0
		; we need to convert this number to about 50us at timer prescaller 8 
		; the formula is:
		;50us = 0.00005s
		;16ms = 0,016s
		;(0,00005 * N * 1024) / 0,016/8
		;(512 * N) / 160 / 8
		;8 * N / 20
		;2*N/5
		clr tmp2		; prepare high byte for 16 bit number
		lsl tmp1		; multiply by 2
		rol tmp2
		; div by 5
		clr tmp 		; counter (result)
wt_calib_div:
		subi tmp1, 5
		sbc tmp2, z0
		inc tmp
		cpi tmp1,5
		cpc tmp2, z0
		brsh wt_calib_div
		; final value for OCR0A in tmp 

		; store final value to EEPROM for debugging
		; Set Programming mode
		ldi tmp1, (0<<EEPM1)|(0<<EEPM0)
		out EECR, tmp1
		; Set up address 
		ldi tmp1, 5
		out EEARL, tmp1
		out EEDR,tmp		; Write data
		sbi EECR,EEMPE
		sbi EECR,EEPE		

		sei
		ret