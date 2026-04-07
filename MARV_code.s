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
;	Button press to wait for: RB0
;   PWM:
;	Pins:	RD1 so far
;	Timers: TMR2 so far
;   Register dump:	{N/A}
;	Port C		{N/A}
;   Colour display:	{N/A}
;	Port D		{N/A}
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
    CONFIG  CCP2MX = PORTC1
    
    CONFIG  MCLRE = EXTMCLR
    CONFIG  LVP	= ON
    
    CONFIG  BOREN = SBORDIS
    CONFIG  BORV = 190 
    
    CONFIG  P2BMX = 1
  
    
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
#define calibrate	state_0,0,a
#define follow_line	state_0,1,a
#define code_tests	state_0,2,a
#define hardware_tests	state_0,3,a

; sub-routine bits
subroutine_0	equ 0x07
#define delay_333_call	    subroutine_0,0,a  ;166ms
#define RGB_delay_call	    subroutine_0,1,a  ;1.2ms
	
#define read_sensors_call   subroutine_0,2,a
#define check_colour	    subroutine_0,3,a
	
#define show_the_colours    subroutine_0,4,a
#define	flash_port_d	    subroutine_0,5,a
#define button_press_check  subroutine_0,6,a

; delay skip bits
DELAY_SKIP		equ	0x08
#define skip_delay_333		DELAY_SKIP,0,a
#define skip_delay_RGB		DELAY_SKIP,1,a
	    
timer_waits		equ	0x09
#define	wait_for_timer333   timer_waits,0,a
#define	wait_for_timerRBG   timer_waits,1,a
	    
calibrated_color    equ 0x0E	
offset_stuff	equ 0x0F
reading_count	equ 0x10
count		equ 0x11
;   dont use address 0x13, strange things afoot
extra		equ 0x19
;OTHER MOTOR DEFINTIONS
;#define left_dir_pin    PORTD,3 ;DIRECTION OUTPUT PINS
;#define right_dir_pin   PORTD,6
;PID variables
line_seen	    equ 0x72
default_duty_cycle  equ	0x73

s0_value        equ   0x74
s1_value        equ   0x75
s2_value        equ   0x76
s3_value        equ   0x77
s4_value        equ   0x78

PD_OUTPUT       EQU   0x79

Kp				equ   0x7A
Kd              equ   0x7B

prop_error      equ   0x7C

deriv_error     equ   0x7D
prev_error		equ   0x7E

acc_error       equ   0x7F

error0          equ   0x80
error1          equ   0x81
error2          equ   0x82
error3          equ   0x83
error4          equ   0x84

PD_SIGN         EQU   0x85

s1_value_e	equ	0x86
s3_value_e	equ	0x87


		
		
; MOTOR variables
;--------------------------------------------------------

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

; LLI registers
SENSOR_START	equ 059h
SENSOR0        EQU 0x59
SENSOR1        EQU 0x5A
SENSOR2        EQU 0x5B
SENSOR3        EQU 0x5C
SENSOR4        EQU 0x5D
RACE_COLOUR    EQU 0x5E
BLACK_FLAG     EQU 0x5F

; RGB pins
#define red_pin     PORTA,4,a
#define green_pin   PORTA,6,a
#define blue_pin    PORTA,7,a
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
     
