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
; red_0		equ 0x00
; red_1		equ 0x01
; red_2		equ 0x02
; red_3		equ 0x03
; red_4		equ 0x04

; green_0		equ 0x06
; green_1		equ 0x07
; green_2		equ 0x08
; green_3		equ 0x09
; green_4		equ 0x0A

; blue_0		equ 0x0B
; blue_1		equ 0x0C
; blue_2		equ 0x0D
; blue_3		equ 0x0E
; blue_4		equ 0x0F

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
    
    LFSR    0, 010h
    movlw   0x0F
    movwf   count
    call read_sensors
    decfsz  count
    bra	    $-6
    goto    start

detect_colour:
; putting variables here made for this
    reading_count	equ 0x10
    count		equ 0x11
    colour_ref		equ 0x12
    sensor_val		equ 0x13
    offset1		equ 0x14
    offset2		equ 0x15
    offset3		equ 0x16
    offset4		equ 0x17
    offset5		equ 0x18

		
    LFSR    0, 200h	; will store sensor measurements starting from 200h
    movlw   1		; im making a setup for a loop just in case i want more sensor readings
    movwf   reading_count,a
    movwf   count,a
    
    call read_sensors
    decfsz  count,a
    bra	    $-6
    
    LFSR    0, 200h	; start of sensor reading value
    LFSR    1, 010h	; presumed start of reference values
    LFSR    2, 070h	; presumed start of SENSOR registers for LLI
    
    ; need to offset FSR0 and FSR1 for white
    
    
next_offset:
    ; manages the offset for colour detection
    offsetW		equ 60 ;15*4
    offsetK		equ 45 ;15*3
    offsetR		equ 0
    offsetG		equ 15
    offsetB		equ 30
		
    ;if calibrated colour = red
    
    
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
    movwf   ADCON0,a	; begin ADC
    
    btfsc   ADCON0,1,a	; check if ADC is done (0)
    bra	    $-2		; no, check again
    
	; testing code, should do nothing if test_en = 0
	    btfsc   test_en,a
	    movff   test_1, ADRESH
	; end of testing code
    
    movff   ADRESH,POSTINC0	; MOVE ADC result bits <9:2> into FSR0L + 4
				; Increment FSR0
    bcf	    ADCON0,1,a
    
    return
    
calibration:
    
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





