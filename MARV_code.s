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
;SENSOR STORAGES TO BE USED IN LLI
;
;	SENSOR0        EQU 0x55
;	SENSOR1        EQU 0x56
;	SENSOR2        EQU 0x57
;	SENSOR3        EQU 0x58
;	SENSOR4        EQU 0x59
;		
; -----------------------------------------------------------------------------

    title	"MARV code"
    PROCESSOR	18F45K22
    
    ; CONFIG1H
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block)
				  ; There is a how-to tutorial on the configuration bits
    CONFIG WDTEN = OFF      ; Turn off the watchdog timer
    
    CONFIG  MCLRE = EXTMCLR
    CONFIG  LVP	= ON
    
    CONFIG  BOREN = SBORDIS
    CONFIG  BORV = 190 
  
    
    #include    <xc.inc>
    #include    "pic18f45k22.inc"

; variables

delay_inner     equ 0x00
delay_outer     equ 0x01


test_0		equ 0x02
#define test_en	    test_0,7
#define live_test	    test_0,6

test_1		equ 0x03

line_reg	equ 0x04
number_of_readings	    equ 0x05
	    
; state machine bits
state_0		equ 0x06
#define calibrate	state_0,0
#define follow_line	state_0,1
#define code_tests	state_0,2
#define hardware_tests	state_0,3

; sub-routine bits
subroutine_0	equ 0x07
#define delay_333_call	    subroutine_0,0  ;166ms
#define RGB_delay_call	    subroutine_0,1  ;1.2ms
	
#define read_sensors_call   subroutine_0,2
#define check_colour	    subroutine_0,3
	
#define show_the_colours    subroutine_0,4
#define	flash_port_d	    subroutine_0,5
#define button_press_check  subroutine_0,6
	    
	    
calibrated_color    equ 0x0E	
offset_stuff	equ 0x0F
reading_count	equ 0x10
count		equ 0x11
;   dont use address 0x13, strange things afoot
extra		equ 0x19


SENSOR_START	equ 059h
SENSOR0        EQU 0x59
SENSOR1        EQU 0x5A
SENSOR2        EQU 0x5B
SENSOR3        EQU 0x5C
SENSOR4        EQU 0x5D
RACE_COLOUR    EQU 0x5E
BLACK_FLAG     EQU 0x5F

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

calib_address	equ 100h
	
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
	
	; config because of LVP change
	bsf	TRISE,3,a
    
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
    bsf	    TRISB,6,a	; just in case programmer for debugging is complaining
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
    movlw   1
    movwf   number_of_readings,a
    clrf    calibrated_color,a
    clrf    test_0,a
    clrf    SENSOR0,a
    clrf    SENSOR1,a
    clrf    SENSOR2,a
    clrf    SENSOR3,a
    clrf    SENSOR4,a
    clrf    RACE_COLOUR,a
; testing setup		
    bcf	    test_en, a
    btfsc   test_en, a
    goto    test
end_test:
    bcf	    test_en, a
    
STATE_MACHINE_SETUP:
    CLRF    state_0,a
    CLRF    subroutine_0,a
    
    ; State activation bits
    ;BSF calibrate,a
    ;BSF follow_line,a
    
	; tests
    ; BSF code_tests,a
    ; BSF hardware_tests,a
    
    ; Subroutine activation bits
    ;BSF delay_333_call,a
    ;BSF RGB_delay_call,a
    ;BSF read_sensors_call,a
    ;BSF check_colour,a
    ;BSF show_the_colours,a
    ;BSF flash_port_d,a
    ;BSF button_press_check,a
    
STATE_MACHINE_START:
		