;DUTY CYCLE DEFINITIONS
DUTY_25     equ 31
DUTY_50     equ 62
DUTY_75     equ 93
DUTY_100    equ 125
DUTY_STOP   equ 0

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
    
    ; setup misc ports(C and D)
    ; Port C, as output (Now used for motor control)
    clrf    PORTC, a
    clrf    LATC, a
    clrf    ANSELC, b
    clrf    TRISC, a


    PWM_Init:
    ; Use Timer2 for CCP1 and CCP2 PWM
    clrf    CCPTMRS0,1
    clrf    CCPTMRS1,1

    ; PWM period:
    ; Fpwm = Fosc / (4 * (PR2 + 1) * prescale)
    ; 4MHz / (4 * 125 * 16) = 0.5kHz
    movlw   124
    movwf   PR2,1

    ; Clear CCP registers
    clrf    CCPR1L,1
    clrf    CCPR2L,1

    ; PWM mode on CCP1 and CCP2
    movlw   00001100B
    movwf   CCP1CON,1
    movwf   CCP2CON,1
    
    ;ALLOWS POLARITY SWITCHING
	; use PxB as forward and PxC as reverse for now
	; only keep one port for each PWM active at a time. 
	; might break the H-Bridge if you try to output from the reverse pin and the forward pin at the same time.
    MOVLW   00010010B
    MOVWF   PSTR1CON,a
    MOVWF   PSTR2CON,a
    
    ; Timer2 prescaler = 1:16, postscaler = 1:1, Timer2 ON
    movlw   00000111B
    movwf   T2CON,1
    
    ; Port D
    clrf    PORTD, a
    clrf    LATD, a
    clrf    ANSELD, b
    ; clrf    TRISD, a
    
    ; RD2 = CCP2 PWM output P2B, RD3 = CCP2 PWM output P2C, RD5 = CCP1 PWM OUTPUT P1B, RD6 = CCP1 OUTPUT P1C
    bcf     TRISD,2,a
    bcf     TRISD,3,a
    bcf     TRISD,5,a
    bcf     TRISD,6,a
    
    ; Set up PORTB
    clrf    PORTB, a
    clrf    LATB, a
    clrf    ANSELB, b
    clrf    TRISB, a
    bsf	    TRISB,1,a	; RB1 is input(INT1I)
    bsf	    TRISB,6,a	; just in case programmer for debugging is complaining
    ; clrf    WPUB,a      ; no more weak pull up for PORTB
    
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

    ; INTCON2 = 0b 0 0 0 0 x 0 x 0 
    ; bsf	    INTCON2,7,a	; no RBPU
    ; bsf	    INTCON2,5,a	; INT1I reacts on rising edge
    ; INTCON3 = 0b 0 1 x 0 1 x 0 0
    clrf    INTCON3,a	;
    bsf     INT1IP	    ; INT1I priority is high
    bsf	    INT1IE	    ; INT1I is enabled
    ; INTCON = 0b 1 0 1 0 0 0 0 0
    bsf	    TMR0IE	    ; enable timer 0 interrupts
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
    
    movlw   DUTY_100
    movwf   default_duty_cycle,b
; testing setup		
    bcf	    test_en, a
    btfsc   test_en, a
    goto    test
end_test:
    bcf	    test_en, a
    
STATE_MACHINE_SETUP:
    CLRF    state_0,a
    CLRF    subroutine_0,a
    CLRF	DELAY_SKIP,a
    CLRF	timer_waits,a
    
    ; State activation bits
    ;BSF calibrate
    ;BSF follow_line
    
	; tests
     ;BSF code_tests
     BSF hardware_tests
    
    ; Subroutine activation bits
    ;BSF delay_333_call
    ;BSF RGB_delay_call
    ;BSF read_sensors_call
    ;BSF check_colour
    ;BSF show_the_colours
    ;BSF flash_port_d
    ;BSF button_press_check

	; Delay skips
	;BSF skip_delay_333
	;BSF skip_delay_RGB
    
STATE_MACHINE_START:
;<editor-fold defaultstate="collapsed" desc="calibration">		
STATE0:
calibration:
    BTFSS   calibrate
    GOTO    STATE1
    
	; red
	LFSR    0, 100h
	movlw   1
	movwf   number_of_readings,a
	bsf	    red_indicator,a

	call    wait_for_button_press
	call    read_sensors
	

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


	movlw   10
	subwf   black_red_thresh,f,a
	subwf   black_green_thresh,f,a
	subwf   black_blue_thresh,f,a
	;white
	lfsr    0, 100h
	bcf	    black_indicator,a
	bsf	    white_indicator,a

	call    wait_for_button_press
	call    read_sensors
	
	
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


	movlw   10
	subwf   white_red_thresh,f,a
	subwf   white_green_thresh,f,a
	subwf   white_blue_thresh,f,a

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

	
    
    
TRANSITION0:
    BCF	    calibrate
    BSF	    follow_line
    
