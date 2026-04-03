; -----------------------------------------------------------------------------
; EMK310
; MARV CODE
; TEAM: 28
; MEMBERS: 
;	    Darius van Niekerk
;	    Owam Bandile Ntlemeza
;	    Elmor Van Der Walt
;	    Bianca Mkhize
; Date of last revision: March 2026
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
;   external interrupts:
;	Pins:	RB0,1
;	Enabled interrupts: RB1
;	Button press to wait for: RB2
;   Register dump:
;	Port C
;   Colour display:
;	Port D
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
#define	touch_start	state_0,4

; sub-routine bits
subroutine_0	equ 0x07
#define delay_333_call	    subroutine_0,0  ;166ms
#define RGB_delay_call	    subroutine_0,1  ;1.2ms
	
#define read_sensors_call   subroutine_0,2
#define check_colour	    subroutine_0,3
	
#define show_the_colours    subroutine_0,4
#define	flash_colour_display	    subroutine_0,5
#define button_press_check  subroutine_0,6
#define colour_display	    subroutine_0,7

; delay skip bits
DELAY_SKIP		equ	0x08
#define skip_delay_333		DELAY_SKIP,0
#define skip_delay_RGB		DELAY_SKIP,1
	    
timer_waits		equ	0x09
#define	wait_for_timer333   timer_waits,0
#define	wait_for_timerRBG   timer_waits,1
	    
calibrated_color    equ 0x0E	
offset_stuff	equ 0x0F
reading_count	equ 0x10
count		equ 0x11
;   dont use address 0x13, strange things afoot
extra		equ 0x19

; RGB control stuff
race_error_colour_magic	    EQU	0X3E
; RGB pins
#define red_pin     PORTA,4
#define green_pin   PORTA,6
#define blue_pin    PORTA,7
; colour indicator offsets in code
DISPLAYED_COLOUR	equ 0x3F
    no_indicator	    EQU 0
    black_indicator	    EQU 2
    white_indicator	    EQU 4
    red_indicator	    EQU 6
    green_indicator	    EQU 8
    blue_indicator	    EQU 10
	    
    race_error_indicator    EQU 12
    error_indicator	    EQU 14
		
; colour detection registers
red_thresh	    equ	0x40
green_thresh	    equ	0x41
blue_thresh	    equ	0x42
	    
black_red_thresh	equ 0x43
black_green_thresh	equ 0x44
black_blue_thresh	equ 0x45
	
white_red_thresh	equ 0x46
white_green_thresh	equ 0x47
white_blue_thresh	equ 0x48
	
red_check_bits	    equ	0x49
green_check_bits    equ	0x4A
blue_check_bits	    equ	0x4B
check		    equ 0x4C
		    
; colour detection tolerances
red_tol		    equ 0x4D
green_tol	    equ 0x4E
blue_tol	    equ 0x4F
white_tol	    equ 0x50
black_tol	    equ 0x51

; LLI registers
SENSOR_START	equ 059h
SENSOR0        EQU 0x59
SENSOR1        EQU 0x5A
SENSOR2        EQU 0x5B
SENSOR3        EQU 0x5C
SENSOR4        EQU 0x5D
RACE_COLOUR    EQU 0x5E
BLACK_FLAG     EQU 0x5F

;Touch Start variables
touch_flag	EQU 0x60
Vread		EQU 0x61
OpenSW		EQU 0x62
Trip		EQU 0x63
Hyst		EQU 0x64
DIFF		EQU 0x65

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
	
ADC_AN6		equ 0b00011001 ; 0 00110 0 1

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
    
    btfsc   TMR4IF	    ;was it timer 4?
    goto    TIMER4_ISR
    goto ISR

