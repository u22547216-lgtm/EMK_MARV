; -----------------------------------------------------------------------------
; EMK310
; MARV CODE
; TEAM: 28
; MEMBERS: Darius van Niekerk
; Date of last revision: February 2026
;------------------------------------------------------------------------------
; Description: 
;   Code for the MARV of team 28 for EMK 310 in 2026
; -----------------------------------------------------------------------------
; Details:
;	ADC:
;	    Pins:   RA0,1,2,3,5
;	    ADCON0: AN0,1,2,3,4 (binary: 0 00000 00 to 0 00101 00)
;   RGB:
;       Pins:   RA4,6,7 (HIGH turns the colour on)
;       Colours:  R,G,B
;	Register dump:
;	    Port C
;	Colour display:
;	    Port D
;		
; -----------------------------------------------------------------------------

    title	"MARV code"
    PROCESSOR	18F45K22
    
    ; CONFIG1H
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block)
				  ; There is a how-to tutorial on the configuration bits
    CONFIG WDTEN = OFF      ; Turn off the watchdog timer
  
    
    #include    <xc.inc>
    #include    "pic18f45k22.inc"

; variables

delay_inner     equ 0x00
delay_outer     equ 0x01
test_0		equ 0x02
#define test_en	    test_0,7

test_1		equ 0x03
line_reg	equ 0x04
number_of_readings	    equ 0x05

; RGB pins
#define red_pin     PORTA,4
#define green_pin   PORTA,6
#define blue_pin    PORTA,7
; colour indicator pins
#define red_indicator       PORTD,0
#define green_indicator     PORTD,1
#define blue_indicator      PORTD,2
#define black_indicator     PORTD,3
#define white_indicator     PORTD,4

; Sensor storage variables, the adresses here can be used with indirect addressing
     ; name format is [colour flash]_[sensor number]
 red_0		equ 0x00
 red_1		equ 0x01
 red_2		equ 0x02
 red_3		equ 0x03
 red_4		equ 0x04

 green_0		equ 0x06
 green_1		equ 0x07
 green_2		equ 0x08
 green_3		equ 0x09
 green_4		equ 0x0A

 blue_0		equ 0x0B
 blue_1		equ 0x0C
 blue_2		equ 0x0D
 blue_3		equ 0x0E
 blue_4		equ 0x0F

; variables to reduce magic numbers
ADC_AN0		equ 0b00000011 ; 0 00000 1 1
ADC_AN1 	equ 0b00000111 ; 0 00001 1 1
ADC_AN2 	equ 0b00001011 ; 0 00010 1 1
ADC_AN3 	equ 0b00001111 ; 0 00011 1 1
ADC_AN4 	equ 0b00010011 ; 0 00100 1 1

;
; -------------	
; PROGRAM START	
; -------------
;
    PSECT code,abs //Start of main code.
    org	    0x00 			; startup address = 0000h
    goto init
    org     0x08            ; interrupt start
    goto ISR