;</editor-fold>
    
    	
STATE1:
LLI:	
BTFSS   follow_line
GOTO    STATE2

MOVLW           -4   
MOVWF		s0_value,b
MOVLW           -2   
MOVWF		s1_value,b
MOVLW           -1   
MOVWF		s1_value_e,b
MOVLW           0
MOVWF		s2_value,b
MOVLW           1
MOVWF		s3_value_e,b
MOVLW           2
MOVWF		s3_value,b
MOVLW           4
MOVWF		s4_value,b
    
    
	    MOVLW   'R'
	    MOVWF   RACE_COLOUR,a
	    movff   RACE_COLOUR,ADRESH
	    
	    MOVLW   'W'
	    MOVWF   SENSOR0,a
	    MOVLW   'B'
	    MOVWF   SENSOR1,a
	    MOVLW   'R'
	    MOVWF   SENSOR2,a
	    MOVLW   'G'
	    MOVWF   SENSOR3,a
	    MOVLW   'W'
	    MOVWF   SENSOR4,a
	
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
	
	    CLRF error0,a
	    CLRF error1,a
	    CLRF error2,a
	    CLRF error3,a
	    CLRF error4,a
	    ;call detect_colour
	    
	    MOVFF   ADRESH,RACE_COLOUR
	    
	    clrf    line_seen,b
	    
		    
		    
		; the PWM shouldnt be changed untill after the PID is done
	    ;CALL    Set_Both_Speed_75
	    
	    ;SENSOR0 check
	    
	    ; this check for race_error makes some sense because the value of 'e' is bigger than the other letters we use.
	    ; only issue is (or was), you cant put letters into the CPFS functions because it will take the value of the letter and use that as an address
		; i also went through and fixed some of the logic
	    movlw   'e'
	    ;MOVF    SENSOR0,W,a
	    CPFSEQ  SENSOR0,a
	    bra	    $+8
	    MOVFF   s1_value, error0
	    setf    line_seen,b
	    
	    ; This is a check that is needed, but you kindof did it wrong because you arent specifically checking for the race colour.
	    ; This means that if, for example, the race colour is red 'R' and the SENSOR sees green 'G' or error 'E', this would still trigger
	    ; because 'G' and 'E' are smaller than 'R', and the MOVFF would only be skipped if SENSOR has 'W' or 'e'
		; I have changed it so that it only works if SENSORx is equal to RACE_COLOUR
	    MOVF    RACE_COLOUR,w,a
	    CPFSEQ  SENSOR0,a
	    bra	    $+8
	    MOVFF   s0_value, error0
	    setf    line_seen,b
	    
	    ;SENSOR1 check
	    movlw   'e'
	    ;MOVF    SENSOR1,W,a
	    CPFSEQ  SENSOR1,a
	    bra	    $+8
	    MOVFF   s1_value_e, error1
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,w,a
	    CPFSEQ  SENSOR1,a
	    bra	    $+8
	    MOVFF   s1_value, error1
	    setf    line_seen,b
	    
	    ;SENSOR2 check
	    movlw   'e'
	    ;MOVF    SENSOR2,W,a
	    CPFSEQ  SENSOR2,a
	    bra	    $+8
	    MOVFF   s2_value, error2
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    cpfseq  SENSOR2,a
	    bra	    $+8
	    MOVFF   s2_value, error2
	    setf    line_seen,b
	    
	    ;SENSOR3 check
	    movlw   'e'
	    ;MOVF    SENSOR3,W,a
	    CPFSEQ  SENSOR3,a
	    bra	    $+8
	    MOVFF   s3_value_e, error3
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    CPFSEQ  SENSOR3,a
	    bra	    $+8
	    MOVFF   s3_value, error3
	    setf    line_seen,b
	    
	    ;SENSOR4 check
	    movlw   'e'
	    ;MOVF    SENSOR4,W,a
	    CPFSEQ  SENSOR4,a
	    bra	    $+8
	    MOVFF   s3_value, error4
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    CPFSEQ  SENSOR4,a
	    bra	    $+8
	    MOVFF   s4_value, error4
	    setf    line_seen,b
	    
	    ; PID calcs
	    
	    CALL    ERROR_CALC
	    
	    CALL    PID1
	    
	    CALL    CHANGE_OF_OUTPUTS
	    ;this only needs to be called if the PID output is 0
	    ; also need to check if the race colour or race error was seen.
	    tstfsz  line_seen,b
	    bra	    $+10
	    tstfsz  PD_OUTPUT,b
	    bra	    $+6
	    CALL    CHECK_BLACK
	    
	    ; again looping over itself, needs to be changed before it is in the actual code
	    GOTO    STRAIGHT
	    
	ERROR_CALC:
	    ; small bit of setup for this
            CLRF    acc_error, b
	    
	    ; SENSOR 0
	    ;NEGF    s0_value	    ; why do this? 
            ;MOVF    s0_value,W,a    ; why do this?
            ;MULWF   error0,a	    ; ?????
	    ;MOVF    PRODH, W, a	    ; !?!?!?
	    movf    error0,w,b
	    ADDWF   acc_error,b	    ; this I somewhat get
	    
	    ; SENSOR 1
	    ;NEGF    s1_value
	    ;MOVF    s1_value,W,a
            ;MULWF   error1,a
	    ;MOVF    PRODH, W, a
	    movf    error1,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 2
	    ; MOVF    s2_value,W,a
        ;     MULWF   error2,a
	    ; MOVF    PRODH, W, a
	    movf    error2,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 3
	    ; MOVF    s3_value,W,a
        ;     MULWF   error3,a
	    ; MOVF    PRODH, W, a
	    movf    error3,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 4
	    ; MOVF    s4_value, W,a
        ;     MULWF   error4,a
	    ; MOVF    PRODH, W, a
	    movf    error4,w,b
	    ADDWF   acc_error,b
	    
	    ; All this adding together of 5 registers might confuse the status register
	    ; might need to add in our own check for negativety, would just need to check if acc_error  is greater than 128
	    
	    
	    ; which way to turn
	    CLRF    PD_SIGN,b
	    movlw   128
	    CPFSGT  acc_error,b
	    BRA	    $+4
	    SETF    PD_SIGN,b
	    
	    RETURN
	    
	PID1:   
	    ; should be possible to trick the multiplication into working with decimal values without actually using decimal values
		; we can just shift the decimal point to the space between PRODH and PRODL
		; need to consider when the multiplication moves over the decimal point
	    ; easier option, just keep the values small enough that it stays in PRODL
		derivative_const equ 15
		proportional_const equ 6
		
	    MOVLW   proportional_const
	    MOVWF   Kp,b
	    MOVLW   derivative_const
	    MOVWF   Kd,b
	    Proportional:
	    MOVF    Kp,b  ; loading Kp into W
	    
	    tstfsz  PD_SIGN,b
	    negf    acc_error,b
	    
	    MULWF   acc_error,b
	    MOVF    PRODL, W, a
	    
	    tstfsz  PD_SIGN,b
	    negf    WREG,a
	    
	    MOVWF   prop_error,b
	    Derivative:
	    CLRF    extra,a
            MOVF    acc_error,w,b
	    SUBWF   prev_error,w,b; error = prev_error - error
	    BNN	    $+6
	    setf    extra,a
	    negf    WREG,a
	    MOVWF   deriv_error, b
	    ; MOVF    deriv_error, b
	    MULWF   Kd, b
	    movf    PRODL,w,a
	    tstfsz  extra,a
	    negf    WREG,a
	    MOVWF   deriv_error,b
	    MOVFF   acc_error, prev_error
	    Output:
            MOVF    prop_error,w,b
	    ADDWF   deriv_error,w,b
	    MOVWF   PD_OUTPUT,b
	    
	    ; checks to determine what the output should be
		; i know if prop is pos or neg
		; i know if deriv is pos or neg
		    ; just need to compare both in terms of size if they have sign differences
		    
	    clrf    WREG,a
	    tstfsz  extra,a
	    bcf	    WREG,0,a
	    tstfsz  PD_SIGN,b
	    bcf	    WREG,1,a
	    
	    ; are both positive?
	    tstfsz  WREG,a
	    bra	    $+4
	    return
	    
	    ; are both negative?
	    SUBLW   3
	    BNZ	    $+6
	    negf    PD_OUTPUT,b
	    return
	    
	    ; make both positive
	    tstfsz  extra,a
	    negf    deriv_error,b
	    tstfsz  PD_SIGN,b
	    negf    prop_error,b
	    
	    ; find difference
	    movf    deriv_error,b
	    subwf   prop_error,w,b
	    
	    ; if this is negative, it means prop is bigger
		; if prop is negative
		    ; negate PD_OUTPUT
		; return
			    
	    ; is proportional bigger?
	    BNN	    $+8
	    tstfsz  PD_SIGN,b ; check if prop is negative
	    negf    PD_OUTPUT,b
	    return
	    
	    ; if deriv is bigger
		; if deriv is negative
		    ; negate PD_OUTPUT
		    ; make PD_SIGN 255
		; if deriv is positive
		    ; make PD_SIGN 0
		; return
	    
	    ; derivative is bigger
	    tstfsz  extra,a ; check if deriv is negative
	    bra	    $+4
	    bra	    $+8
	    negf    PD_OUTPUT,b
	    setf    PD_SIGN,b
	    return
	    
	    clrf    PD_SIGN,b
	    
	    RETURN
	    
	CHANGE_OF_OUTPUTS:
    
	    
	    
	    ; now i dont know what it means when the PID output is positive or negative.
		; positive maps to right on the sensors
		; negative maps to left on the sensors
		
		; it stands to reason that a negative output means to turn left
		    ; which just means to adjust the left motor.
		    
	    ; now i just need to check if the PID output is higher than the default wheel speed duty cycle register.
		; if it is, then i need to invert the direction of the wheel that needs to be adjusted
		    ; need to subtract the default value from the PID output
			; then put that result in the duty cycle register of the wheel that needs to be adjusted.
			
	    ; left is connected to CPP1
	    
	    ; check if a wheel needs to reverse
	    movf    PD_OUTPUT,w,b
	    subwf   default_duty_cycle,w,b
	    bnn	    $+8
	    ; a wheel needs to reverse
	    tstfsz  PD_SIGN,b
	    bra	    right_reverse
	    bra	    left_reverse
	    ; both wheels forward
	    tstfsz  PD_SIGN,b
	    bra	    slow_right
	    bra	    slow_left
	    
	   
	    right_reverse:
		; never set one of these first, extra safety for the H-Bridge
		BCF	    STR1C
		BSF	    STR1B
		
		BCF	    STR2B
		BSF	    STR2C
		
		negf	WREG,a
		movwf   CCPR2L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR1L,a
		
		return
		
	    left_reverse:
		BCF	    STR2C
		BSF	    STR2B
		
		BCF	    STR1B
		BSF	    STR1C
		
		negf	WREG,a
		movwf   CCPR1L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR2L,a
		
		return
		
	    slow_right:
		BCF	    STR1C
		BCF	    STR2C
		BSF	    STR1B
		BSF	    STR2B
		
		movwf   CCPR2L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR1L,a
		
		return
		
	    slow_left:
		BCF	    STR1C
		BCF	    STR2C
		BSF	    STR1B
		BSF	    STR2B
		
		movwf   CCPR1L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR2L,a
		
		return 
	    
	    
	;need to figure out lost algorithm now    
	  LOST:
	    LOST_STOP:
		CALL BRAKES
		;bcf	wait_for_timer333,a
		;bsf	delay_333_call,a
		;CALL    delay_333
		;bcf	delay_333_call,a
          ;REVERSE UNTIL WE SEE LINE
		REVERSE:
		    ; need to change from the forward pins to the reverse pins
		    BCF	    STR1B
		    BCF	    STR2B
		    
		    BSF	    STR1C
		    BSF	    STR2C
    
		    movf    default_duty_cycle,w,b
		    movwf   CCPR1L,a
		    movwf   CCPR2L,a
		 
		    
		  return
	  ;TURN UNTIL MIDDLE SENSOR IS ON THE LINE:THE PID TAKES CARE OF THE SECOND PART
	  
		;call    wait_for_button_press	; this is here for the purposes of the dem0
	    RETURN
         
	BRAKES:
	    clrf    CCPR1L,a
	    clrf    CCPR2L,a
	    
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
    BSF	    follow_line  ;LOOP OVER LLI

		
