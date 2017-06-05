;*****    Registers    *****
; tmp - general temp register
; tmp1 - bit counter
; tmp2 - Received value

.equ	BAUD 		 = 19200 	; bps

;DELAY_COUNT is used in delay loop 
;pure cycles necessary per bit
.equ	DELAY_C = CRYSTAL_FREQ / BAUD			
.equ 	DELAY_COUNT	= (DELAY_C - 23) / 6	; this is more correct

; throw error if we're out of bounds
.if DELAY_COUNT > 255
	.error "Baud rate too low for this clock speed!"
.elif DELAY_COUNT <= 0
	.error "Baud rate too high for this clock speed!"
.endif

		
; UART -> tmp2
UART_get_byte:	
		push tmp
		ldi tmp1, 9			;8 data bit + 1 stop bit

uart_wait_for_start:	
		sbic PINB, CONF_PIN	
		rjmp uart_wait_for_start
		;synchronize for 0.5 bit length
		rcall UART_delay	

uart_get_bit:	
		rcall UART_delay	
		rcall UART_delay		

		clc			
		sbic PINB, CONF_PIN	
		sec			
		
		dec tmp1		
		breq uart_bit_done	
					
		ror tmp2		
		rjmp uart_get_bit	

uart_bit_done:	
		pop tmp
		ret

; 3·DELAY_COUNT + 7 cycles (including rcall(3) and ret(4))
UART_delay:	
		ldi tmp, DELAY_COUNT		;1
UART_delay1:	
		dec	tmp						;1
		brne UART_delay1			;2
		ret							;4

	
EnterCommandMode:
		cli	; disable interrupts (no TVout) due to critical timing on UART transmission
		; We first receive 0x55, to enable Serial
		; wait until port stabilize (all 0x55 char is received)
		rcall SA_Wait_Transfer_Compelted
		; Now wait for characters
		; One is Parameter, other three is number 000
		; we can reuse buff_data buffer to receive data
		ldi tmp, 4		; receive 4 bytes
		ldi Zl, low(buff_data)
SA_LB:	rcall UART_get_byte
		st Z+, tmp2
		dec tmp
		brne SA_LB
		; Parse buffer
		; Available commands:
		;  XXXX - Exit from Command mode
		;  SSSS - Save settings to EEPROM
		;  Lnnn - Set start TV line number for printed text
		;  Cnnn - Set TV column number for printed text
		;  Vnnn - Battery voltage correction
		;  RRRR - Reset to Factory settings
		;  TTTT - Test settings (show OSD for 5 seconds)
		ldi Zl, low(buff_data)
				


SA_Exit:	; exit from command mode
		sei		; enable TVout
		ret

SA_Wait_Transfer_Compelted:
SA_L1:	clr tmp			; about 20-30ms
		clr tmp1
SA_L2:	sbis PINB, CONF_PIN
		rjmp SA_L1				; start over, transmision is not finished
		dec  tmp1
		brne SA_L2
		dec  tmp
		brne SA_L2
		ret