init:
    MOVLB   0xF		; work in bank 15, not all SFRs are in access bank
    
	; Set oscillator speed at 4 MHz
	bsf 	IRCF0
	bcf	IRCF1
	bsf	IRCF2
    
    ; setup ADC and RGB pins
    CLRF    PORTA,a 	; Initialize PORTA by clearing output data latches
    CLRF    LATA,a	; Alternate method to clear output data latches
    movlw   0b00101111
    movwf   ANSELA,b 	; sets pins A 0,1,2,3 and 5 to analogue     ADC
                        ; also sets pins A 4,6 and 7 to digital     RGB
    movwf   TRISA,a	; sets pins A 0,1,2,3 and 5 to input        ADC
                        ; also sets pins A 4,6 and 7 to outputs     RGB
    ; movlw   0b11010000
    ; movwf   PORTA,a     ; put RGB pins low, powers NPN transistor, turns RGB LEDs on

    ; setup the ADC registers
    ; ADCON0 = x 00000 0 1
    clrf    ADCON0, a	; sets channel to AN0(RA0)
			; makes sure it is not running
    bsf	    ADCON0,0,a	; turns ADC on
    
    ; ADCON1 = 1 xxx 00 00
    clrf    ADCON1, a	; sets voltage references to internal signal
    bsf	    ADCON1,7,a	; set special trigger to CTMU
    
    ; ADCON2 = 0 x 010 010
    clrf    ADCON2,a	; left justified ADC result
    bsf	    ADCON2,2,a	; sets TAD to 1us
    bsf	    ADCON2,5,a	; acquisition time of 8 TAD or 8us
			; ADC works for 8+12* = 20us. ie: 20 instruction cycles.
    ; need to remember the ADC cooldown of 2 TAD, or 2us, which is 2 instruction cycle.
    
    ; setup debug ports(C and D)
    ; register dump port
    clrf    PORTC, a
    clrf    LATC, a
    clrf    ANSELC, b
    clrf    TRISC, a
    
    ; colour show port
    clrf    PORTD, a
    clrf    LATD, a
    clrf    ANSELD, b
    clrf    TRISD, a
    
    ; Set up PORTB
    clrf    PORTB, a
    clrf    LATB, a
    clrf    ANSELB, b
    clrf    TRISB, a
    bsf	    TRISB,1,a	; RB1 is input(INT1I)
    ; clrf    WPUB,a      ; no more weak pull up for PORTB
    
    ; set up interrupts
    ; bcf	    RCON,7,b	; disable priority in interrupts.
    ; just in case some flags are set or some interrupts are enabled when i enable interrupts
    clrf    INTCON,a
    clrf    INTCON2,a
    clrf    PIE1,a
    clrf    PIE2,a
    clrf    PIE3,a
    clrf    PIE4,a
    clrf    PIE5,a

    ; INTCON2 = 0b 0 0 0 0 x 0 x 0 
    ; bsf	    INTCON2,7,a	; no RBPU
    ; bsf	    INTCON2,5,a	; INT1I reacts on rising edge
    ; INTCON3 = 0b 0 1 x 0 1 x 0 0
    clrf    INTCON3,a	;
    bsf     INT1IP	    ; INT1I priority is high
    bsf	    INT1IE	    ; INT1I is enabled
    ; INTCON = 0b 1 0 0 0 0 0 0 0
    bsf	    GIEH	    ; enable high priority interupts
    ; bsf	    GIEL,a	; enable low priority interupts
    
    MOVLB   0x00	; back to bank 0 for normal opperations
; testing setup		
    bcf	    test_en, a
    btfsc   test_en, a
    goto    test
end_test:
    bcf	    test_en, a
		
start: 	
    
    LFSR    0,010h
    call    read_sensors
    goto    start


    
register_dump:
    movff   line_reg, PORTC     ; put line_reg into PORTC
    bcf	    INT1IF		; clear interrupt flag
    retfie			            ;return from interrupt
    
show_colour:
    
read_sensors:
; setup for indirect adressing
    ; you need to use 'LFSR FSR0, XYZh' before calling this 
    ; X is the bank
    ; YZ is the starting register
;    LFSR 0, 100h ;need to remove, only here for initial creation purposes
    
; shine red
    bsf	    red_pin,a
    call delay_RGB
    
	; testing code, should do nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_all_sensors
	    bra	    $+6
	; end of testing code
    
    call    read_all_sensors
    bcf	    red_pin,a
    
; shine green
    bsf	    green_pin,a
    call delay_RGB
    
	; testing code, should do nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_all_sensors
	    bra	    $+6
	; end of testing code
    
    call    read_all_sensors
    bcf	    green_pin,a
    
; shine blue
    bsf	    blue_pin,a
    call delay_RGB
    
	; testing code, should do nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_all_sensors
	    bra	    $+6
	; end of testing code
    
    call    read_all_sensors
    bcf	    blue_pin,a
    
    return

read_all_sensors:
; read from AN0
    ; ADCON0 = x 00000 1 1
    movlw   ADC_AN0	; select AN0
    
	; testing code, does nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_sensor
	    bra	    $+6
	; end of testing code
    
    call    read_sensor
    
; read from AN1
    ; ADCON0 = x 00001 1 1
    movlw   ADC_AN1	; select AN1
    
	; testing code, does nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_sensor
	    bra	    $+6
	; end of testing code
    
    call    read_sensor
    