STATE2:
software_tests:
    BTFSS   code_tests
    GOTO    STATE3
    
    TODO_code_tests: ; to-do todo to do
	nop
;   state 2 code
    ; to be added later
;    BRA	    $-2
    
TRANSITION2:
    BCF	    code_tests
    
    		
STATE3:
test_hardware:
    BTFSS   hardware_tests
    GOTO    SUBROUTINE0
    
    TODO_hardware_tests: ; to-do todo to do
    movlw   DUTY_50
    movwf   CPPR1L,a
    movwf   CPPR2L,a
;   state 2 code
    ; to be added later
    
TRANSITION3:
    BCF	    hardware_tests
    
;==========SUBROUTINES=======================
    
TRY_ALL_SUBROUTINES:
    
SUBROUTINE0:
TODO_DELAY_333_REPLACE_WITH_TIMER:
delay_333:
    BTFSS   delay_333_call
    GOTO    SUBROUTINE1
    BTFSC   skip_delay_333
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
	btfsc	wait_for_timer333
	bra	$-2
	
	; restore context
	movf    extra,w,a
	return
    
SUB_TRANSITIONS0:
    BCF	    delay_333_call
    
        
SUBROUTINE1:
delay_RGB:
    BTFSS   RGB_delay_call
    GOTO    SUBROUTINE2
	BTFSC	skip_delay_RGB
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
    BCF	    RGB_delay_call
    
        