STATE0:
    BTFSS   calibrate,a
    GOTO    STATE1
    
    calibration:
	;desperate times
	LFSR    0, 100h
	movlw   1
	movwf   number_of_readings,a
	bsf	    red_indicator,a

	call    wait_for_button_press
	call    read_sensors

	red_thresh	    equ	0x40

	lfsr    0, 100h
	movf    INDF0,w,a    ;sensor 0

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	MOVWF   red_thresh,a
	movlw   10
	subwf   red_thresh,f,a

	;green
	lfsr    0, 100h
	bcf	    red_indicator,a
	bsf	    green_indicator,a

	call    wait_for_button_press
	call    read_sensors

	green_thresh	    equ	0x41

	lfsr    0, 105h
	movf    INDF0,w,a    ;sensor 0

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	MOVWF green_thresh,a
	movlw   10
	subwf   green_thresh,f,a

	;blue
	lfsr    0, 100h
	bcf	    green_indicator,a
	bsf	    blue_indicator,a

	call    wait_for_button_press
	call    read_sensors

	blue_thresh	    equ	0x42

	lfsr    0, 10Ah
	movf    INDF0,w,a    ;sensor 0

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	MOVWF blue_thresh,a
	movlw   10
	subwf   blue_thresh,f,a

	;black
	lfsr    0, 100h
	bcf	    blue_indicator,a
	bsf	    black_indicator,a

	call    wait_for_button_press
	call    read_sensors

	black_thresh    equ 0x43

	lfsr    0, 100h
	movf    INDF0,w,a    ;sensor 0


	cpfsgt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 0
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 0
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfsgt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	movwf   black_thresh,a
	movlw   10
	subwf   black_thresh,f,a
	;white
	lfsr    0, 100h
	bcf	    black_indicator,a
	bsf	    white_indicator,a

	call    wait_for_button_press
	call    read_sensors

	white_thresh    equ 0x44

	lfsr    0, 100h
	movf    INDF0,w,a    ;sensor 0

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 0
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 0
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 1
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 2
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 3
	bra	    $+4
	movf    INDF0,w,a

	cpfslt  PREINC0,a	    ;s 4
	bra	    $+4
	movf    INDF0,w,a

	movwf   white_thresh,a
	movlw   10
	subwf   white_thresh,f,a

	setf    PORTD,a
	call    wait_for_button_press

	call    detect_colour

    ; calibrated colour
	movff   SENSOR2,RACE_COLOUR
	clrf    PORTD,a

	movlw   'R'
	cpfseq  RACE_COLOUR,a
	bra	    $+8
	bsf	    red_indicator,a
	goto    display_race_colour

	movlw   'G'
	cpfseq  RACE_COLOUR,a
	bra	    $+8
	bsf	    green_indicator,a
	goto    display_race_colour

	movlw   'B'
	cpfseq  RACE_COLOUR,a
	bra	    $+8
	bsf	    blue_indicator,a
	goto    display_race_colour

	movlw   'K'
	cpfseq  RACE_COLOUR,a
	bra	    $+8
	bsf	    black_indicator,a
	goto    display_race_colour

	bsf	    white_indicator,a

	display_race_colour:

	call flash
	call wait_for_button_press

	return
    
    
TRANSITION0:
    BCF	    calibrate,a
    BSF	    follow_line,a
    
    		
