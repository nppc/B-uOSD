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
		;sbic EECR, EEPE
		;rjmp EEPROM_write 
		; Set Programming mode
		out EECR, z0
		out EEARL, tmp1	; address
		out EEDR, tmp	; data
		; Write logical one to EEMPE
		sbi EECR, EEMPE
		; Start eeprom write by setting EEPE
		sbi EECR, EEPE
		; Wait until write is finished
EE_wrL:	sbic EECR, EEPE
		rjmp EE_wrL 
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