; read from AN2
    ; ADCON0 = x 00010 1 1
    movlw   ADC_AN2	; select AN2
    
	; testing code, does nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_sensor
	    bra	    $+6
	; end of testing code
    
    call    read_sensor
    
; read from AN3
    ; ADCON0 = x 00011 1 1
    movlw   ADC_AN3	; select AN3
    
	; testing code, does nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_sensor
	    bra	    $+6
	; end of testing code
    
    call    read_sensor
    
; read from AN4
    ; ADCON0 = x 00100 1 1
    movlw   ADC_AN4	; select AN4
    
	; testing code, does nothing if test_en = 0
	    btfss   test_en,a
	    bra	    $+8
	    call    dummy_read_sensor
	    bra	    $+6
	; end of testing code
    
    call    read_sensor
    
    return
    
read_sensor:
    movwf   extra,a
    movff   number_of_readings, count
    movff   extra, ADCON0	; begin ADC
    
    btfsc   ADCON0,1,a	; check if ADC is done (0)
    bra	    $-2		; no, check again
								    ; adc delay is over by this point, Tacq starts 8TAD
	; testing code, should do nothing if test_en = 0
	    btfsc   test_en,a
	    movff   test_1, ADRESH
	; end of testing code
								    ; 3TAD is done
    movff   ADRESH,POSTINC0	; MOVE ADC result bits <9:2> into FSR0L + 4
				; Increment FSR0
								    ; 5TAD is done
    decfsz  count,a
								    ; 6TAD is done
    bra	    $-20						    ;happens on 7TAD
    bcf	    ADCON0,1,a						    ; shuts ADC down on 8TAD
    
    return
    
calibration:
    LFSR 0, 060h
    ; ; movf    INDF0,w,a ; sensor 0, red shine
    ; addFSR  0, blue_4
    ; movf    INDF0,w,A

    movf    POSTINC0,w,a    ; move red_0 to WREG
    movf    POSTINC0,w,a    ; move red_1 to WREG
    movf    POSTINC0,w,a    ; move red_2 to WREG
    movf    POSTINC0,w,a    ; move red_3 to WREG
    movf    POSTINC0,w,a    ; move red_4 to WREG

    movf    POSTINC0,w,a    ; move green_0 to WREG
    movf    POSTINC0,w,a    ; move green_1 to WREG
    movf    POSTINC0,w,a    ; move green_2 to WREG
    movf    POSTINC0,w,a    ; move green_3 to WREG
    movf    POSTINC0,w,a    ; move green_4 to WREG

    movf    POSTINC0,w,a    ; move blue_0 to WREG
    movf    POSTINC0,w,a    ; move blue_1 to WREG
    movf    POSTINC0,w,a    ; move blue_2 to WREG
    movf    POSTINC0,w,a    ; move blue_3 to WREG
    movf    POSTINC0,w,a    ; move blue_4 to WREG

    ;goto start
    mask    equ 0x50 
    chosen_red	equ 0x51
    chosen_green equ 0x52
    chosen_blue	equ 0x53
    ;Test bits for colours:
    ;Red
    movlw   0b10110111
    movwf   red_0
    movlw   0b10100010
    movwf   red_1
    movlw   0b10110110
    movwf   red_2
    movlw   0b10110001
    movwf   red_3
    movlw   0b10110101
    movwf   red_4
    ;Green
    movlw   0b11011111
    movwf   green_0
    movlw   0b11011010
    movwf   green_1
    movlw   0b11011110
    movwf   green_2
    movlw   0b11011001
    movwf   green_3
    movlw   0b11011101
    movwf   green_4
    
choose_colour:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;New average code
    call    average
    call    red_loop
    call    green_loop
    call    blue_loop
;    call    reload_mask
;    btfsc   chosen_red
;    goto    comp_r0_r1  
;    btfsc   chosen_green
;    goto    comp_g0_g1
;    btfsc   chosen_blue
;    goto    comp_b0_b1
;    goto    choose_colour
average:
;    LFSR    0, 100h
;    movlw   0x0
;    movwf   sensor_0_red
;    movlw   0x4
;    movwf   num_readings
;    ave_sensor_0:
;    movf    POSTINC0,W	;first sensor_0 reading for num_reading = 5. Second sensor_0 reading if num_reading = 4
;    addwf   sensor_0_red
;;    movff   POSTINC0, sensor_0_red   
;    decfsz  num_readings
;    bra	    ave_sensor_0
;    RRCF    sensor_0_red
;    RRCF    sensor_0_red
;    ;RRCF    sensor_0_red
;    goto    ave_sensor_1
;    ave_sensor_1:

;newbetter average calculation. Take sensor readings and divide by two until divided by eight. After each division,
;add sensors in pairs. Do the same after each division.
    ;Test POSTINC0 values
   
;    
;
;    ; Step 2: Store values sequentially using POSTINC0
;    MOVLW   0x11
;    MOVWF   POSTINC0           ; Store 0x11 at myBuffer[0], FSR0 now points to myBuffer+1
;
;    MOVLW   0x22
;    MOVWF   POSTINC0           ; Store 0x22 at myBuffer[1], FSR0 now points to myBuffer+2
;
;    MOVLW   0x33
;    MOVWF   POSTINC0           ; Store 0x33 at myBuffer[2], FSR0 now points to myBuffer+3
;    
;    MOVLW   0x44
;    MOVWF   POSTINC0           ; Store 0x33 at myBuffer[2], FSR0 now points to myBuffer+4

; --- First 40 values (Red sensor) ---
LFSR    0, 100h    ; Load starting address into FSR0
LFSR    1, 160h
LFSR    2, 180h
MOVLW   0b10110010
MOVWF   POSTINC0
MOVLW   0b01101101
MOVWF   POSTINC0
MOVLW   0b11001010
MOVWF   POSTINC0
MOVLW   0b01010101
MOVWF   POSTINC0
MOVLW   0b10001100
MOVWF   POSTINC0
MOVLW   0b11100011
MOVWF   POSTINC0
MOVLW   0b00111001
MOVWF   POSTINC0
MOVLW   0b10010110
MOVWF   POSTINC0
MOVLW   0b01111000
MOVWF   POSTINC0
MOVLW   0b11010100
MOVWF   POSTINC0
MOVLW   0b00101011
MOVWF   POSTINC0
MOVLW   0b10000001
MOVWF   POSTINC0
MOVLW   0b11110000
MOVWF   POSTINC0
MOVLW   0b01001110
MOVWF   POSTINC0
MOVLW   0b10101010
MOVWF   POSTINC0
MOVLW   0b00011100
MOVWF   POSTINC0
MOVLW   0b11000101
MOVWF   POSTINC0
MOVLW   0b01110010
MOVWF   POSTINC0
MOVLW   0b10011011
MOVWF   POSTINC0
MOVLW   0b00110110
MOVWF   POSTINC0
MOVLW   0b11101001
MOVWF   POSTINC0
MOVLW   0b01000111
MOVWF   POSTINC0
MOVLW   0b10100000
MOVWF   POSTINC0
MOVLW   0b00001101
MOVWF   POSTINC0
MOVLW   0b11011110
MOVWF   POSTINC0
MOVLW   0b01100001
MOVWF   POSTINC0
MOVLW   0b10001110
MOVWF   POSTINC0
MOVLW   0b00110011
MOVWF   POSTINC0
MOVLW   0b11100110
MOVWF   POSTINC0
MOVLW   0b01011000
MOVWF   POSTINC0
MOVLW   0b10110111
MOVWF   POSTINC0
MOVLW   0b00100100
MOVWF   POSTINC0
MOVLW   0b11001100
MOVWF   POSTINC0
MOVLW   0b01111011
MOVWF   POSTINC0
MOVLW   0b10010001
MOVWF   POSTINC0
MOVLW   0b00011111
MOVWF   POSTINC0
MOVLW   0b11010010
MOVWF   POSTINC0
MOVLW   0b01001011
MOVWF   POSTINC0
MOVLW   0b10101101
MOVWF   POSTINC0
MOVLW   0b00110000
MOVWF   POSTINC0