STATE1:
    BTFSS   follow_line,a
    GOTO    STATE2
    
    LLI:
	nop	;this is just here to see it in the navigator
    ; 5 sensors --> left sensor (LL), middle left sensor (ML), middle sensor (M), middle right sensor (MR), right sensor (RR)

    ;go straight --> M detects line
    ;turn left 	--> LL or ML detects line
    ;turn right --> RR or MR detects line
    ;if all the sensors detect white STOP (SOS MODE). 
	    ;Suggestion: turn 90 degrees to the left and see if the sensors detect the line. If not go back to previous position (-90 degrees)
				    ;turn 90 degrees to the right and see if the sensors detect the line.
				    ;One of these two actions should detect the intended line and thus follow the original line-intepreter algorithm
    ; if all sensor detect black, STOP (End of maze)

	STRAIGHT:
	    call detect_colour
	    
	    MOVF    RACE_COLOUR,W,a
	    SUBWF   SENSOR0,W,a
	    BZ	    TURN_LEFT_ALOT
	    
	    MOVF    RACE_COLOUR,W,a
	    SUBWF   SENSOR1,W,a
	    BZ	    TURN_LEFT_ALITTLE
	    
	    MOVF    RACE_COLOUR,W,a
	    SUBWF   SENSOR3,W,a
	    BZ	    TURN_RIGHT_ALITTLE
	    
	    MOVF    RACE_COLOUR,W,a
	    SUBWF   SENSOR4,W,a
	    BZ	    TURN_RIGHT_ALOT
	    
	    MOVF    RACE_COLOUR,W,a
	    SUBWF   SENSOR2,W,a
	    BNZ	    CHECK_BLACK
	    
	    MOVLW   0b00100000
	    MOVWF   line_reg,a
	    RETURN
	TURN_LEFT_ALOT:
	    MOVLW 0b10000000
	    MOVWF line_reg,a
	    RETURN
	TURN_LEFT_ALITTLE:
	    MOVLW 0b01000000
	    MOVWF line_reg,a
	    RETURN
	TURN_RIGHT_ALOT:
	    MOVLW 0b00001000
	    MOVWF line_reg,a
	    RETURN
	TURN_RIGHT_ALITTLE:
	    MOVLW 0b00010000
	    MOVWF line_reg,a
	    RETURN
	LOST:
	    CALL LOST_STOP
	    CALL TURN_LEFT_ALOT
		;call    wait_for_button_press	; this is here for the purposes of the demo
	    BRA STRAIGHT
	    RETURN
	    
	    LOST_STOP:
		CALL BRAKES
		CALL delay_333
		    ;call    wait_for_button_press	; this is here for the purposes of the demo
		CLRF line_reg,a
		RETURN
         
	BRAKES:
	    MOVLW 0b11111000
	    MOVWF line_reg,a
	    RETURN   
	    
	CHECK_BLACK:
	    MOVLW   'K'
	    CPFSEQ   SENSOR0,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,0,a
	    MOVlW   'K'
	    CPFSEQ   SENSOR1,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,1,a
	    MOVLW   'K'
	    CPFSEQ   SENSOR3,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,2,a
	    MOVLW   'K'
	    CPFSEQ   SENSOR4,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,3,a
	    MOVLW   'K'
	    CPFSEQ   SENSOR2,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,4,a
	    MOVLW   0b00011111
	    CPFSEQ  BLACK_FLAG,a
	    RETURN
	    BRA	    BRAKES
    
TRANSITION1:
    BSF	    follow_line,a   ;LOOP OVER LLI

		
STATE2:
    BTFSS   code_tests,a
    GOTO    STATE3
    
    TODO_code_tests: ; to-do todo to do
	nop
;   state 2 code
    ; to be added later
    
TRANSITION2:
    BCF	    code_tests,a
    
    		
STATE3:
    BTFSS   hardware_tests,a
    GOTO    SUBROUTINE0
    
    TODO_hardware_tests: ; to-do todo to do
    nop
;   state 2 code
    ; to be added later
    
TRANSITION3:
    BCF	    hardware_tests,a 
    
;==========SUBROUTINES=======================
    
TRY_ALL_SUBROUTINES:
    
SUBROUTINE0:
    BTFSS   delay_333_call,a
    GOTO    SUBROUTINE1
    
    delay_333:
	movwf    extra,a
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

	movf    extra,w,a
    
SUB_TRANSITIONS0:
    BCF	    delay_333_call,a
	return
    
        
SUBROUTINE1:
    BTFSS   RGB_delay_call,a
    GOTO    SUBROUTINE2
    
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
    
SUB_TRANSITIONS1:
    BCF	    RGB_delay_call,a
	return
    
        