init:
    ; Set oscillator speed at 4 MHz
	bsf 	IRCF0
	bcf	IRCF1
	bsf	IRCF2
	
    MOVLB   0xFF	; work in bank 15, not all SFRs are in access bank
    
	
	
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
    
    ;Setup PORTE
    CLRF    ANSELE,b
    CLRF    PORTE,a
    CLRF    LATE,a
    CLRF    TRISE,a
    BSF	    ANSELE,1,b
    BSF	    TRISE,1,a
    
    ; Timer setup
    clrf    T0CON,a
    clrf    T1CON,a
    clrf    T1GCON,a
    
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
    
    ;Setup for touch pad
    ;CTMU modules
    CLRF    CTMUCONH
    movlw   0b00000010
    movwf   CTMUICON
    movlw   0b10010000 
    movwf   CTMUCONL
    movlw   0b10001000
    movwf   CTMUCONH
    
    ;Timer4 init for touch pad
   
    movlw   0b00000000
    movwf   T4CON
    movlw   125
    movwf   PR4

    ; INTCON2 = 0b 0 0 0 0 x 0 x 0 
    ; bsf	    INTCON2,7,a	; no RBPU
    ; bsf	    INTCON2,5,a	; INT1I reacts on rising edge
    ; INTCON3 = 0b 0 1 x 0 1 x 0 0
    clrf    INTCON3,a	;
    bsf     INT1IP	    ; INT1I priority is high
    bsf	    INT1IE	    ; INT1I is enabled
    ; INTCON = 0b 1 0 1 0 0 0 0 0
    bsf	    TMR0IE	    ; enable timer 0 interrupts
    bsf	    TMR2IE	    ;enable timer 4 interrupts
    
    BSF	    PEIE
    bsf	    GIEH	    ; enable high priority interupts
    bsf	    TMR4IE
    ; bsf	    GIEL,a	; enable low priority interupts
    
    MOVLB   0x0	; back to bank 0 for normal opperations
    
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
    ;initializing touch pad variables
    clrf    touch_flag,a	
    clrf    Vread,a		
    clrf    OpenSW,a		
    clrf    Trip,a		
    clrf    Hyst,a		
    clrf    DIFF,a
    
    clrf    race_error_colour_magic,a
    
    COLOUR_TOLERANCES:
	movlw   10
	MOVWF   red_tol,a
	
	movlw   10
	MOVWF   green_tol,a
	
	movlw   10
	MOVWF   blue_tol,a

	movlw   10
	MOVWF   black_tol,a

	movlw   10
	MOVWF   white_tol,a
    
    
; testing setup		
    bcf	    test_en, a
    btfsc   test_en, a
    goto    test
end_test:
    bcf	    test_en, a
    
STATE_MACHINE_SETUP:
    CLRF    state_0,a
    CLRF    subroutine_0,a
    CLRF    DELAY_SKIP,a
    CLRF    timer_waits,a
    
    ;Set touch start bit first so that the program waits for the touch pad to be touched
    ; State activation bits
    BSF calibrate,a
    ;BSF	touch_start,a
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
    ;BSF flash_colour_display,a
    ;BSF button_press_check,a
    ;BSF colour_display,a

	; Delay skips
	;BSF skip_delay_333,a
	;BSF skip_delay_RGB,a
    
STATE_MACHINE_START:
   
		
STATE0:
calibration:
    BTFSS   calibrate,a
    GOTO    STATE1
    
	; red
	LFSR    0, 100h
	movlw   1
	movwf   number_of_readings,a
	MOVLW	red_indicator
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	

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

	;green
	lfsr    0, 100h
	MOVLW	green_indicator
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	

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

	;blue
	lfsr    0, 100h
	MOVLW	blue_indicator
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	

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

	;black
	lfsr    0, 100h
	MOVLW	black_indicator
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	

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

	movwf	black_red_thresh,a


	movf    PREINC0,w,a	    ;s 0

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
	
	movwf	black_green_thresh,a


	movf    PREINC0,w,a	    ;s 0

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
	
	movwf	black_blue_thresh,a

	
	;white
	lfsr    0, 100h
	MOVLW	white_indicator
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	
	
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

	movwf	white_red_thresh,a


	movf    PREINC0,w,a	    ;s 0

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

	movwf	white_green_thresh,a


	movf    PREINC0,w,a	    ;s 0

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

	movwf	white_blue_thresh,a


	MOVLW	no_indicator
	MOVWF	DISPLAYED_COLOUR,a
	
	; setf    PORTD,a
	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a

	BSF	check_colour,a
	call    detect_colour
	BCF	check_colour,a

    ; calibrated colour
	movff   SENSOR2,RACE_COLOUR
	; clrf    PORTD,a

	movlw   'R'
	cpfseq  RACE_COLOUR,a
	bra	    $+12
	MOVLW	red_indicator
	MOVWF	DISPLAYED_COLOUR,a
	BSF	race_error_colour_magic,4,a
	goto    display_race_colour

	movlw   'G'
	cpfseq  RACE_COLOUR,a
	bra	    $+12
	MOVLW	green_indicator
	MOVWF	DISPLAYED_COLOUR,a
	BSF	race_error_colour_magic,6,a
	goto    display_race_colour

	movlw   'B'
	cpfseq  RACE_COLOUR,a
	bra	    $+12
	MOVLW	blue_indicator
	MOVWF	DISPLAYED_COLOUR,a
	BSF	race_error_colour_magic,7,a
	goto    display_race_colour

	movlw   'K'
	cpfseq  RACE_COLOUR,a
	bra	    $+10
	MOVLW	black_indicator
	MOVWF	DISPLAYED_COLOUR,a
	goto    display_race_colour

	MOVLW	white_indicator
	MOVWF	DISPLAYED_COLOUR,a

	display_race_colour:

	bsf		flash_colour_display,a
	call 	flash
	bcf		flash_colour_display,a
	;bsf		button_press_check,a
	;call    wait_for_button_press_show_colour
	;bcf		button_press_check,a