; --- Second 40 values (Green sensor) ---
MOVLW   0b01100100
MOVWF   POSTINC0
MOVLW   0b10111001
MOVWF   POSTINC0
MOVLW   0b00101110
MOVWF   POSTINC0
MOVLW   0b11010101
MOVWF   POSTINC0
MOVLW   0b01001000
MOVWF   POSTINC0
MOVLW   0b10100011
MOVWF   POSTINC0
MOVLW   0b00011010
MOVWF   POSTINC0
MOVLW   0b11101100
MOVWF   POSTINC0
MOVLW   0b01110101
MOVWF   POSTINC0
MOVLW   0b10001010
MOVWF   POSTINC0
MOVLW   0b00100001
MOVWF   POSTINC0
MOVLW   0b11011000
MOVWF   POSTINC0
MOVLW   0b01000110
MOVWF   POSTINC0
MOVLW   0b10110001
MOVWF   POSTINC0
MOVLW   0b00111100
MOVWF   POSTINC0
MOVLW   0b11100000
MOVWF   POSTINC0
MOVLW   0b01011110
MOVWF   POSTINC0
MOVLW   0b10010011
MOVWF   POSTINC0
MOVLW   0b00101000
MOVWF   POSTINC0
MOVLW   0b11111010
MOVWF   POSTINC0
MOVLW   0b01100111
MOVWF   POSTINC0
MOVLW   0b10001111
MOVWF   POSTINC0
MOVLW   0b00110101
MOVWF   POSTINC0
MOVLW   0b11010001
MOVWF   POSTINC0
MOVLW   0b01001100
MOVWF   POSTINC0
MOVLW   0b10100110
MOVWF   POSTINC0
MOVLW   0b00011001
MOVWF   POSTINC0
MOVLW   0b11101010
MOVWF   POSTINC0
MOVLW   0b01110000
MOVWF   POSTINC0
MOVLW   0b10000111
MOVWF   POSTINC0
MOVLW   0b00100110
MOVWF   POSTINC0
MOVLW   0b11011011
MOVWF   POSTINC0
MOVLW   0b01000001
MOVWF   POSTINC0
MOVLW   0b10111110
MOVWF   POSTINC0
MOVLW   0b00111010
MOVWF   POSTINC0
MOVLW   0b11100100
MOVWF   POSTINC0
MOVLW   0b01011011
MOVWF   POSTINC0
MOVLW   0b10010111
MOVWF   POSTINC0
MOVLW   0b00101101
MOVWF   POSTINC0
MOVLW   0b11111001
MOVWF   POSTINC0
    
;get values from FSR0 and divide them
   count_1  equ	0x30
   count_2  equ 0x31
   count_3  equ 0x32
return
red_loop:
   movlw    0x14
   movwf    count_1
   movlw    0x0A
   movwf    count_2
   movlw    0x5
   movwf    count_3
   LFSR    0, 100h
loop_1_r:
    BCF     STATUS, 0
    RRCF   INDF0	    ;divide 1st value by 2
    MOVF    POSTINC0, W	    ;move the value to W and increment to next value in FSR0
    MOVWF   INDF1	    ;put the value from W(POSTINC0) into FSR1
    
    BCF     STATUS, 0
    RRCF   INDF0	    ;divide 2nd value by 2
    MOVF    POSTINC0,W	    ;move the value to W and increment to 3rd value for second loop
    ADDWF   POSTINC1	    ;Add the 2nd value to the 1st value moved into FSR1(through INDF1) and increment
			    ;after incrementing, in the second loop the second place will be filled with the value
    DECFSZ  count_1
    goto    loop_1_r
    LFSR    1,160h
    goto    loop_2_r
loop_2_r:
    BCF     STATUS, 0
    RRCF   INDF1
    MOVF    POSTINC1,W
    MOVWF   INDF2
    
    BCF     STATUS, 0
    RRCF    INDF1
    MOVF    POSTINC1,W
    ADDWF   POSTINC2
    
    DECFSZ  count_2
    goto    loop_2_r
    LFSR    2,180h
    LFSR    0, 100h
    goto    loop_3_r