SUBROUTINE2:
read_sensors:
    BTFSS   read_sensors_call
    GOTO    SUBROUTINE3
    
    TODO_make_states_with_this: ; to-do todo to do
    nop
    
    ; setup for indirect adressing
	; you need to use 'LFSR FSR0, XYZh' before calling this 
	; X is the bank
	; YZ is the starting register
    ;    LFSR 0, 100h ;need to remove, only here for initial creation purposes

    ; shine red
	bsf	    red_pin
	bsf	RGB_delay_call
	call delay_RGB
	bcf	RGB_delay_call

	    ; testing code, should do nothing if test_en = 0
		btfss   test_en,a
		bra	    $+8
		call    dummy_read_all_sensors
		bra	    $+6
	    ; end of testing code

	call    read_all_sensors
	bcf	    red_pin

    ; shine green
	bsf	    green_pin
	bsf	RGB_delay_call
	call delay_RGB
	bcf	RGB_delay_call

	    ; testing code, should do nothing if test_en = 0
		btfss   test_en,a
		bra	    $+8
		call    dummy_read_all_sensors
		bra	    $+6
	    ; end of testing code

	call    read_all_sensors
	bcf	    green_pin

    ; shine blue
	bsf	    blue_pin
	bsf	RGB_delay_call
	call delay_RGB
	bcf	RGB_delay_call

	    ; testing code, should do nothing if test_en = 0
		btfss   test_en,a
		bra	    $+8
		call    dummy_read_all_sensors
		bra	    $+6
	    ; end of testing code

	call    read_all_sensors
	bcf	    blue_pin

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
    BCF	    read_sensors_call
    
        