TRANSITION0:
    BCF	    calibrate,a
    BSF	    touch_start,a
    
STATE1:
touch_to_start:
    BTFSS   touch_start,a
    GOTO    STATE2
    ;Load threshold values. Change according to the touch pad used
    
;    MOVLW	0b00001001; AN2
    MOVLW	ADC_AN6; AN6, PORTE 1
    MOVWF	ADCON0,a
    BCF		TRISE1
    NOP
    BSF		TRISE1
    
    CAP_TOUCH:
	
	movlw   20
	movwf   OpenSW	;unpressed switch value
	movlw   1
	movwf   Trip	;difference between pressed and unpressed switch
	movlw   1
	movwf   Hyst	;amount to change from pressed to unpressed
    CHECK_TOUCH:
	MOVF    Trip,W
	SUBWF   OpenSW,0
	MOVWF   DIFF	;DIFF is OpenSW - Trip. This is the base comparison
	
	;Discharge touch pad
	BSF	    CTMUEN
	BCF	    EDG1STAT
	BCF	    EDG2STAT
	BSF	    IDISSEN
	CALL	    CAP_DELAY
	BCF	    IDISSEN

	;Charge circuit
	BSF	    EDG1STAT
	CALL	    CAP_DELAY
	BCF	    EDG1STAT

	;AD conversion
	BSF	    GO
	BTFSC	    GO
	BRA	    $-2
	MOVF	    ADRESH,W
	MOVWF	    Vread
	
	;test if Vread = 0
	MOVLW   0
	CPFSEQ  Vread
	GOTO    CHK_P_OR_UP
	BSF	PORTA,7
	GOTO    CHECK_TOUCH
	
    ;Check if pressed or unpressed
    CHK_P_OR_UP:
	;Check for pressed
	MOVF    DIFF,W
	CPFSLT  Vread  
	GOTO    PAD_PRESS
	;Check for unpressed
	MOVF    Hyst,W
	ADDWF   DIFF
	MOVF    DIFF,W
	CPFSGT  Vread
	GOTO    PAD_UNPRESS
	GOTO    CAP_TOUCH	;Loop touch start sequence until pad is pressed
    
    PAD_PRESS:
	BCF	    PORTA,7
	BSF	    PORTA,4
	GOTO	    TOUCH_TRANSITION
    PAD_UNPRESS:
	BCF	    PORTA,4
	BSF	    PORTA,7
	GOTO	    CHECK_TOUCH
    TOUCH_TRANSITION:
	; BCF	    touch_start
	BCF	    PORTA,4
	BCF	    PORTA,7
	GOTO	    TRANSITION1
    CAP_DELAY: 
	MOVLB	    0xF
	CLRF	    TMR4
	BSF	    TMR4ON
	MOVLB	    0x0
    WAIT1:
	BTFSS	    touch_flag,0
	BRA	    WAIT1
	BCF	    touch_flag,0
	BCF	    TMR4ON
	
	RETURN
    TIMER4_ISR:  ;moved the ISR here because if it is way down under, it affects the charging time for the current on the touchpad, giving low values. 
    ;Also added/moved the timer2 ISR to the org 0x08 to check if it is timer2 ISR or the normal ISR.
	BSF	    touch_flag,0
	
	BCF	    TMR4IF
	
	RETFIE
TRANSITION1:
    BCF	    touch_start,a
    BSF	    follow_line,a
    	
STATE2:
LLI:	
    BTFSS   follow_line,a
    GOTO    STATE3
    
	
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
	BSF	check_colour,a
	call    detect_colour
	BCF	check_colour,a
	GOTO	TRANSITION2
	    
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
	    GOTO    TRANSITION2
	TURN_LEFT_ALOT:
	    MOVLW 0b10000000
	    MOVWF line_reg,a
	    GOTO    TRANSITION2
	TURN_LEFT_ALITTLE:
	    MOVLW 0b01000000
	    MOVWF line_reg,a
	    GOTO    TRANSITION2
	TURN_RIGHT_ALOT:
	    MOVLW 0b00001000
	    MOVWF line_reg,a
	    GOTO    TRANSITION2
	TURN_RIGHT_ALITTLE:
	    MOVLW 0b00010000
	    MOVWF line_reg,a
	    GOTO    TRANSITION2
	LOST:
	    CALL LOST_STOP
	    CALL TURN_LEFT_ALOT
		;call    wait_for_button_press	; this is here for the purposes of the demo
	    BRA STRAIGHT
	    GOTO    TRANSITION2
	    
	    LOST_STOP:
		CALL BRAKES
		bsf	wait_for_timer333,a
		bsf	delay_333_call,a
		CALL delay_333
		bcf	delay_333_call,a
		    ;call    wait_for_button_press	; this is here for the purposes of the demo
		CLRF line_reg,a
	    GOTO    TRANSITION2
         
	BRAKES:
	    MOVLW 0b11111000
	    MOVWF line_reg,a
	    GOTO    TRANSITION2
	    
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
	    GOTO    TRANSITION2
	    BRA	    BRAKES
    