SUBROUTINE2:
    BTFSS   read_sensors_call,a
    GOTO    SUBROUTINE3
    
    TODO_make_states_with_this: ; to-do todo to do
    nop
    
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

    BCF	    read_sensors_call,a
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
		movff   number_of_readings, delay_outer
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
		decfsz  delay_outer,a
										; 6TAD is done
		bra	    $-20						    ;happens on 7TAD
		bcf	    ADCON0,1,a						    ; shuts ADC down on 8TAD

		return
    
SUB_TRANSITIONS2:
    BCF	    read_sensors_call,a
    
        
SUBROUTINE3:
    BTFSS   check_colour,a
    GOTO    SUBROUTINE4
    
    TODO_make_this_work_with_states_1:  ; to-do todo to do
    nop
    
    detect_colour:
	clrf    SENSOR0,a
	clrf    SENSOR1,a
	clrf    SENSOR2,a
	clrf    SENSOR3,a
	clrf    SENSOR4,a
	; desperate times
	LFSR    0, 200h	
	call read_sensors

	LFSR    0, 200h	

	white_check:
	    red_check_bits  equ	0x45
	    ;sensor 0
	    clrf	red_check_bits,a

	    movf    red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,0,a


	    movf    red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,1,a

	    movf    red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,2,a

	    movf    red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,3,a

	    movf    red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,4,a


	    green_check_bits  equ	0x46
	    ;sensor 0
	    clrf	green_check_bits,a
	    movf    green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,0,a


	    movf    green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,1,a

	    movf    green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,2,a

	    movf    green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,3,a

	    movf    green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,4,a




	    blue_check_bits  equ	0x47
	    ;sensor 0
	    clrf	blue_check_bits,a
	    movf    blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,0,a

	    movf    blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,1,a

	    movf    blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,2,a

	    movf    blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,3,a

	    movf    blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,4,a

	    ;checking colours
	    check	equ 0x48
	    CLRF    check,a
	    ;check sensor 0
	    btfsc   red_check_bits,0,a
	    bsf     check,0,a
	    btfsc   green_check_bits,0,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,0,a
	    bsf     check,2,a

	    lfsr    1,059h
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    movlw	'W'
	    movwf	INDF1,a

	    CLRF    check,a
	    ;check sensor 1
	    btfsc   red_check_bits,1,a
	    bsf     check,0,a
	    btfsc   green_check_bits,1,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,1,a
	    bsf     check,2,a

	    lfsr    1,05Ah
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    movlw	'W'
	    movwf	INDF1,a

	    CLRF    check,a
	    ;check sensor 2
	    btfsc   red_check_bits,2,a
	    bsf     check,0,a
	    btfsc   green_check_bits,2,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,2,a
	    bsf     check,2,a

	    lfsr    1,05Bh
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    movlw	'W'
	    movwf	INDF1,a

	    CLRF    check,a
	    ;check sensor 3
	    btfsc   red_check_bits,3,a
	    bsf     check,0,a
	    btfsc   green_check_bits,3,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,3,a
	    bsf     check,2,a

	    lfsr    1,05Ch
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    movlw	'W'
	    movwf	INDF1,a

	    CLRF    check,a
	    ;check sensor 4
	    btfsc   red_check_bits,4,a
	    bsf     check,0,a
	    btfsc   green_check_bits,4,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,4,a
	    bsf     check,2,a

	    lfsr    1,05Dh
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    movlw	'W'
	    movwf	INDF1,a

	check_green:
	    lfsr	1,200h
	    movlw	5
	    ;addwf	FSR0,f,a
	    addwf	FSR1,f,a

	green_check_bits  equ	0x46
	    ;sensor 0
	    clrf	green_check_bits,a
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,0,a


	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,1,a

	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,2,a

	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,3,a

	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,4,a

	    red_checks:
	    LFSR    1, 200h	

	red_check_bits  equ	0x45

	    clrf	red_check_bits,a
	    btfsc	green_check_bits,0,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,0,a

	    btfsc	green_check_bits,1,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,1,a

	    btfsc	green_check_bits,2,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,2,a

	    btfsc	green_check_bits,3,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,3,a

	    btfsc	green_check_bits,4,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,4,a

	    check_blue:

	    LFSR    1, 200h	
	    movlw	10
	    addwf	FSR1,f,a

	blue_check_bits  equ	0x47

	    clrf	blue_check_bits,a
	    btfss	red_check_bits,0,a
	    btfsc	green_check_bits,0,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,0,a

	    btfss	red_check_bits,1,a
	    btfsc	green_check_bits,1,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,1,a

	    btfss	red_check_bits,2,a
	    btfsc	green_check_bits,2,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,2,a

	    btfss	red_check_bits,3,a
	    btfsc	green_check_bits,3,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,3,a

	    btfss	red_check_bits,4,a
	    btfsc	green_check_bits,4,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,4,a


	    checking_colours:
	    check	equ 0x48
	    CLRF    check,a
	    ;check sensor 0
	    btfsc   red_check_bits,0,a
	    bsf     check,0,a
	    btfsc   green_check_bits,0,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,0,a
	    bsf     check,2,a

	    lfsr    1,059h
	    movlw	'W'
	    cpfseq	SENSOR0,a
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks

	    CLRF    check,a
	    ;check sensor 1
	    btfsc   red_check_bits,1,a
	    bsf     check,0,a
	    btfsc   green_check_bits,1,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,1,a
	    bsf     check,2,a

	    lfsr    1,05Ah
	    movlw	'W'
	    cpfseq	SENSOR1,a
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks

	    CLRF    check,a
	    ;check sensor 2
	    btfsc   red_check_bits,2,a
	    bsf     check,0,a
	    btfsc   green_check_bits,2,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,2,a
	    bsf     check,2,a

	    lfsr    1,05Bh
	    movlw	'W'
	    cpfseq	SENSOR2,a
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks

	    CLRF    check,a
	    ;check sensor 3
	    btfsc   red_check_bits,3,a
	    bsf     check,0,a
	    btfsc   green_check_bits,3,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,3,a
	    bsf     check,2,a

	    lfsr    1,05Ch
	    movlw	'W'
	    cpfseq	SENSOR3,a
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks

	    CLRF    check,a
	    ;check sensor 4
	    btfsc   red_check_bits,4,a
	    bsf     check,0,a
	    btfsc   green_check_bits,4,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,4,a
	    bsf     check,2,a

	    lfsr    1,05Dh
	    movlw	'W'
	    cpfseq	SENSOR4,a
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks
    BCF	    check_colour,a
	return
	    run_detection_checks:
		movlw   0
		cpfseq  check,a
		bra	    $+8
		movlw   'K'
		movwf   INDF1,a
		RETURN

		movlw   1
		cpfseq  check,a
		bra	    $+8
		movlw   'R'
		movwf   INDF1,a
		RETURN

		movlw   2
		cpfseq  check,a
		bra	    $+8
		movlw   'G'
		movwf   INDF1,a
		RETURN

		movlw   4
		cpfseq  check,a
		bra	    $+8
		movlw   'B'
		movwf   INDF1,a
		RETURN

		movlw   'W'
		movwf   INDF1,a

		return

    
