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
; * You should have received a copy of the GNU General Public License
; * along with Cleanflight.  If not, see <http://www.gnu.org/licenses/>.


; ADC reading
; We come to this routine after ADC conversion is finished
; First we need to accumulate 64 ADC 10 bit readings.
; Then we will divide the sum by 16 getting 12 bit ADC! (aka Oversampling)
; At the end we will convert ADC value to volts (actually volts*10 for easy printing)
ReadVoltage:
		; read current ADC
		in tmp, ADCL
		in tmp1, ADCH
		sbi ADCSRA, ADSC		; start new conversion
		; accumulate readings
		add adc_sumL, tmp
		adc adc_sumH, tmp1
		dec adc_cntr
		; check adc_cntr. Did we collected all data?
		brne adc_exit	; continue to accumulate ADC readings
		; data is ready for converting
		ldi adc_cntr, 64	; reset counter
		; Oversamping the result(divide by 16)
		; But actually we divide only by 2, to preserve precision in integer math
		lsr adc_sumH
		ror adc_sumL
		; Now we use constant VOLT_DIV_CONST.
		; And to get voltage (Vin*10) we divide ADC Oversampled value by our calculated constant 
		ldi tmp, VOLT_DIV_CONST
		clr tmp2	; result will be here
adc_L1:	cp adc_sumL, tmp
		cpc adc_sumH, z0
		brlo adc_3
		inc tmp2
		sub adc_sumL, tmp
		sbc	adc_sumH, z0
		rjmp adc_L1
adc_3:	; now we have reminder in adc_sumL. Lets add it to the final result
		lsr tmp	; divide constant by 2
		cp adc_sumL, tmp
		brlo adc_4
		inc tmp2	; add 1 (actually it is 0.1) to the result if reminder is 0.5 or greather
adc_4:	;apply voltage adjustment
		lds tmp, Bat_correction
		add tmp2, tmp
		; return voltage for OSD 
		mov voltage, tmp2	; now we have beautiful result for printing
		; check for minimal detected voltage
		cp voltage, voltage_min
		brsh adc_nomin
		mov voltage_min, voltage
adc_nomin:
		; check for low-voltage
		lds tmp, Bat_low_volt
		cp voltage, tmp 
		brsh adc_exit
		cpi lowbat_cntr, 255
		brne adc_exit
		ldi lowbat_cntr, 254		; start low-bat blink
adc_exit:
		ret
				