TRANSITION2:
    BSF	    follow_line,a   ;LOOP OVER LLI

		
STATE3:
software_tests:
    BTFSS   code_tests,a
    GOTO    STATE4
    
    TODO_code_tests: ; to-do todo to do
	nop
;   state 2 code
    ; to be added later
    
TRANSITION3:
    BCF	    code_tests,a
    
    		
STATE4:
test_hardware:
    BTFSS   hardware_tests,a
    GOTO    SUBROUTINE0
    
    movlb   0x1
    TODO_hardware_tests: ; to-do todo to do
    

	
	
	MOVLW	black_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	
	
	MOVLW	error_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	
	
	MOVLW	red_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	
	
	bsf	race_error_colour_magic,4,a
	MOVLW	race_error_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	clrf	race_error_colour_magic,a
	
	
	MOVLW	green_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	
	
	bsf	race_error_colour_magic,6,a
	MOVLW	race_error_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	clrf	race_error_colour_magic,a
	
	
	MOVLW	blue_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	
	
	bsf	race_error_colour_magic,7,a
	MOVLW	race_error_indicator    
	MOVWF	DISPLAYED_COLOUR,a

	bsf		button_press_check,a
	call    wait_for_button_press_show_colour
	bcf		button_press_check,a
	clrf	race_error_colour_magic,a
	
	
    goto    TODO_hardware_tests
    

SENSOR0_RED	EQU 0X100
SENSOR1_RED	EQU 0X101
SENSOR2_RED	EQU 0X102
SENSOR3_RED	EQU 0X103
SENSOR4_RED	EQU 0X104
SENSOR0_GREEN	EQU 0X105
SENSOR1_GREEN	EQU 0X106
SENSOR2_GREEN	EQU 0X107
SENSOR3_GREEN	EQU 0X108
SENSOR4_GREEN	EQU 0X109
SENSOR0_BLUE	EQU 0X10A
SENSOR1_BLUE	EQU 0X10B
SENSOR2_BLUE	EQU 0X10C
SENSOR3_BLUE	EQU 0X10D
SENSOR4_BLUE	EQU 0X10E
    
    lfsr    0,100h
    bsf	    read_sensors_call,a
    call read_sensors
    bcf	    read_sensors_call,a
    goto TODO_hardware_tests
;   state 2 code
    ; to be added later
    
TRANSITION4:
    BCF	    hardware_tests,a 
    
;==========SUBROUTINES=======================
    
TRY_ALL_SUBROUTINES:
    
SUBROUTINE0:
TODO_DELAY_333_REPLACE_WITH_TIMER:
delay_333:
    BTFSS   delay_333_call,a
    GOTO    SUBROUTINE1
    BTFSC   skip_delay_333,A
    return
    
	; save context
	movwf    extra,a
	
    ; decide timer 0 setup for this specific timer
	; sets timer 0 to overflow in (2*256+139)*4 = 166656 instruction cycles
	    ; is about 166656us, half the period of a 3Hz flash
	; TMR0H = -2
	movlw	-2
	movwf	TMR0H,a
	; TMR0L = -139
	movlw	-139
	movwf	TMR0L,a
	; T0CON = 0b 1 0 0 0 0 111
	; enable timer
	; make 16-bit
	; work on instruction cycle
	; x
	; use prescaler
	; prescaler is set to 1:256
	movlw	0b10000111
	movwf	T0CON,a
	
	; option to wait for the timer
	btfsc	wait_for_timer333,a
	bra	$-2
	
	; restore context
	movf    extra,w,a
	return
    
SUB_TRANSITIONS0:
    BCF	    delay_333_call,a
    
        
SUBROUTINE1:
delay_RGB:
    BTFSS   RGB_delay_call,a
    GOTO    SUBROUTINE2
	BTFSC	skip_delay_RGB,A
	return
	
	; save context
	movwf    extra,a
	
	TODO_maybe_give_the_option_to_wait_for_it:
	; set the timer to overflow in 40 instruction cycles
	; about 40 us, which is the settling time 
	    ; might change to 20us, because that is the rise time
	    ; would have to change the calibration code a bit to account for the 
	    ; range of values between 90% and 100% of the steady state
		; this might distort the ADC reading tho, so nah
	movlw	-40
	movwf	TMR1L,a
	setf	TMR1H,a
	; turn the timer on
	bsf	TMR1ON
	; wait for the timer
	btfss	TMR1IF
	bra	$-2
	; turn the timer off
	bcf	TMR1ON
	bcf	TMR1IF
	
	; restore context
	movf    extra,w,a
	return
    