SUB_TRANSITIONS3:
        
    
SUBROUTINE4:
    BTFSS   show_the_colours,a
    GOTO    SUBROUTINE5
    
    show_colour:
	movf	SENSOR0,w,a
	andwf	SENSOR1,w,a
	andwf	SENSOR2,w,a
	andwf	SENSOR3,w,a
	andwf	SENSOR4,w,a

	clrf	PORTD,a

	movwf	extra,a
	movlw	'W'
	cpfseq	extra,a
	bra	$+4
	bsf	white_indicator,a

	movlw	'K'
	cpfseq	extra,a
	bra	$+4
	bsf	black_indicator,a

	movlw	'R'
	cpfseq	extra,a
	bra	$+4
	bsf	red_indicator,a

	movlw	'G'
	cpfseq	extra,a
	bra	$+4
	bsf	green_indicator,a

	movlw	'B'
	cpfseq	extra,a
	bra	$+4
	bsf	blue_indicator,a

    
SUB_TRANSITIONS4:
    BCF	    show_the_colours,a
	return
        
    
SUBROUTINE5:
    BTFSS   flash_port_d,a
    GOTO    SUBROUTINE6
    
    flash:
	movlw   3
	movwf   count,a
	movf    PORTD,w,a
	clrf    PORTD,a
	call    delay_333
	movwf   PORTD,a
	call    delay_333
	decfsz  count,a
	bra	    $-14
    