loop_3_r:
    BCF     STATUS, 0
    RRCF    INDF2
    MOVF    POSTINC2,W	;first FSR2 value added back to F and then increment to next value
    MOVWF   INDF0	;load back into FSR0
    
    BCF     STATUS, 0
    RRCF    INDF2
    MOVF    POSTINC2,W
    ADDWF   POSTINC0
    
    DECFSZ  count_3
    goto    loop_3_r
   ;after this loop, the 5 sensors' calibrated colour for red is stored in FSR0 from 100h. Green's values will start at 200h. May change depending on 
   return
green_loop:
    movlw    0x40
   movwf    count_1
   movlw    0x20
   movwf    count_2
   movlw    0x10
   movwf    count_2
    LFSR    0,128h
    loop_1_g:
    RRCF   INDF0	    ;divide 1st value by 2
    MOVF    POSTINC0, W	    ;move the value to W and increment to next value in FSR0
    MOVWF   INDF1	    ;put the value from W(POSTINC0) into FSR1
    
    RRCF   INDF0	    ;divide 2nd value by 2
    MOVF    POSTINC0,W	    ;move the value to W and increment to 3rd value for second loop
    ADDWF   POSTINC1	    ;Add the 2nd value to the 1st value moved into FSR1(through INDF1) and increment
			    ;after incrementing, in the second loop the second place will be filled with the value
    DECFSZ  count_1
    goto    loop_1_g
    goto    loop_2_g
loop_2_g:
    RRCF   INDF1
    MOVF    POSTINC1,W
    MOVWF   INDF2
    
    RRCF   INDF1
    MOVF    POSTINC1,W
    ADDWF   POSTINC2
    
    DECFSZ  count_2
    goto    loop_2_g
    LFSR    0, 105h
    goto    loop_3_g
loop_3_g:
    RRCF    INDF2
    MOVF    POSTINC2	;first FSR2 value added back to F and then increment to next value
;    MOVWF   INDF2?
    
    RRCF   INDF2
    MOVF    POSTINC2,W
    ADDWF   INDF2
    MOVF    POSTINC2,W
    MOVWF   POSTINC0
    
    DECFSZ  count_3
    goto    loop_3_g
    return
blue_loop:
    movlw    0x40
   movwf    count_1
   movlw    0x20
   movwf    count_2
   movlw    0x10
   movwf    count_2
    LFSR    0,150h
loop_1_b:
    RRNCF   INDF0	    ;divide 1st value by 2
    MOVF    POSTINC0, W	    ;move the value to W and increment to next value in FSR0
    MOVWF   INDF1	    ;put the value from W(POSTINC0) into FSR1
    
    RRNCF   INDF0	    ;divide 2nd value by 2
    MOVF    POSTINC0,W	    ;move the value to W and increment to 3rd value for second loop
    ADDWF   POSTINC1	    ;Add the 2nd value to the 1st value moved into FSR1(through INDF1) and increment
			    ;after incrementing, in the second loop the second place will be filled with the value
    DECFSZ  count_1
    goto    loop_1_b
    goto    loop_2_b
loop_2_b:
    RRNCF   INDF1
    MOVF    POSTINC1,W
    MOVWF   INDF2
    
    RRNCF   INDF1
    MOVF    POSTINC1,W
    ADDWF   POSTINC2
    
    DECFSZ  count_2
    goto    loop_2_b
    LFSR    0, 110h
    goto    loop_3_b
loop_3_b:
    RRNCF    INDF2
    MOVF    POSTINC2	;first FSR2 value added back to F and then increment to next value
;    MOVWF   INDF2?
    
    RRNCF   INDF2
    MOVF    POSTINC2,W
    ADDWF   INDF2
    MOVF    POSTINC2,W
    MOVWF   POSTINC0
    
    DECFSZ  count_3
    goto    loop_3_b
    return
    call    reload_mask
    btfsc   chosen_red
    goto    comp_r0_r1  
    btfsc   chosen_green
    goto    comp_g0_g1
    btfsc   chosen_blue
    goto    comp_b0_b1
    goto    choose_colour
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reload_mask:
    movlw       0b11111111        ;
    movwf       mask,a  ; mask red = 0b 1111 1111
    return