SUB_TRANSITIONS1:
    BCF	    RGB_delay_call,a
    
        
SUBROUTINE2:
read_sensors:
    BTFSS   read_sensors_call,a
    GOTO    SUBROUTINE3
    
    TODO_make_states_with_this: ; to-do todo to do
    nop
    
    ; setup for indirect adressing
	; you need to use 'LFSR FSR0, XYZh' before calling this 
	; X is the bank
	; YZ is the starting register
    ;    LFSR 0, 100h ;need to remove, only here for initial creation purposes

    ; shine red
	bsf	    red_pin,a
	bsf	RGB_delay_call,a
	call delay_RGB
	bcf	RGB_delay_call,a

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
	bsf	RGB_delay_call,a
	call delay_RGB
	bcf	RGB_delay_call,a

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
	bsf	RGB_delay_call,a
	call delay_RGB
	bcf	RGB_delay_call,a

	    ; testing code, should do nothing if test_en = 0
		btfss   test_en,a
		bra	    $+8
		call    dummy_read_all_sensors
		bra	    $+6
	    ; end of testing code

	call    read_all_sensors
	bcf	    blue_pin,a

	return
	GOTO	SUB_TRANSITIONS2

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
detect_colour:
    BTFSS   check_colour,a
    GOTO    SUBROUTINE4
    
    ;TODO_make_this_work_with_states_1:  ; to-do todo to do
    
	; clear the previous colours
	clrf    SENSOR0,a
	clrf    SENSOR1,a
	clrf    SENSOR2,a
	clrf    SENSOR3,a
	clrf    SENSOR4,a
	
	; read sensors to bank 2 for now
	LFSR    0, 200h	
	BSF read_sensors_call,a
	call    read_sensors
	BCF read_sensors_call,a
	; back to bank 2
	LFSR    0, 200h	

	; always check for white first
	white_check:
    
		white_red_check:
    
	    
	    clrf	red_check_bits,a

	    ;sensor 0
	    movf    white_red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    red_check_bits,0,a

	    ;sensor 1
	    movf    white_red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    red_check_bits,1,a

	    ;sensor 2
	    movf    white_red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    red_check_bits,2,a

	    ;sensor 3
	    movf    white_red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    red_check_bits,3,a

	    ;sensor 4
	    movf    white_red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    red_check_bits,4,a


		white_green_check:


	    clrf	green_check_bits,a

	    ;sensor 0
	    movf    white_green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    green_check_bits,0,a

	    ;sensor 1
	    movf    white_green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    green_check_bits,1,a

	    ;sensor 2
	    movf    white_green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    green_check_bits,2,a

	    ;sensor 3
	    movf    white_green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    green_check_bits,3,a

	    ;sensor 4
	    movf    white_green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    green_check_bits,4,a


		white_blue_check:


	    clrf	blue_check_bits,a

	    ;sensor 0
	    movf    white_blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    blue_check_bits,0,a

	    ;sensor 1
	    movf    white_blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    blue_check_bits,1,a

	    ;sensor 2
	    movf    white_blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    blue_check_bits,2,a

	    ;sensor 3
	    movf    white_blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    blue_check_bits,3,a

	    ;sensor 4
	    movf    white_blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  white_tol,a
	    bsf	    blue_check_bits,4,a

	    final_white_check:
	    CLRF    check,a
	    
	    ;check sensor 0
	    btfsc   red_check_bits,0,a
	    bsf     check,0,a
	    btfsc   green_check_bits,0,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,0,a
	    bsf     check,2,a

	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
	    movlw	'W'
	    movwf	SENSOR0,a

	    CLRF    check,a
	    ;check sensor 1
	    btfsc   red_check_bits,1,a
	    bsf     check,0,a
	    btfsc   green_check_bits,1,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,1,a
	    bsf     check,2,a

	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
	    movlw	'W'
	    movwf	SENSOR1,a

	    CLRF    check,a
	    ;check sensor 2
	    btfsc   red_check_bits,2,a
	    bsf     check,0,a
	    btfsc   green_check_bits,2,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,2,a
	    bsf     check,2,a

	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
	    movlw	'W'
	    movwf	SENSOR2,a

	    CLRF    check,a
	    ;check sensor 3
	    btfsc   red_check_bits,3,a
	    bsf     check,0,a
	    btfsc   green_check_bits,3,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,3,a
	    bsf     check,2,a

	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
	    movlw	'W'
	    movwf	SENSOR3,a

	    CLRF    check,a
	    ;check sensor 4
	    btfsc   red_check_bits,4,a
	    bsf     check,0,a
	    btfsc   green_check_bits,4,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,4,a
	    bsf     check,2,a

	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
	    movlw	'W'
	    movwf	SENSOR4,a
	    
	    TODO_change_how_the_colour_checks_are_done:
	    ; best ideas so far:
		; check how close the colours are to their white thresholds.
		    ; this can be used to resolve error cases where two colours
		    ; are higher than their thresholds.
		; check how far the colours are from their black thresholds.
		    ; can be used when all the colours are lower than their thresholds
		    ; but the sensor is not seeing black.
	    ; comments:
		; need to check how much noise is on the output of the new amplifier
		; circuit to see how generous i have to be with the error tollerance 
	    nop
	    TODO_maybe_put_a_checking_order_for_the_colours:
	    nop

	    lfsr	0,200h

	red_checks:
	    clrf	red_check_bits,a
	    
	    ; sensor 0
	    ; is it white?
	    TSTFSZ  SENSOR0,a
	    bra	    $+14

	    movf    red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  red_tol,a
	    bsf	    red_check_bits,0,a

	    ; sensor 1
	    ; is it white?
	    TSTFSZ  SENSOR1,a
	    bra	    $+14

	    movf    red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  red_tol,a
	    bsf	    red_check_bits,1,a

	    ; sensor 2
	    ; is it white?
	    TSTFSZ  SENSOR2,a
	    bra	    $+14

	    movf    red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  red_tol,a
	    bsf	    red_check_bits,2,a

	    ; sensor 3
	    ; is it white?
	    TSTFSZ  SENSOR3,a
	    bra	    $+14
		
	    movf    red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  red_tol,a
	    bsf	    red_check_bits,3,a

	    ; sensor 4
	    ; is it white?
	    TSTFSZ  SENSOR4,a
	    bra	    $+14

	    movf    red_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  red_tol,a
	    bsf	    red_check_bits,4,a

	green_checks:
	    clrf	green_check_bits,a
	    
	    ; sensor 0
	    ; is it white?
	    TSTFSZ  SENSOR0,a
	    bra	    $+14
		
	    movf    green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  green_tol,a
	    bsf	    green_check_bits,0,a

	    ; sensor 1
	    ; is it white?
	    TSTFSZ  SENSOR1,a
	    bra	    $+14

	    movf    green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  green_tol,a
	    bsf	    green_check_bits,1,a

	    ; sensor 2
	    ; is it white?
	    TSTFSZ  SENSOR2,a
	    bra	    $+14

	    movf    green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  green_tol,a
	    bsf	    green_check_bits,2,a

	    ; sensor 3
	    ; is it white?
	    TSTFSZ  SENSOR3,a
	    bra	    $+14

	    movf    green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  green_tol,a
	    bsf	    green_check_bits,3,a

	    ; sensor 4
	    ; is it white?
	    TSTFSZ  SENSOR4,a
	    bra	    $+14

	    movf    green_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  green_tol,a
	    bsf	    green_check_bits,4,a

	blue_checks:
	    clrf	blue_check_bits,a
	    
	    ; sensor 0
	    ; is it white?
	    TSTFSZ  SENSOR0,a
	    bra	    $+14

	    movf    blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  blue_tol,a
	    bsf	    blue_check_bits,0,a

	    ; sensor 1
	    ; is it white?
	    TSTFSZ  SENSOR1,a
	    bra	    $+14

	    movf    blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  blue_tol,a
	    bsf	    blue_check_bits,1,a

	    ; sensor 2
	    ; is it white?
	    TSTFSZ  SENSOR2,a
	    bra	    $+14

	    movf    blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  blue_tol,a
	    bsf	    blue_check_bits,2,a

	    ; sensor 3
	    ; is it white?
	    TSTFSZ  SENSOR3,a
	    bra	    $+14

	    movf    blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  blue_tol,a
	    bsf	    blue_check_bits,3,a

	    ; sensor 4
	    ; is it white?
	    TSTFSZ  SENSOR4,a
	    bra	    $+14

	    movf    blue_thresh,w,a
	    SUBWF   POSTINC0,w,a	    ; get error
	    BNN	    $+6
	    NEGF    WREG,a		    ; make positive if negative
	    cpfslt  blue_tol,a
	    bsf	    blue_check_bits,4,a


	checking_colours:
	    ; check sensor 0
	    ; check if it is white
	    TSTFSZ  SENSOR0,a
	    bra	    $+22

	    CLRF    check,a
	    
	    btfsc   red_check_bits,0,a
	    bsf     check,0,a
	    btfsc   green_check_bits,0,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,0,a
	    bsf     check,2,a

	    call    run_detection_checks
	    movwf   SENSOR0,a

	    ; check sensor 1
	    ; check if it is white
	    TSTFSZ  SENSOR1,a
	    bra	    $+22
		
	    CLRF    check,a

	    btfsc   red_check_bits,1,a
	    bsf     check,0,a
	    btfsc   green_check_bits,1,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,1,a
	    bsf     check,2,a

	    call    run_detection_checks
	    movwf   SENSOR1,a

	    ; check sensor 2
	    ; check if it is white
	    TSTFSZ  SENSOR2,a
	    bra	    $+22
		
	    CLRF    check,a

	    btfsc   red_check_bits,2,a
	    bsf     check,0,a
	    btfsc   green_check_bits,2,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,2,a
	    bsf     check,2,a

	    call    run_detection_checks
	    movwf   SENSOR2,a

	    ; check sensor 3
	    ; check if it is white
	    TSTFSZ  SENSOR3,a
	    bra	    $+22
		
	    CLRF    check,a
		
	    btfsc   red_check_bits,3,a
	    bsf     check,0,a
	    btfsc   green_check_bits,3,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,3,a
	    bsf     check,2,a

	    call    run_detection_checks
	    movwf   SENSOR3,a

	    ; check sensor 4
	    ; check if it is white
	    TSTFSZ  SENSOR4,a
	    bra	    $+22
		
	    CLRF    check,a
		
	    btfsc   red_check_bits,4,a
	    bsf     check,0,a
	    btfsc   green_check_bits,4,a
	    bsf     check,1,a
	    btfsc   blue_check_bits,4,a
	    bsf     check,2,a

	    call    run_detection_checks
	    movwf   SENSOR4,a

	return
	    run_detection_checks:
    
		movlw   0
		cpfseq  check,a
		bra	    $+4
		; it sees black
		RETLW   'K'

		movlw   1
		cpfseq  check,a
		bra	    $+4
		; it sees red
		RETLW   'R'

		movlw   2
		cpfseq  check,a
		bra	    $+4
		; it sees green
		RETLW   'G'

		movlw   4
		cpfseq  check,a
		bra	    $+4
		; it sees blue
		RETLW   'B'
		
		; race error check
		movlw	'R'
		CPFSEQ	RACE_COLOUR,a
		bra	$+6
		btfsc	check,0,a
		RETLW	'e'
		
		movlw	'G'
		CPFSEQ	RACE_COLOUR,a
		bra	$+6
		btfsc	check,1,a
		RETLW	'e'
		
		movlw	'B'
		CPFSEQ	RACE_COLOUR,a
		bra	$+6
		btfsc	check,0,a
		RETLW	'e'

		; default to ERROR
		RETLW   'E'
    
