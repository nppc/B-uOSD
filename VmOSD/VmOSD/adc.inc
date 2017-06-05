/*
 * adc.inc
 *
 *  Created: 04-Jun-17
 *   Author: Pavel
 */ 

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
		inc adc_cntr
		; check adc_cntr. Did we collected all data?
		ldi, tmp, 64
		cp adc_cntr, tmp
		brlo adc_exit	; continue to accumulate ADC readings
		; data is ready for converting
		clr adc_cntr	; reset counter
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
adc_4:	mov voltage, tmp2	; now we have beautiful result for printing
adc_exit:
		ret
				