comp_r0_r1:
    movf    red_0,w,b
    cpfseq  red_1,b         ; if red_0 = red_1
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_r1_r2      ; yes, go to next compare

    BCF	    STATUS,0
    RLCF    mask,1,0
    movf    mask,w,a    ; move mask red to WREG
    andwf   red_0,f,b       ; cut a bit off red_0
    andwf   red_1,f,b       ; cut a bit off red_1
    goto    comp_r0_r1      ; repeat

comp_r1_r2:
    
    movf    red_1,w,b
    cpfseq  red_2,b         ; if red_1 = red_2
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_r2_r3      ; yes, go to next compare
    
    BCF	    STATUS,0
    RLCF    mask,1,0    ; mask red -> 0b 1111 1110 -> 0b 1111 1100
    movf    mask,w,a    ; move mask red to WREG
    andwf   red_2,f,b       ; cut noise bits off 
    goto    comp_r1_r2

comp_r2_r3:
    movf    red_2,w,b
    cpfseq  red_3,b         ; if red_2 = red_3
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_r3_r4      ; yes, go to next compare
    
    BCF	    STATUS,0
    RLCF    mask,1,0    ; mask red -> 0b 1111 1110 -> 0b 1111 1100
    movf    mask,w,a    ; move mask red to WREG
    andwf   red_3,f,b       ; cut noise bits off 
    goto    comp_r2_r3
comp_r3_r4:
    movf    red_3,w,b
    cpfseq  red_4,b         ; if red_3 = red_4
    bra	    $+10             ; no
    call    reload_mask
    goto    choose_colour      ; yes, go to green compare
    
    BCF	    STATUS,0
    RLCF    mask,1,0    ; mask red -> 0b 1111 1110 -> 0b 1111 1100
    movf    mask,w,a    ; move mask red to WREG
    andwf   red_4,f,b       ; cut noise bits off 
    goto    comp_r3_r4
    
comp_g0_g1:
    movf    green_0,w,b
    cpfseq  green_1,b         ; if red_0 = red_1
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_g1_g2      ; yes, go to next compare

    BCF	    STATUS,0
    RLCF    mask,1,0
    movf    mask,w,a    ; move mask red to WREG
    andwf   green_0,f,b       ; cut a bit off red_0
    andwf   green_1,f,b       ; cut a bit off red_1
    goto    comp_g0_g1      ; repeat
comp_g1_g2:
    movf    green_1,w,b
    cpfseq  green_2,b         ; if red_0 = red_1
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_g2_g3      ; yes, go to next compare

    BCF	    STATUS,0
    RLCF    mask,1,0
    movf    mask,w,a    ; move mask red to WREG
    andwf   green_1,f,b       ; cut a bit off red_0
    andwf   green_2,f,b       ; cut a bit off red_1
    goto    comp_g1_g2      ; repeat
comp_g2_g3:
    movf    green_2,w,b
    cpfseq  green_3,b         ; if red_0 = red_1
    bra	    $+10             ; no
    call    reload_mask
    goto    comp_g3_g4      ; yes, go to next compare

    BCF	    STATUS,0
    RLCF    mask,1,0
    movf    mask,w,a    ; move mask red to WREG
    andwf   green_2,f,b       ; cut a bit off red_0
    andwf   green_3,f,b       ; cut a bit off red_1
    goto    comp_g2_g3      ; repeat
comp_g3_g4:
    movf    green_3,w,b
    cpfseq  green_4,b         ; if red_0 = red_1
    bra	    $+10             ; no
    call    reload_mask
    goto    choose_colour      ; yes, go to next compare

    BCF	    STATUS,0
    RLCF    mask,1,0
    movf    mask,w,a    ; move mask red to WREG
    andwf   green_3,f,b       ; cut a bit off red_0
    andwf   green_4,f,b       ; cut a bit off red_1
    goto    comp_g3_g4      ; repeat
;red_mask = 0b 1111 0000
;   we can use this as a threshold 

;    red_ref equ 0x51
;    movf    red_2,w,B
;    movwf   red_ref,a
;
;    ; colour detection
;        movf    red_mask,w,a
;        andwf   red_0,w,B
;        cmpfseq red_ref,a
;
;; do same for green and blue
;;       green_mask and blue_mask
;
;; simpler code, this just finds the lowest sensor value, we can use as a threshold
;    movf        red_0,w,b       ;assume red 0 is smallest
;    cpfsgt      red_1,b         ;is red 1 smaller?
;    movf        red_1,w,b       ;yes, save red_1
;
;    cpfsgt      red_2,b         ;is red 2 smaller
;    movf        red_2,w,b       ;yes, save red_2
;
;    cpfsgt      red_3,b
;    movf        red_3,w,b
;    
;    cpfsgt      red_4,b
;    movf        red_4,w,b
;
;    movwf       red_ref,a
    