SUB_TRANSITIONS5:
    BCF	    flash_port_d,a
	return
        
    
SUBROUTINE6:
    BTFSS   button_press_check,a
    GOTO    STATE_MACHINE_END
    
    wait_for_button_press:
	btfss   INT0IF	    ;wait for button press
	bra	    $-2
	call    delay_333
	bcf	    INT0IF
    
SUB_TRANSITIONS6:
    BCF	    button_press_check,a
	return
    
    
STATE_MACHINE_END:
    
GOTO    STATE_MACHINE_START   ; LOOP OVER ALL STATES

    
;======INTERRUPTS===========
    
    ISR:
    btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
    goto    register_dump   
    
    retfie


register_dump:
    movff   line_reg, PORTC     ; put line_reg into PORTC
    bcf	    INT1IF		; clear interrupt flag
    retfie			            ;return from interrupt

    
TODO_move_test_code_into_states:  ; to-do todo to do
    nop
    
living_test:
; for tests that happen on the physical PIC
    call    dummy_calibration_values
    
    return
    
run_read_sensors:
    LFSR    0, 100h
    movlw   0x0F
    movwf   count,a
    call read_sensors
    decfsz  count,a
    bra	    $-6
    btfsc   INT0IF
    bcf	    INT0IF
    goto    run_read_sensors


    
test:
; this is just a software engineering practice
; basically disecting the code you made, making the input fixed, and seeing if the output is what you expect
; just comment or uncomment what needs to be tested
    
    call    test_register_dump
    
    call    test_read_sensors
    
    call    test_read_all_sensors
    
    call    test_read_sensor
    
    goto end_test

    
test_colour_detection:
    call    dummy_calibration_values
    call    dummy_calibration
    call    fake_read_sensors
    call    detect_colour
    return

dummy_calibration_values:
    LFSR    1, 300h
    ; red
    movlw   162
    movwf   POSTINC1,a
    movlw   151
    movwf   POSTINC1,a
    movlw   192
    movwf   POSTINC1,a
    movlw   159
    movwf   POSTINC1,a
    movlw   129
    movwf   POSTINC1,a
    
    movlw   116
    movwf   POSTINC1,a
    movlw   90
    movwf   POSTINC1,a
    movlw   115
    movwf   POSTINC1,a
    movlw   104
    movwf   POSTINC1,a
    movlw   97
    movwf   POSTINC1,a
    
    movlw   55
    movwf   POSTINC1,a
    movlw   70
    movwf   POSTINC1,a
    movlw   68
    movwf   POSTINC1,a
    movlw   68
    movwf   POSTINC1,a
    movlw   81
    movwf   POSTINC1,a
    ; green
    movlw   106
    movwf   POSTINC1,a
    movlw   102
    movwf   POSTINC1,a
    movlw   90
    movwf   POSTINC1,a
    movlw   76
    movwf   POSTINC1,a
    movlw   87
    movwf   POSTINC1,a
    
    movlw   247
    movwf   POSTINC1,a
    movlw   245
    movwf   POSTINC1,a
    movlw   234
    movwf   POSTINC1,a
    movlw   244
    movwf   POSTINC1,a
    movlw   246
    movwf   POSTINC1,a
    
    movlw   136
    movwf   POSTINC1,a
    movlw   152
    movwf   POSTINC1,a
    movlw   78
    movwf   POSTINC1,a
    movlw   127
    movwf   POSTINC1,a
    movlw   183
    movwf   POSTINC1,a
