/*
 * eeprom.inc
 *
 *  Created: 07-Jun-17 
 *   Author: Pavel
 */ 
Factory_data:	.DW FIRST_PRINT_TV_LINE			; TV Line to print 
				.DB FIRST_PRINT_TV_COLUMN, 0		; TV Col to print and voltage offset

; tmp is value
; tmp1 is address
EEPROM_read:
		; Wait for completion of any previous operations
		sbic EECR, EEPE
		rjmp EEPROM_read
		out EEARL, tmp1
		; Start eeprom read
		sbi EECR, EERE
		; Read data from
		in tmp, EEDR
		ret

EEPROM_write:
		; Wait for completion of any previous operations
		sbic EECR, EEPE
		rjmp EEPROM_write 
		; Set Programming mode
		out EECR, z0
		out EEARL, tmp1	; address
		out EEDR, tmp	; data
		; Write logical one to EEMPE
		sbi EECR, EEMPE
		; Start eeprom write by setting EEPE
		sbi EECR, EEPE
		ret
		
; reset EEPROM to factory settings. After resetting MCU reset (via Watchdog) should be issued.
; before running this routine, ensure that interrupts are disabled
EE_Reset_factory:
		ldi ZL, low(Factory_data << 1)
		ldi ZH, high(Factory_data << 1)
		ldi tmp1, EEPROM_Start		; address in EEPROM
EE_RstL1:
		lpm tmp, Z+
		rcall EEPROM_write
		inc tmp1
		cpi tmp1, EEPROM_Start+4 	; 4 bytes to restore
		brne EE_RstL1
		ret