LLI:

flash:
    
delay_333:
; 0.166442 seconds of delay
    movlw   217
    movwf   delay_outer,a
delay_outside:
    movlw   254
    movwf   delay_inner,a
delay_inside:
    decfsz  delay_inner,a
    goto delay_inside
    
    decfsz  delay_outer,a
    goto delay_outside
    
    return
    
delay_RGB:  ; 1.2ms = 1200 instruction cycles
    movlw   151		    ;150 loops  + 1
    movwf   delay_inner,a
delay_rgb_inner:    ; need 8 instruction cycles here
    dcfsnz  delay_inner,a   ;1	    1
    goto    delay_rgb_end   ;2	    3
    nop			    ;1	    4
    nop			    ;1	    5
    nop			    ;1	    6
    goto    delay_rgb_inner ;2	    8
delay_rgb_end:
    return
    
ISR:
    btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
    goto    register_dump   
    
    retfie
    
test:
; this is just a software engineering practice
; basically disecting the code you made, making the input fixed, and seeing if the output is what you expect
; just comment or uncomment what needs to be tested
    
    call    test_register_dump
    
    call    test_read_sensors
    
    call    test_read_all_sensors
    
    call    test_read_sensor
    
    goto end_test
    
test_register_dump:
; setup
    movlw   0b00000100
    movwf   line_reg,a
    bsf	    test_0,3,a
; test
    bsf	    INTCON3,0,a
; verification 
    cpfseq  PORTC,a
    bcf	    test_0,3,a
    return
    
test_read_sensors:
; test values
    LFSR    1, 200h
    movlw   0x0F
    movwf   test_1,a
    movlw   0x00
    addlw   0x11
    movwf   POSTINC1,a
    decfsz  test_1,f,a
    bra	    $-6
; setup
    LFSR    1, 200h
    LFSR    0, 100h
; test
    call read_sensors
; verification
    bsf	    test_0,0,a
    movlw   1
    subwf   FSR1L,f,a
    subwf   FSR0L,f,a
    movf    INDF1,w,a
    cpfseq  INDF0,a
    bcf	    test_0,0,a
    btfss   test_0,0,a
    return
    movlw   0x00
    cpfseq  FSR0L,a
    bra	$-20
    return
    
dummy_read_all_sensors:
    movlw   0x05
    movwf   test_1,a
    movff   POSTINC1, POSTINC0
    decfsz  test_1,f,a
    bra	    $-6
    return
    
test_read_all_sensors:
; test values
    LFSR    1, 200h
    movlw   0xC0
    movwf   POSTINC1,a
    movlw   0x30
    movwf   POSTINC1,a
    movlw   0x0C
    movwf   POSTINC1,a
    movlw   0x03
    movwf   POSTINC1,a
    movlw   0xFF
    movwf   POSTINC1,a
; setup
    LFSR    1, 200h
    LFSR    0, 100h
; test
    call    read_all_sensors
; verification
    bsf	    test_0,1,a
    movlw   1
    subwf   FSR1L,f,a
    subwf   FSR0L,f,a
    movf    INDF1,w,a
    cpfseq  INDF0,a
    bcf	    test_0,0,a
    btfss   test_0,0,a
    return
    movlw   0x00
    cpfseq  FSR0L,a
    bra	$-20
    return
    
dummy_read_sensor:
    movff   POSTINC1, POSTINC0
    return
    
test_read_sensor:
; test values
    movlw   0b11010010
    movwf   test_1,a
; setup
    LFSR    0, 100h
    movlw   ADC_AN1
; test
    call    read_sensor
;verification
    movlw   -1
    movf    PLUSW0,w,a
    cpfseq  test_1,a
    bra	    1
    bsf	    test_0,2,a
    
    return
    
    end			