; blue
    movlw   50
    movwf   POSTINC1,a
    movlw   56
    movwf   POSTINC1,a
    movlw   64
    movwf   POSTINC1,a
    movlw   63
    movwf   POSTINC1,a
    movlw   59
    movwf   POSTINC1,a
    
    movlw   149
    movwf   POSTINC1,a
    movlw   113
    movwf   POSTINC1,a
    movlw   136
    movwf   POSTINC1,a
    movlw   143
    movwf   POSTINC1,a
    movlw   127
    movwf   POSTINC1,a
    
    movlw   106
    movwf   POSTINC1,a
    movlw   161
    movwf   POSTINC1,a
    movlw   160
    movwf   POSTINC1,a
    movlw   211
    movwf   POSTINC1,a
    movlw   181
    movwf   POSTINC1,a
; black
    movlw   60
    movwf   POSTINC1,a
    movlw   54
    movwf   POSTINC1,a
    movlw   52
    movwf   POSTINC1,a
    movlw   38
    movwf   POSTINC1,a
    movlw   35
    movwf   POSTINC1,a
    
    movlw   126
    movwf   POSTINC1,a
    movlw   76
    movwf   POSTINC1,a
    movlw   102
    movwf   POSTINC1,a
    movlw   112
    movwf   POSTINC1,a
    movlw   79
    movwf   POSTINC1,a
    
    movlw   54
    movwf   POSTINC1,a
    movlw   63
    movwf   POSTINC1,a
    movlw   56
    movwf   POSTINC1,a
    movlw   55
    movwf   POSTINC1,a
    movlw   62
    movwf   POSTINC1,a
; white
    movlw   180
    movwf   POSTINC1,a
    movlw   175
    movwf   POSTINC1,a
    movlw   180
    movwf   POSTINC1,a
    movlw   142
    movwf   POSTINC1,a
    movlw   132
    movwf   POSTINC1,a
    
    movlw   248
    movwf   POSTINC1,a
    movlw   247
    movwf   POSTINC1,a
    movlw   247
    movwf   POSTINC1,a
    movlw   247
    movwf   POSTINC1,a
    movlw   246
    movwf   POSTINC1,a
    
    movlw   203
    movwf   POSTINC1,a
    movlw   246
    movwf   POSTINC1,a
    movlw   211
    movwf   POSTINC1,a
    movlw   214
    movwf   POSTINC1,a
    movlw   246
    movwf   POSTINC1,a

    return

dummy_calibration:
    movlw   'R'
    movwf   calibrated_color,a
    return
    
fake_read_sensors:
    ; FLASH RED
    movlw   180		; W
    movwf   POSTINC1,a
    movlw   151		; R
    movwf   POSTINC1,a
    movlw   52		; K
    movwf   POSTINC1,a
    movlw   76		; G
    movwf   POSTINC1,a
    movlw   59		; B
    movwf   POSTINC1,a
    ; FLASH GREEN
    movlw   248		; W
    movwf   POSTINC1,a
    movlw   90		; R
    movwf   POSTINC1,a
    movlw   102		; K
    movwf   POSTINC1,a
    movlw   244		; G
    movwf   POSTINC1,a
    movlw   127		; B
    movwf   POSTINC1,a
    ; FLASH BLUE
    movlw   203		; W
    movwf   POSTINC1,a
    movlw   70		; R
    movwf   POSTINC1,a
    movlw   56		; K
    movwf   POSTINC1,a
    movlw   127		; G
    movwf   POSTINC1,a
    movlw   181		; B
    movwf   POSTINC1,a
    return
    
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
    bra	    $+2
    bsf	    test_0,2,a
    
    return
    
    end			





