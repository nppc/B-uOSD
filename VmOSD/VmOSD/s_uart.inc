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

; we wait only some milliseconds for start bit. If symbols not arrive, then seems transfer is finished
		rcall wait_for_start_short

		ldi tmp1, 9			;8 data bit + 1 stop bit
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
Cm_wt:	rcall wait_for_start_short	; we should wait for first bit forever...
		cp tmp2, z0
		breq Cm_wt
		; something started to come
		; First byte is Parameter, other three is number 000
		; we can reuse buff_data buffer to receive data
		ldi tmp, 4		; receive 4 bytes
		ldi Zl, low(buff_data)
Cm_LB:	rcall UART_get_byte
		st Z+, tmp2
		dec tmp
		brne Cm_LB
		; Parse buffer
		; Available commands:
		;  XXXX - Exit from Command mode without saving settings to EEPROM
		;  SSSS - Save settings to EEPROM and Exit
		;  Lnnn - Set start TV line number for printed text
		;  Cnnn - Set TV column number for printed text
		;  Vnnn - Battery voltage correction
		;  RRRR - Reset to Factory settings
		;  TTTT - Test settings (show OSD for 5 seconds)
		ldi Zl, low(buff_data)
		ld tmp, Z+
		cpi tmp, 'X'
		breq Cm_Exit
		cpi tmp, 'S'
		breq Cm_Save
		cpi tmp, 'L'
		breq Cm_TVLine
		cpi tmp, 'C'
		breq Cm_TVColumn
		cpi tmp, 'V'
		breq Cm_Battery


Cm_Exit:	; exit from command mode
		sei		; enable TVout
		ret

Cm_Save:
		; save all data to EEPROM and exit
		; because this is very sensitive operation, lets double check it. Check remaining buffer for 'SSS'
		ldi tmp1, 3
Cm_SL1:	ld tmp, Z+
		cpi tmp, 'S'
		brne EnterCommandMode		; Seems command is not 'SSSS' go back to command mode. Save nothing to EEPROM
		dec tmp1
		brne Cm_SL1
		; TODO EEPROM save
		rjmp Cm_Exit

Cm_TVLine:
		;OK Convert remaining buffer to 16bit number
		;-- Check number for allowed range
		;OK Update SRAM variable
		;   Show OSD for 5 seconds
		;OK Go back to Command Mode
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		sts TV_line_start, adc_sumL
		sts TV_line_start+1, adc_sumH
		; TODO
		
		rjmp EnterCommandMode		; go back to Command Mode

Cm_TVColumn:
		;OK Convert remaining buffer to 16bit number
		;-- Check number for allowed range
		;OK Update SRAM variable
		;   Show OSD for 5 seconds
		;OK Go back to Command Mode
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		sts TV_col_start, adc_sumL
		; TODO
		
		rjmp EnterCommandMode		; go back to Command Mode

Cm_Battery:
		;OK Convert remaining buffer to 16bit number
		;-- Check number for allowed range
		;OK Update SRAM variable
		;   Show OSD for 5 seconds
		;OK Go back to Command Mode
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		sts Bat_correction, adc_sumL
		; TODO
		
		rjmp EnterCommandMode		; go back to Command Mode


; Convert 3 bytes from SRAM pointed by Z register to 16bit number (adc_sumL:adc_sumH)
Cm_ConvertBCD16bit:
		clr adc_sumL	; reuse adc variables for storing 16 bit number
		clr adc_sumH	; reuse adc variables for storing 16 bit number
		ld tmp, Z+		; read 100s of number
		andi tmp, 0b00001111	; converd BCD to bin
		; multiply by 100
		ldi tmp1, 50	; multiply by 50
		rcall Cm_multiply
		ld tmp, Z+		; read 10s of number
		andi tmp, 0b00001111	; converd BCD to bin
		; multiply by 10
		ldi tmp1, 5	; multiply by 5
		rcall Cm_multiply
		ld tmp, Z		; read remaining of number
		andi tmp, 0b00001111	; converd BCD to bin
		add adc_sumL, tmp
		adc adc_sumH, z0
		ret
		
; Multiply tmp by (tmp1/2) and add it to adc_sumL:adc_sumH
; we supply half of tmp1 for speed purposes (we first multiply tmp by 2)
Cm_multiply:		
		lsl tmp	; multiply by 2 
Cm_mul1:add adc_sumL, tmp
		adc adc_sumH, z0
		dec tmp1
		brne Cm_mul1
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

; tmp2 returns flag for start bit: 1-start bit, 0-timeout expired
wait_for_start_short:
		mov tmp2,z1		; flag for start bit
		clr tmp			; about 20-30ms
		clr tmp1
wfs_L2:	sbis PINB, CONF_PIN
		rjmp wfs_exit				; transmission started
		dec  tmp1
		brne wfs_L2
		dec  tmp
		brne wfs_L2
		clr tmp2		; clear flag for start bit, because start bit did not came
wfs_exit:
		ret