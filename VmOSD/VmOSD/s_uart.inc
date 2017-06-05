;*****    Registers    *****
; tmp - general temp register
; tmp1 - bit counter
; tmp2 - Received value

.equ	BAUD 		 = 9600 	; bps

; hand-picked for easier auto-baud calculations (no division)
.equ	cycles_per_bit 	   = 12 ;without delays + 4*nop(1)
.equ	const_delay_cycles = 9	;rjmp(2) + ret(4) + 2*nop(1)

;DELAY_COUNT is used in delay loop 
;pure cycles necessary per bit
.equ	DELAY_C = CRYSTAL_FREQ / BAUD			
.equ	DELAY_COUNT = (DELAY_C - cycles_per_bit - 2 * const_delay_cycles)/6 ; maybe this is wrong
;.equ 	DELAY_COUNT	= (DELAY_C - 23) / 6	; this is more correct

; throw error if we're out of bounds
.if DELAY_COUNT > 255
	.error "Baud rate too low for this clock speed!"
.elif DELAY_COUNT <= 0
	.error "Baud rate too high for this clock speed!"
.endif

		
;****************************************************
;*****                 GET BYTE                 *****
;****************************************************
; UART -> tmp2
UART_get_byte:	
		ldi 	tmp1, 9			;8 data bit + 1 stop bit

uart_wait_for_start:	
		sbic 	PINB, CONF_PIN	
		rjmp 	uart_wait_for_start
		;synchronize for 0.5 bit length
		rcall 	UART_delay	

; 10 cycles here (without delays)
uart_get_bit:	
		rcall 	UART_delay	
		rcall 	UART_delay		

		clc			
		sbic 	PINB, CONF_PIN	
		sec			
		
		nop	nop nop nop					; not yet sure, maybe we can delete them
		dec 	tmp1		
		breq 	uart_bit_done	
					
		ror 	tmp2		
		rjmp 	uart_get_bit	

uart_bit_done:	
		ret

;****************************************************
;*****                UART DELAY                *****
;****************************************************
; 3*DELAY_COUNT + const_delay_cycles
; 3·DELAY_COUNT + 7 cycles (including rcall(3) and ret(4))
UART_delay:	
		lds		tmp, BAUD_DELAY		;2
UART_delay1:	
		dec		tmp					;1
		brne	UART_delay1			;2
		nop							;1 - not yet sure, maybe we can delete this
		ret							;4

;****************************************************
;*****              UART AUTO-BAUD              *****
;****************************************************
; calculates calc_b after receiving 0x55
; calc_b -> tmp
; intermediate result is DELAY_C/6
; sbis (2) + inc (1) + breq (2) + nop (1)

UART_autocalibrate:
		clr 	tmp
	
uart_cal_wait_start:	
		sbic 	PINB, CONF_PIN	
		rjmp 	uart_cal_wait_start

uart_cal_wait_bit:	
		sbis 	PINB, CONF_PIN	
		rjmp 	uart_cal_wait_bit

uart_measure_bit:
		sbis 	PINB, CONF_PIN		
		rjmp 	uart_calibration_done
		nop
		inc		tmp
		breq	uart_calibration_fail

uart_calibration_done:
		; DELAY_COUNT = DELAY_C/6 - cycles_per_bit/6 - const_delay_cycles/3
		; tmp = DELAY_C/6
		cpi		tmp, cycles_per_bit/6
		brlo	uart_calibration_fail
		subi	tmp, cycles_per_bit/6

		cpi		tmp, const_delay_cycles/3
		brlo	uart_calibration_fail
		subi	tmp, const_delay_cycles/3

		sts		BAUD_DELAY, tmp

uart_calibration_fail:
		ret

	
	
SerialActivity:
		; We first receive 0x55, to autotune serial port
		rcall UART_autocalibrate
		; wait until port stabilize (all 0x55 char is received)
SA_L1:	ldi tmp, 10		; about 1ms
		clr tmp1
SA_L2:	sbis PINB, CONF_PIN
		rjmp SA_L1				; start over, transmision is not finished
		dec  tmp1
		brne SA_L2
		dec  tmp
		brne SA_L2
		; Now wait for character
		cbi PORTB, VIDEO_PIN	; clear VIDEO pin
		rcall UART_get_byte
		ldi tmp, 0x58				; 'X' is received
		cp tmp2, tmp
		brne SA_Exit
		sbi PORTB, VIDEO_PIN	; set VIDEO pin
SA_Exit:ret