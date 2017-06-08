/*
 * Author of B-uOSD is Pavel Palonen
 *
 * B-uOSD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * B-uOSD is distributed WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * this text shall be included in all
 * copies or substantial portions of the Software.
 *
 * You should have received a copy of the GNU General Public License
 * along with Cleanflight.  If not, see <http://www.gnu.org/licenses/>.
 */



;DELAY_COUNT is used in delay loop 
;pure cycles necessary per bit
.equ	DELAY_C = CRYSTAL_FREQ / BAUD			
.equ 	DELAY_COUNT	= (DELAY_C - 23) / 6

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
		ldi ZL, low(buff_data)
		clr ZH
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
		;  TTTT - Test settings (show OSD for 4 seconds)
		ldi ZL, low(buff_data)
		clr ZH
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
		cpi tmp, 'R'
		breq Cm_Factory_reset
		cpi tmp, 'T'
		breq Cm_Show_OSD


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
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		sts TV_line_start, adc_sumL
		sts TV_line_start+1, adc_sumH
		rjmp EnableTVout4sec

Cm_TVColumn:
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		sts TV_col_start, adc_sumL
		rjmp EnableTVout4sec

Cm_Battery:
		; check, does the number contains sign?
		mov tmp2, z1	; assum we have negative number
		ld tmp, Z		; read buffer to determine sign char
		cpi tmp, '-'
		breq Cm_Bneg
		clr tmp2		; no, number is not negative 
Cm_Bneg:
		;now we know the sign of the number, lets convert it to binary
		ldi tmp, '0'
		st Z, tmp
		rcall Cm_ConvertBCD16bit
		; now we have a number in adc_sumL:adc_sumH
		; we need only adc_sumL
		cpse tmp2, z0	;dont make negative
		neg adc_sumL
		sts Bat_correction, adc_sumL
		rjmp Cm_Exit	; Here we exit because to see effect of voltage correction we can only if ADC is read and recalculated in main loop
		
Cm_Factory_reset:
		; because this is very sensitive operation, lets double check it. Check remaining buffer for 'RRR'
		ldi tmp1, 3
Cm_Fr1:	ld tmp, Z+
		cpi tmp, 'R'
		brne Cm_Fr3			; Seems command is not 'RRRR' go back to command mode. Save nothing to EEPROM
		dec tmp1
		brne Cm_Fr1
		rcall EE_Reset_factory
		; initiate a reset
		rcall WDT_Start_16ms
Cm_Fr2:	rjmp Cm_Fr2					; wait until WDT reset
Cm_Fr3:	rjmp EnterCommandMode		; relative branch is too long...

Cm_Show_OSD:
		rjmp EnableTVout4sec
		


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

EnableTVout4sec:
		rcall WDT_Start_4s			; start WDT in interrupt mode
		clr adc_cntr
		sei							; Enable TVout
wt4s:	cp adc_cntr, z0
		breq wt4s
		cli							; Disable TVout
		rcall WDT_off				; disable watchog
		rjmp EnterCommandMode		; go back to Command Mode