SUB_TRANSITIONS3:
    BCF	    check_colour,a
        
    
SUBROUTINE4:
    TODO_this_should_be_changed_for_serial_bridge_comms:
    nop
show_colour:
    BTFSS   show_the_colours,a
    GOTO    SUBROUTINE5
    
    ; check solid colour
	; movf	SENSOR0,w,a
	; andwf	SENSOR1,w,a
	; andwf	SENSOR2,w,a
	; andwf	SENSOR3,w,a
	; andwf	SENSOR4,w,a

	; clrf	PORTD,a

	movwf	extra,a
	movlw	'W'
	cpfseq	extra,a
	bra	$+6
	MOVLW	white_indicator
	MOVWF	DISPLAYED_COLOUR,a

	movlw	'K'
	cpfseq	extra,a
	bra	$+6
	MOVLW	black_indicator
	MOVWF	DISPLAYED_COLOUR,a

	movlw	'R'
	cpfseq	extra,a
	bra	$+6
	MOVLW	red_indicator
	MOVWF	DISPLAYED_COLOUR,a

	movlw	'G'
	cpfseq	extra,a
	bra	$+6
	MOVLW	green_indicator
	MOVWF	DISPLAYED_COLOUR,a

	movlw	'B'
	cpfseq	extra,a
	bra	$+6
	MOVLW	blue_indicator
	MOVWF	DISPLAYED_COLOUR,a
	return

    