SUBROUTINE3:
detect_colour:
    BTFSS   check_colour
    GOTO    SUBROUTINE4
    
    TODO_make_this_work_with_states_1:  ; to-do todo to do
    
	; clear the previous colours
	clrf    SENSOR0,a
	clrf    SENSOR1,a
	clrf    SENSOR2,a
	clrf    SENSOR3,a
	clrf    SENSOR4,a
	
	; read sensors to bank 2 for now
	LFSR    0, 200h	
	BSF	read_sensors_call
	call	read_sensors
	BCF	read_sensors_call
	; back to bank 2
	LFSR    0, 200h	

	; always check for white first
	white_check:
    
		white_red_check:
    
	    
	    ;sensor 0
	    clrf	red_check_bits,a

	    movf    white_red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,0,a


	    ; movf    white_red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,1,a

	    ; movf    white_red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,2,a

	    ; movf    white_red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,3,a

	    ; movf    white_red_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    red_check_bits,4,a


		white_green_check:


	    ;sensor 0
	    clrf	green_check_bits,a

	    movf    white_green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,0,a

	    ; movf    white_green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,1,a

	    ; movf    white_green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,2,a

	    ; movf    white_green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,3,a

	    ; movf    white_green_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    green_check_bits,4,a


		white_blue_check:


	    ;sensor 0
	    clrf	blue_check_bits,a

	    movf    white_blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,0,a

	    ; movf    white_blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,1,a

	    ; movf    white_blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,2,a

	    ; movf    white_blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
	    bsf	    blue_check_bits,3,a

	    ; movf    white_blue_thresh,w,a
	    cpfsgt  POSTINC0,a
	    bra	    $+4
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

	    TODO_change_from_FSR1_to_FSR0:
	    lfsr    1,059h
	    movlw	7
	    cpfseq	check,a
	    bra	$+6
	    ; it sees white
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
	    ; it sees white
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
	    ; it sees white
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
	    ; it sees white
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
	    ; it sees white
	    movlw	'W'
	    movwf	INDF1,a
	    
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
	    TODO_also_change_FSR1_to_FSR0_for_these_checks:
	    nop
	    TODO_maybe_put_a_checking_order_for_the_colours:
	    nop

	check_green:
	    lfsr	1,200h
	    movlw	5
	    ;addwf	FSR0,f,a
	    addwf	FSR1,f,a

	    
	    ; sensor 0
	    clrf	green_check_bits,a
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,0,a

	    ; sensor 1
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,1,a

	    ; sensor 2
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,2,a

	    ; sensor 3
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,3,a

	    ; sensor 4
	    movf    POSTINC1,w,a
	    cpfslt  green_thresh,a
	    bra	    $+4
	    bsf	    green_check_bits,4,a

	    red_checks:
	    LFSR    1, 200h	

	    
	    clrf	red_check_bits,a
	    
	    ; sensor 0
	    btfsc	green_check_bits,0,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,0,a

	    ; sensor 1
	    btfsc	green_check_bits,1,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,1,a

	    ; sensor 2
	    btfsc	green_check_bits,2,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,2,a

	    ; sensor 3
	    btfsc	green_check_bits,3,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  red_thresh,a
	    bra	    $+4
	    bsf	    red_check_bits,3,a

	    ; sensor 4
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

	    
	    clrf	blue_check_bits,a
	    
	    ; sensor 0
	    btfss	red_check_bits,0,a
	    btfsc	green_check_bits,0,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,0,a

	    ; sensor 1
	    btfss	red_check_bits,1,a
	    btfsc	green_check_bits,1,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,1,a

	    ; sensor 2
	    btfss	red_check_bits,2,a
	    btfsc	green_check_bits,2,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,2,a

	    ; sensor 3
	    btfss	red_check_bits,3,a
	    btfsc	green_check_bits,3,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,3,a

	    ; sensor 4
	    btfss	red_check_bits,4,a
	    btfsc	green_check_bits,4,a
	    bra	$+10
	    movf    POSTINC1,w,a
	    cpfslt  blue_thresh,a
	    bra	    $+4
	    bsf	    blue_check_bits,4,a


	    checking_colours:
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
	    cpfseq	SENSOR0,a   ; did the white check give this a colour already?
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks    ; no

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
	    cpfseq	SENSOR1,a   ; did the white check give this a colour already?
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks    ; no

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
	    cpfseq	SENSOR2,a   ; did the white check give this a colour already?
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks    ; no

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
	    cpfseq	SENSOR3,a   ; did the white check give this a colour already?
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks    ; no

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
	    cpfseq	SENSOR4,a   ; did the white check give this a colour already?
	    bra	$+4
	    bra	$+6
	    call    run_detection_checks    ; no
	return
	    run_detection_checks:
    
		movlw   0
		cpfseq  check,a
		bra	    $+8
		; it sees black
		movlw   'K'
		movwf   INDF1,a
		RETURN

		movlw   1
		cpfseq  check,a
		bra	    $+8
		; it sees red
		movlw   'R'
		movwf   INDF1,a
		RETURN

		movlw   2
		cpfseq  check,a
		bra	    $+8
		; it sees green
		movlw   'G'
		movwf   INDF1,a
		RETURN

		movlw   4
		cpfseq  check,a
		bra	    $+8
		; it sees blue
		movlw   'B'
		movwf   INDF1,a
		RETURN

		TODO_add_error_case_for_this:
		; default to white for now
		movlw   'W'
		movwf   INDF1,a

		return

    