SUB_TRANSITIONS4:
    BCF	    show_the_colours,a
        
    
SUBROUTINE5:
 flash:
    BTFSS   flash_colour_display,a
    GOTO    SUBROUTINE6
    
	; number of flashes
	movlw   3
	movwf   count,a
	
	BEGIN_FLASH:
	; begin flashing
	    ; turn off
	bcf	red_pin,a
	bcf	green_pin,a
	bcf	blue_pin,a
	    ;wait 0.166 seconds
	bsf	wait_for_timer333,a
	bsf	delay_333_call,a
	call    delay_333
	bcf	delay_333_call,a
	    ;start 0.166 second timer
	bsf	delay_333_call,a
	call    delay_333
	bcf	delay_333_call,a
	; do this because i will do things while waiting for the timer.
	bsf	wait_for_timer333,a
	    ; turn on
	MOVF	DISPLAYED_COLOUR,w,a
	BSF	colour_display,a
	call	display_colour
	BCF	colour_display,a
	    ;wait 0.166 seconds
	btfsc	wait_for_timer333,a
	bra	$-10
	; did we flash enough?
	decfsz  count,a
	bra	BEGIN_FLASH	; no
	; yes
	return
    
SUB_TRANSITIONS5:
    BCF	    flash_colour_display,a
        
    