SUB_TRANSITIONS3:
    BCF	    check_colour
        
    
SUBROUTINE4:
    TODO_this_should_be_changed_for_serial_bridge_comms:
    nop
show_colour:
    BTFSS   show_the_colours
    GOTO    SUBROUTINE5
    
    ; check solid colour
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
	return

    
SUB_TRANSITIONS4:
    BCF	    show_the_colours
        
    
SUBROUTINE5:
flash:
    BTFSS   flash_port_d
    GOTO    SUBROUTINE6
    
	; number of flashes
	movlw   3
	movwf   count,a
	; save portD
	movf    PORTD,w,a
	BEGIN_FLASH:
	; begin flashing
	    ; turn off
	clrf    PORTD,a
	    ;wait 0.166 seconds
	bsf	wait_for_timer333
	bsf	delay_333_call
	call    delay_333
	bcf	delay_333_call
	    ; turn on
	movwf   PORTD,a
	    ;wait 0.166 seconds
	bsf	wait_for_timer333
	bsf	delay_333_call
	call    delay_333
	bcf	delay_333_call
	; did we flash enough?
	decfsz  count,a
	bra	BEGIN_FLASH	; no
	; yes
	return
    
SUB_TRANSITIONS5:
    BCF	    flash_port_d
        
    
SUBROUTINE6:
wait_for_button_press:
    BTFSS   button_press_check
    GOTO    STATE_MACHINE_END
    
	btfss   INT0IF	    ;wait for button press
	bra	    $-2
	; delay so that we dont have to debounce
	bsf	wait_for_timer333
	bsf	delay_333_call
	call    delay_333
	bcf	delay_333_call
	; reset button wait
	bcf	    INT0IF
	; go back
	return
    
SUB_TRANSITIONS6:
    BCF	    button_press_check
    
    
STATE_MACHINE_END:
    
GOTO    STATE_MACHINE_START   ; LOOP OVER ALL STATES

    
;======INTERRUPTS===========
    
ISR:
    btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
    goto    register_dump   
    btfsc   TMR0IF	    ; was it timer 0?
    goto    timer0_interrupt
    
    retfie


register_dump:
    incf    count,a
    movff   line_reg, PORTC     ; put line_reg into PORTC
    bcf	    INT1IF		; clear interrupt flag
    retfie			            ;return from interrupt

timer0_interrupt:
    ; check if the wait bit for timmer333 was set
    btfsc   wait_for_timer333
    bra	    $+10
    ; if it was, just clear the wait and return
    bcf	    wait_for_timer333
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