SUBROUTINE6:
wait_for_button_press_show_colour:
    BTFSS   button_press_check,a
    GOTO    display_colour
    
	; show the colour to calibrate
	BSF	colour_display,a
	call	display_colour
	BCF	colour_display,a
	
	btfss   INT0IF	    ;wait for button press
	bra	    $-10
	; delay so that we dont have to debounce
    bsf	wait_for_timer333,a
	bsf	delay_333_call,a
	call    delay_333
	bcf	delay_333_call,a
	; reset button wait
	bcf	    INT0IF
	; go back
	return
    
SUB_TRANSITIONS6:
    BCF	    button_press_check,a
    
    
SUBROUTINE7:
display_colour:
    BTFSS   colour_display,a
    GOTO    STATE_MACHINE_END
    
	MOVF	PCL,w,a
	MOVF	DISPLAYED_COLOUR,w,a
	ADDWF	PCL,f,a
	bra	    display_nothing
	;BTFSC   black_indicator,a
	bra	    display_black
	;BTFSC   white_indicator,a
	bra	    display_white
	;BTFSC   red_indicator,a
	bra	    display_red
	;BTFSC   green_indicator,a
	bra	    display_green
	;BTFSC   blue_indicator,a
	bra	    display_blue
	;BTFSC	race_error_indicator,a
	bra		display_race_error
	;BTFSC 	error_indicator,a
	bra		display_error
	
	display_colour_end:
	; clrf	colour_displays,a
    
	RETURN
	bra	SUB_TRANSITIONS7
	
	    display_nothing:
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    
	    return
    
	    display_black:
	    ; orange = RGB(255,102,0), means 40% duty cycle on green
	    bsf	red_pin,a
	    bsf	green_pin,a
	    nop
	    nop
	    nop
	    bcf	green_pin,a
	    nop
	    nop
	    nop
	    nop
	    bcf	red_pin,a

	    return

	    display_white:
	    ; white = RGB(255,255,255)
	    SETF	LATA,a
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    CLRF	LATA,a

	    return

	    display_red:
	    bsf	red_pin,a
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    bcf	red_pin,a

	    return

	    display_green:
	    bsf	green_pin,a
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    bcf	green_pin,a

	    return

	    display_blue:
	    bsf	blue_pin,a
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    bcf	blue_pin,a

	    return

	    display_race_error:
	    movf	race_error_colour_magic,w,a
	    movwf	LATA,a
	    CLRF	LATA,a
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop
	    nop

	    return

	    display_error:
	    ; brown = RGB(102,51,0); 40% duty cycle on red and 20% duty cycle on green
	    bsf	red_pin,a
	    bsf	green_pin,a
	    bcf	green_pin,a
	    bcf	red_pin,a
	    bsf	blue_pin,a
	    bcf	blue_pin,a
	    nop
	    nop
	    nop
	    nop
	    nop

	    return
    
SUB_TRANSITIONS7:
    BCF	    colour_display,a
    
    
STATE_MACHINE_END:
    
GOTO    STATE_MACHINE_START   ; LOOP OVER ALL STATES

    
;======INTERRUPTS===========
    
ISR:
    btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
    goto    register_dump   
    btfsc   TMR0IF	    ; was it timer 0?
    goto    timer0_interrupt
;    btfsc   TMR2IF	    ;was it timer 2?
;    goto    TIMER2_ISR
    
    retfie

;TIMER2_ISR:   
;    BSF	    touch_flag,0
;    BCF	    TMR2IF
;    RETFIE

register_dump:
    movff   line_reg, PORTC     ; put line_reg into PORTC
    bcf	    INT1IF		; clear interrupt flag
    retfie			            ;return from interrupt

timer0_interrupt:
    ; check if the wait bit for timmer333 was set
    btfsS   wait_for_timer333,a
    bra	    $+10
    ; if it was, just clear the wait and return
    bcf	    wait_for_timer333,a
    clrf    T0CON,a
    bcf	    TMR0IF
    retfie
    ; if not, do other things first, then return
    
    nop
    retfie
    
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