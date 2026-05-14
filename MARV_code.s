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

;<editor-fold defaultstate="collapsed" desc="Variables">

    ;sample_wait     equ 0x00
    black_seen_count     equ 0x01


    lost_count		equ 0x02

    misc_checks		equ 0x03
    #define race_colour_seen	misc_checks,0,a
    #define black_flag		misc_checks,1,a
    #define Rx_done		misc_checks,2,a

    sample_wait	equ 0x04
    number_of_readings	    equ 0x05

    ;<editor-fold defaultstate="collapsed" desc="State Machine Variables">

	; state machine bits
	state_0		equ 0x06
	#define calibrate	state_0,0,a
	#define follow_line	state_0,1,a
	#define code_tests	state_0,2,a
	#define hardware_tests	state_0,3,a
	#define	touch_start	state_0,4,a

	; sub-routine bits
	subroutine_0	equ 0x07
	#define delay_333_call	    subroutine_0,0,a  ;166ms
	#define RGB_delay_call	    subroutine_0,1,a  ;1.2ms

	#define read_sensors_call   subroutine_0,2,a
	#define check_colour	    subroutine_0,3,a

	#define show_the_colours    subroutine_0,4,a
	#define	flash_colour_display	    subroutine_0,5,a
	#define button_press_check  subroutine_0,6,a
	#define colour_display	    subroutine_0,7,a

; delay skip bits
DELAY_SKIP		equ	0x08
#define skip_delay_333		DELAY_SKIP,0,a
#define skip_delay_RGB		DELAY_SKIP,1,a

    ;</editor-fold>

    timer_waits		equ	0x09
    #define	wait_for_timer333   timer_waits,0,a
    #define	wait_for_timerRBG   timer_waits,1,a
    #define wait_for_timer2	    timer_waits,2,a

    offset_stuff	equ 0x0F
    reading_count	equ 0x10
    count		equ 0x11
    ;   dont use address 0x13, strange things afoot
    extra		equ 0x19

    ;<editor-fold defaultstate="collapsed" desc="Colour Related Variables">

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

    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="LLI registers">

	SENSOR_START	equ 059h
	SENSOR0        EQU 0x59
	SENSOR1        EQU 0x5A
	SENSOR2        EQU 0x5B
	SENSOR3        EQU 0x5C
	SENSOR4        EQU 0x5D
	RACE_COLOUR    EQU 0x5E
	BLACK_FLAG     EQU 0x5F
     
     
	; MOTOR DEFINTIONS
	; PID variables
	line_seen	    equ 0x72
	default_duty_cycle  equ	0x73

	PD_OUTPUT       EQU   0x79

	prop_error      equ   0x7C

	deriv_error     equ   0x7D
	prev_error	equ   0x7E

	acc_error       equ   0x7F

	error0          equ   0x80
	error1          equ   0x81
	error2          equ   0x82
	error3          equ   0x83
	error4          equ   0x84

	PD_SIGN         EQU   0x85
    
	 
	; PD constants
	Kd  equ 20
	Kp  equ 60


	; sensor value mapping
	s0_value        equ   -4
	s1_value        equ   -2
	s1_value_e	equ	-1
	s2_value        equ   0
	s3_value_e	equ	1
	s3_value        equ   2
	s4_value        equ   4


	;DUTY CYCLE DEFINITIONS
	MIN_DUTY    equ 10
	DUTY_25     equ 31
	DUTY_50     equ 62
	DUTY_75     equ 93
	DUTY_100    equ 123
    
	DUTY_MISC   equ	80
   
	DUTY_STOP   equ 0
		
	lost_thresh equ -30
 
	black_seen_thresh   equ 3
     

    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="Touch Start variables">

	touch_flag	EQU 0x60
	Vread		EQU 0x61
	OpenSW		EQU 0x62
	Trip		EQU 0x63
	Hyst		EQU 0x64
	DIFF		EQU 0x65

    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="I2C Variables">
    
	TX_BYTE         EQU 0x30
	POLL_COUNTER    EQU 0x31
	Delay1          EQU 0x32
	Delay2          EQU 0x33
	EEPROM_ADDRESS  EQU 0x34
	CHAR_COUNT      EQU 0x35
	CHAR_WRITE      EQU 0x36

	PAGE_COUNT	equ 0x38
	page_byte_count equ 0x39
 

	WRITE_CONTROL   EQU 10100000B
	READ_CONTROL    EQU 10100001B
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Serial Variables">
	
	RCFlag		EQU 0x3B
	ERRORFlag	EQU 0x3C
	DelayCount	EQU 0x3D    
    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="Magic Numbers">
    
	; variables to reduce magic numbers
	ADC_AN0		equ 0b00000011 ; 0 00000 1 1
	ADC_AN1 	equ 0b00000111 ; 0 00001 1 1
	ADC_AN2 	equ 0b00001011 ; 0 00010 1 1
	ADC_AN3 	equ 0b00001111 ; 0 00011 1 1
	ADC_AN4 	equ 0b00010011 ; 0 00100 1 1

	ADC_AN6		equ 0b00011001 ; 0 00110 0 1

	calib_address	equ 100h
	
    ;</editor-fold>
	
;</editor-fold>

;
; -------------	
; PROGRAM START	
; -------------
;
    PSECT code,abs //Start of main code.
    org	    0x00 			; startup address = 0000h
    goto init
    org     0x08            ; interrupt start
    
    BTFSC   RCIF	    ; was it Rx?
    GOTO    Rx_ISR
    btfsc   TMR4IF	    ;was it timer 4?
    goto    TIMER4_ISR
    goto ISR


;<editor-fold defaultstate="collapsed" desc="Initialisation">
init:
    
    ;<editor-fold defaultstate="collapsed" desc="Clock Setup">
	; Set oscillator speed at 4 MHz
	bsf 	IRCF0
	bcf	IRCF1
	bsf	IRCF2
	
    ;</editor-fold>
	
    MOVLB   0xF	; work in bank 15, not all SFRs are in access bank
    
    ;<editor-fold defaultstate="collapsed" desc="Port A Setup">
	
	; setup ADC and RGB pins
	CLRF    PORTA,a 	; Initialize PORTA by clearing output data latches
	CLRF    LATA,a	; Alternate method to clear output data latches
	movlw   0b00101111
	movwf   ANSELA,b 	; sets pins A 0,1,2,3 and 5 to analogue     ADC
			    ; also sets pins A 4,6 and 7 to digital     RGB
	movwf   TRISA,a	; sets pins A 0,1,2,3 and 5 to input        ADC
			    ; also sets pins A 4,6 and 7 to outputs     RGB
			
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="ADC Setup">

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
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Port C Setup">
    
	; register dump port
	clrf    PORTC, a
	clrf    LATC, a
	clrf    ANSELC, b
	clrf    TRISC, a
	
	BSF     TRISC,3          ; RC3 = SCL1
	BSF     TRISC,4          ; RC4 = SDA1
	
	BSF     TRISC,6          ; RC6 = Tx1
	BSF     TRISC,7          ; RC7 = Rx1
	
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Port D Setup">
    
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
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Port B Setup">
    
	; Set up PORTB
	clrf    PORTB, a
	clrf    LATB, a
	clrf    ANSELB, b
	clrf    TRISB, a
	bsf	    TRISB,1,a	; RB1 is input(INT1I)
	bsf	    TRISB,6,a	; just in case programmer for debugging is complaining
	; clrf    WPUB,a      ; no more weak pull up for PORTB
    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="PWM Init">

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
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Port E Setup">
    
	;Setup PORTE
	CLRF    ANSELE,b
	CLRF    PORTE,a
	CLRF    LATE,a
	CLRF    TRISE,a
	BSF	    ANSELE,1,b
	BSF	    TRISE,1,a
	; config because of LVP change
	bsf	TRISE,3,a
	
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Timer 0 and 1 Setup">
    
	; Timer setup
	clrf    T0CON,a
	clrf    T1CON,a
	clrf    T1GCON,a
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Interrupt flag clears">
    
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
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Capacitive Touch Setup">
    
	;Setup for touch pad
	;CTMU modules
	CLRF    CTMUCONH,b
	movlw   0b00000010
	movwf   CTMUICON,b
	movlw   0b10010000 
	movwf   CTMUCONL,b
	movlw   0b10001000
	movwf   CTMUCONH,b

	;Timer4 init for touch pad

	movlw   0b00000000
	movwf   T4CON,b
	movlw   125
	movwf   PR4,b
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="I2C Setup">
    
	; 100 kHz @ Fosc = 4 MHz
	    ; 4 MHz / (4 * 100 kHz) - 1 = 9
	    MOVLW   9
	    MOVWF   SSP1ADD

	    ; SSP1STAT
	    CLRF    SSP1STAT
	    BSF     SSP1STAT,7       ; SMP = 1 for standard speed mode

	    ; SSP1CON1: I2C Master mode, clock = FOSC/(4 * (SSPADD + 1))
	    MOVLW   00101000B
	    MOVWF   SSP1CON1

	    ; SSP1CON2
	    CLRF    SSP1CON2

	    ; Clear interrupt flags
	    BCF     SSP1IF
	    BCF     BCL1IF

    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Setial Comms Setup">
    
	; Baud rate setup (Datasheet RX#1)
	MOVLW   12			; 19200 BAUD @ 4 MHz
				    ; table 18-5 of datasheet
	; MOVLW   25			; 9600 BAUD @ 4 MHz
	MOVWF   SPBRG1	  	; load baudrate register
	CLRF    SPBRGH1
	BSF     TXSTA1,2		; Enable high BAUDrate
	BCF	BAUDCON1,3		; Use 8 bit baud generator

	; Enable asynchronous serial port
	BCF     TXSTA1,4		; Enable asynchronous transmission
	BSF	RCSTA1,7		; Enable Serial Port (Datasheet RX#3)

	; Transmit setup (TX)
	BSF	TXSTA1,5		; Enable transmit

	; Receive setup (RX)
	BSF	RCSTA1,4		; Enable continuous reception (Datasheet RX#6)

    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Interrupts">

	; INTCON2 = 0b 0 0 0 0 x 0 x 0 
	; bsf	    INTCON2,7,a	; no RBPU
	; bsf	    INTCON2,5,a	; INT1I reacts on rising edge
	; INTCON3 = 0b 0 1 x 0 1 x 0 0
	clrf    INTCON3,a	;
	bsf     INT1IP	    ; INT1I priority is high
	bsf	INT1IE	    ; INT1I is enabled
	; INTCON = 0b 1 0 1 0 0 0 0 0
	bsf	    TMR0IE	    ; enable timer 0 interrupts
	bsf	    TMR2IP	    ; enable timer 4 interrupts
	
	; serial comms interrupt
	BCF	RCIF			; Clear RCIF Interrupt Flag
	BSF	RCIP
	BSF	RCIE			; Set RCIE Interrupt Enable (Datasheet RX#4)

	BSF	    PEIE
	bsf	    GIEH	    ; enable high priority interupts
	bsf	    TMR4IE
	; bsf	    GIEL,a	; enable low priority interupts
    
    ;</editor-fold>
    
    MOVLB   0x0	; back to bank 0 for normal opperations
    
    ;<editor-fold defaultstate="collapsed" desc="Clearing Variables">
    
	movlw   1
	movwf   number_of_readings,a
	clrf    SENSOR0,a
	clrf    SENSOR1,a
	clrf    SENSOR2,a
	clrf    SENSOR3,a
	clrf    SENSOR4,a
	clrf    RACE_COLOUR,a
    
	;initializing touch pad variables
	clrf    touch_flag,b	
	clrf    Vread,b		
	clrf    OpenSW,b		
	clrf    Trip,b		
	clrf    Hyst,b		
	clrf    DIFF,b

	clrf    race_error_colour_magic,a
	
	movlw   DUTY_MISC
	movwf   default_duty_cycle,b
	
	MOVLW	lost_thresh
	MOVWF	lost_count,a
	
	;MOVLW	-20
	;MOVWF	race_error_navigations,a
	
	CLRF    RCFlag
	CLRF    ERRORFlag
	CLRF    DelayCount
    
    ;</editor-fold>
    
    
    ;<editor-fold defaultstate="collapsed" desc="Setting Detection Tolerances">
    
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
	
    ;</editor-fold>

;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="State Machine Setup">
    
    STATE_MACHINE_SETUP:
    ;<editor-fold defaultstate="collapsed" desc="Clear State Control Bits">
    
	CLRF    state_0,a
	CLRF    subroutine_0,a
	CLRF    DELAY_SKIP,a
	CLRF    timer_waits,a
    
    ;</editor-fold>
    
    ;<editor-fold desc="State Control Bits">
    
	;Set touch start bit first so that the program waits for the touch pad to be touched
	; State activation bits
	;BSF calibrate
	;BSF	touch_start
	;BSF follow_line
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Test States">
    
	; tests
	;BSF code_tests
	;BSF hardware_tests
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Subroutine Control Bits">
    
	; Subroutine activation bits
	;BSF delay_333_call
	;BSF RGB_delay_call
	;BSF read_sensors_call
	;BSF check_colour
	;BSF show_the_colours
	;BSF flash_colour_display
	;BSF button_press_check
	;BSF colour_display
    
    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="Delay Skip Bits">

	; Delay skips
	;BSF skip_delay_333
	;BSF skip_delay_RGB
	
    ;</editor-fold>
    
;</editor-fold>
    
STATE_MACHINE_START:
    
;<editor-fold desc="State Control Bits">
    STATE_CONTROLLER:
	//    SECTIONS TO HANDLE IN THIS
	    //    Power-on greeting
	    //    Menu options
	    //    (C)colour
	    //    (R)eference
	    //    (A)ttack
	    //    (S)imulate race
	    //    (H)otload EEPROM
	    
	//    this needs to control which state we go to
	//    it needs a way to interpret commands
	
	//    everything here needs to be controlled by bits.
	    //    the control bits for the main functions need to be controlled here.
	    //    the state or menu option that we are in has to be kept track of with bits.
	
	READ_FROM_SERIAL:
	    //   might not be needed
	
	INTERPRET_COMMAND:
	    //   I DONT THINK THIS IS NEEDED. WE CAN JUST MAKE IT SO THAT MAIN MENU HAS TO PROCESS EVERY TYPE OF COMMAND, AND THE OTHER 
	    //   ONES JUST HAVE TO CHECK IF THE COMMAND IS "M" TO RETURN TO MAIN MENU, OR JUST RETURN TO IT BY DEFAULT.
    
	CYOC:
	    //    THE POWER ON MESSAGE
	    
		; eeprom address is 88
		; last char is a CR (0x0D) character, will make the I2C read check for this
		MOVLW   88
		CLRF    EEPROM_ADDRESS
		MOVLW   -88
		MOVWF   CHAR_COUNT
		
	    ;--- Stream data to 0x200 in data memory
		LFSR    0, 0x200
		
		CALL	READ_EEPROM
		
		MOVFF	FSR0L, count
		
		LFSR    0, 0x200
		
		movf	POSTINC0,W
		CALL	BYTE_TX
		DECFSZ	count
		BRA	$-8
		
		RETURN
	    
	MAIN_MENU:
	    //    SPEAKS FOR ITSELF, JUST READ THE EEPROM, AND THEN TRANSMIT IT WITH Tx

		; eeprom address is 0
		; char count is 86
		CLRF    EEPROM_ADDRESS
		MOVLW   86
		MOVWF   CHAR_COUNT
		
	    ;--- Stream data to 0x200 in data memory
		LFSR    0, 0x200
		
		CALL	READ_EEPROM
		
		LFSR    0, 0x200
		
		movf	POSTINC0,W
		CALL	BYTE_TX
		DECFSZ	count
		BRA	$-8
		
		BTFSS	Rx_done
		BRA	$-2
		
		BCF	Rx_done
		
		// NOW TO CHECK EVERY SINGLE CASE  FOR THE COMMANDS
		
	COLOUR:
	    //    DECIDE THE RACE COLOUR, LIKELY WITH Rx
    
	REFERENCE:
	    //    GO TO CALIBRATION SEQUENCE
    
	ATTACK:
	    //    GO TO LLI
    
	SIMULATE_RACE:
	    //    BASICALLY IT'S OWN STATE MACHINE
	    
	    SEND_SENSORS:
	    //    WE NEED TO DECIDE IF IT WILL CONSTANTLY SEND SENSOR READINGS OR JUST SEND THE CURRENT SENSOR VALUE WHEN WE ENTER THE COMMAND
    
	    CHANGE_DIRECTION:
    
	HOTLOAD_EEPROM:
	    //    READ FROM Rx AND PROGRAM TO EEPROM
		LFSR    0,100h
    
	    RECIEVE_MESSAGE:
	    //	  write recieved to Bank 1
		BTFSS	Rx_done
		BRA	$-2
		
		BCF	Rx_done
		
		MOVLW	2
		CPFSEQ	FSR0L
		BRA	CHANGE_EEPROM
		
		MOVLW	'M'
		MOVFF	100h,extra
		CPFSEQ	extra
		BRA	CHANGE_EEPROM
		
		GOTO	MAIN_MENU
		
    
	    CHANGE_EEPROM:
	    //	  how many pages to write
		MOVLW	0
		CLRF    PAGE_COUNT
		ADDLW	8
		INCF	PAGE_COUNT
		CPFSLT	FSR0L
		BRA	$-6
	    //	  start address of power on message
		MOVLW	88
		MOVWF	EEPROM_ADDRESS
		LFSR    0,100h
		
		call	MULTI_PAGE_WRITE
		
		GOTO	HOTLOAD_EEPROM
    
	ECHO:

    
    
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Calibration">
    STATE0:
    calibration:
	BTFSS   calibrate
	GOTO    STATE1

	;<editor-fold defaultstate="collapsed" desc="Calibrate Red">
	    ; red
	    LFSR    0, 100h
	    movlw   1
	    movwf   number_of_readings,a
	    MOVLW	red_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call


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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Calibrate Green">
	    ;green
	    lfsr    0, 100h
	    MOVLW	green_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call


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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Calibrate Blue">

	    ;blue
	    lfsr    0, 100h
	    MOVLW	blue_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call


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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Calibrate Black">

	    ;black
	    lfsr    0, 100h
	    MOVLW	black_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call


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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Calibrate White">

	    ;white
	    lfsr    0, 100h
	    MOVLW	white_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call


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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Select Race Colour">

	race_colour_selection:
	
	    MOVLW	error_indicator
	    MOVWF	DISPLAYED_COLOUR,a

	    bsf		button_press_check
	    call    wait_for_button_press_show_colour
	    bcf		button_press_check

	    BSF	check_colour
	    call    detect_colour
	    BCF	check_colour

	    ; Race colour
	    movff   SENSOR2,RACE_COLOUR

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

	    bsf		flash_colour_display
	    call 	flash
	    bcf		flash_colour_display

	;</editor-fold>

    TRANSITION0:
	BCF	    calibrate
	BSF	    touch_start
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Touch start">
    
    STATE1:
    touch_to_start:
	BTFSS   touch_start
	GOTO    STATE2
	;Load threshold values. Change according to the touch pad used

    ;    MOVLW	0b00001001; AN2
	MOVLW	ADC_AN6; AN6, PORTE 1
	MOVWF	ADCON0,a
	BCF		TRISE1
	NOP
	BSF		TRISE1

	CAP_TOUCH:

	    movlw   60
	    movwf   OpenSW,b	;unpressed switch value
	    movlw   1
	    movwf   Trip,b	;difference between pressed and unpressed switch
	    movlw   1
	    movwf   Hyst,b	;amount to change from pressed to unpressed
	CHECK_TOUCH:
	    MOVF    Trip,W,b
	    SUBWF   OpenSW,w,b
	    MOVWF   DIFF,b	;DIFF is OpenSW - Trip. This is the base comparison

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
	    MOVF	    ADRESH,W,a
	    MOVWF	    Vread,b

	    ;test if Vread = 0
	    MOVLW   0
	    CPFSEQ  Vread,b
	    GOTO    CHK_P_OR_UP
	    BSF	PORTA,7,a
	    GOTO    CHECK_TOUCH

	;Check if pressed or unpressed
	CHK_P_OR_UP:
	    ;Check for pressed
	    MOVF    DIFF,W,b
	    CPFSLT  Vread  ,b
	    GOTO    PAD_PRESS
	    ;Check for unpressed
	    MOVF    Hyst,W,b
	    ADDWF   DIFF,b
	    MOVF    DIFF,W,b
	    CPFSGT  Vread,b
	    GOTO    PAD_UNPRESS
	    GOTO    CAP_TOUCH	;Loop touch start sequence until pad is pressed

	PAD_PRESS:
	    BCF	    PORTA,7,a
	    BSF	    PORTA,4,a
	    GOTO	    TOUCH_TRANSITION
	PAD_UNPRESS:
	    BCF	    PORTA,4,a
	    BSF	    PORTA,7,a
	    GOTO	    CHECK_TOUCH
	TOUCH_TRANSITION:
	    ; BCF	    touch_start
	    BCF	    PORTA,4,a
	    BCF	    PORTA,7,a
	    
	    BSF	    TMR2IE
	    
	    GOTO	    TRANSITION1
	CAP_DELAY: 
	    MOVLB	    0xF
	    CLRF	    TMR4,b
	    BSF	    TMR4ON
	    MOVLB	    0x0
	WAIT1:
	    BTFSS	    touch_flag,0,b
	    BRA	    WAIT1
	    BCF	    touch_flag,0,b
	    BCF	    TMR4ON

	    RETURN
	TIMER4_ISR:  ;moved the ISR here because if it is way down under, it affects the charging time for the current on the touchpad, giving low values. 
	;Also added/moved the timer2 ISR to the org 0x08 to check if it is timer2 ISR or the normal ISR.

	BSF	    touch_flag,0,b

	    BCF	    TMR4IF

	    RETFIE
    TRANSITION1:
	BCF	    touch_start
	BSF	    follow_line
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="LLI">
    	
    STATE2:
    LLI:	
	BTFSS   follow_line
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

	;STRAIGHT:
	    
	    ; force sampling rate to be equal to timer 2 rate
	    
	    ; wait for a certain amount of duty cycles
	    movlw   2
	    movwf   sample_wait,a
	    BSF	    wait_for_timer2
	    BTFSC   wait_for_timer2
	    bra	    $-2
	    decfsz  sample_wait,a
	    bra	    $-8
	    
	    ; setup
	    CLRF error0,b
	    CLRF error1,b
	    CLRF error2,b
	    CLRF error3,b
	    CLRF error4,b
	    clrf    line_seen,b
	    
	    BSF	    check_colour
	    call detect_colour
	    BCF	    check_colour
	    
	;<editor-fold defaultstate="collapsed" desc="Colour interpreter">
	    
	    ;SENSOR0 check
	    movlw   'e'
	    CPFSEQ  SENSOR0,a
	    bra	    $+8
	    movlw   s1_value
	    MOVWF   error0,b
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,w,a
	    CPFSEQ  SENSOR0,a
	    bra	    $+10
	    movlw   s0_value
	    MOVWF   error0,b
	    setf    line_seen,b
	    BSF	    race_colour_seen
	    
	    
	    ;SENSOR1 check
	    movlw   'e'
	    ;MOVF    SENSOR1,W,a
	    CPFSEQ  SENSOR1,a
	    bra	    $+8
	    movlw   s1_value_e
	    MOVWF   error1,b
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,w,a
	    CPFSEQ  SENSOR1,a
	    bra	    $+10
	    movlw   s1_value
	    MOVWF   error1,b
	    setf    line_seen,b
	    BSF	    race_colour_seen
	    
	    
	    ;SENSOR2 check
	    movlw   'e'
	    ;MOVF    SENSOR2,W,a
	    CPFSEQ  SENSOR2,a
	    bra	    $+8
	    movlw   s2_value
	    MOVWF   error2,b
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    cpfseq  SENSOR2,a
	    bra	    $+10
	    movlw   s2_value
	    MOVWF   error2,b
	    setf    line_seen,b
	    BSF	    race_colour_seen
	    
	    
	    ;SENSOR3 check
	    movlw   'e'
	    ;MOVF    SENSOR3,W,a
	    CPFSEQ  SENSOR3,a
	    bra	    $+8
	    movlw   s3_value_e
	    MOVWF   error3,b
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    CPFSEQ  SENSOR3,a
	    bra	    $+10
	    movlw   s3_value
	    MOVWF   error3,b
	    setf    line_seen,b
	    BSF	    race_colour_seen
	    
	    
	    ;SENSOR4 check
	    movlw   'e'
	    ;MOVF    SENSOR4,W,a
	    CPFSEQ  SENSOR4,a
	    bra	    $+8
	    movlw   s3_value
	    MOVWF   error4,b
	    setf    line_seen,b
	    
	    MOVF    RACE_COLOUR,W,a
	    CPFSEQ  SENSOR4,a
	    bra	    $+10
	    movlw   s4_value
	    MOVWF   error4,b
	    setf    line_seen,b
	    BSF	    race_colour_seen
	    
	;</editor-fold>
	    
	;<editor-fold defaultstate="collapsed" desc="Checking if Stop or Lost conditions need to be considered">
	
	Stop_or_Lost_Check:
	    ; check if the line was seen
	    tstfsz  line_seen,b
	    bra	    $+10
	    CALL    CHECK_BLACK
	    GOTO    TRANSITION1
	    
	    ;BTFSC   race_colour_seen
	    ;bra	    $+6
	    ;INCFSZ  race_error_navigations,a
	    ;bra	    $+14
	    ;goto    LOST_STOP
	    
	    MOVLW	lost_thresh
	    MOVWF	lost_count,a
	    
	    ;MOVLW	-20
	    ;MOVWF	race_error_navigations,a
	    
	    ; i want to add something to this that gives the lost condition a bit of time to kick in
	    ; something like a sample delay, it has to be lost for a number of samples before it is actually lost
	    
	    ; along with this, it would maybe be worth it to treat race_error as something functionally different from
	    ; the race colour. It can still treat it as a value to consider in the PID, but if the race_colour isn't seen
	    ; for a as long as the it takes to be lost, then it will be lost.
	        
	;</editor-fold>
	    
	;<editor-fold defaultstate="collapsed" desc="Error calc">
	    
	ERROR_CALC:
	    ; small bit of setup for this
            CLRF    acc_error, b
	    
	    ; SENSOR 0
	    movf    error0,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 1
	    movf    error1,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 2
	    movf    error2,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 3
	    movf    error3,w,b
	    ADDWF   acc_error,b
	    
	    ; SENSOR 4
	    movf    error4,w,b
	    ADDWF   acc_error,b
	    
	    ; All this adding together of 5 registers might confuse the status register
	    ; so we add in our own check for negativety
		; basically just checking if acc_error is greater than 128
		; this helps determine which way to turn
	    CLRF    PD_SIGN,b
	    movlw   128
	    CPFSGT  acc_error,b
	    BRA	    $+4
	    SETF    PD_SIGN,b
	    
	;</editor-fold>
	
	;<editor-fold defaultstate="collapsed" desc="PID">
	    
	    PID1:   

	    Proportional:
	    MOVLW    Kp		; loading Kp into W
	    
	    ; checing negativity
	    tstfsz  PD_SIGN,b
	    negf    acc_error,b	    ; make this positive because of MULWF
	    
	    MULWF   acc_error,b
	    MOVF    PRODL, W, a
	    
	    ; preserving negativity after multiplication
	    tstfsz  PD_SIGN,b
	    negf    WREG,a
	    
	    MOVWF   prop_error,b
	    
	    tstfsz  PD_SIGN,b
	    negf    acc_error,b	    ; restore sign
	    
	    Derivative:
	    ; using this for storing the negativity of this part
	    CLRF    extra,a
	    
            MOVF    prev_error,w,b
	    SUBWF   acc_error,w,b  ; change = error - prev_error
	    BNN	    $+6
	    setf    extra,a	    ; save negativity
	    negf    WREG,a	    ; make positive for multiplication
	    
	    ; multiplication prep
	    MOVWF   deriv_error, b
	    movlw   Kd
	    
	    MULWF   deriv_error, b
	    movf    PRODL,w,a
	    ; preserving negativity again
	    tstfsz  extra,a
	    negf    WREG,a
	    
	    MOVWF   deriv_error,b
	    ; saving the error for the next run of the PD
	    MOVFF   acc_error, prev_error
	    
	    Output:
	    ; the basic math
            MOVF    prop_error,w,b
	    ADDWF   deriv_error,w,b
	    MOVWF   PD_OUTPUT,b
	    
	    ; checks to determine if the output is positive or negative

	    clrf    WREG,a
	    tstfsz  extra,a
	    movlw   2
	    tstfsz  PD_SIGN,b
	    incf    WREG,a
	    
	    ; are both positive?
	    tstfsz  WREG,a
	    bra	    $+4
	    bra	    CCHANGE_OF_OUTPUTS
	    
	    ; are both negative?
	    ADDLW   -3
	    BNZ	    $+6
	    negf    PD_OUTPUT,b
	    bra	    CCHANGE_OF_OUTPUTS
	    
	    ; make both positive
	    tstfsz  extra,a
	    negf    deriv_error,b
	    tstfsz  PD_SIGN,b
	    negf    prop_error,b
	    
	    ; find difference
	    movf    deriv_error,w,b
	    subwf   prop_error,w,b
	    
			    
	    ; is proportional bigger?
	    BN	    $+8
	    tstfsz  PD_SIGN,b ; check if prop is negative
	    negf    PD_OUTPUT,b
	    bra	    CCHANGE_OF_OUTPUTS
	    
	    
	    ; derivative is bigger
	    tstfsz  extra,a ; check if deriv is negative
	    bra	    $+4
	    bra	    $+8
	    negf    PD_OUTPUT,b
	    setf    PD_SIGN,b
	    bra	    CCHANGE_OF_OUTPUTS
	    
	    clrf    PD_SIGN,b
	    
	;</editor-fold>
	
	;<editor-fold defaultstate="collapsed" desc="Steering">
	    
	    CCHANGE_OF_OUTPUTS:
	    
	    ; check if a wheel needs to reverse
	    movf    PD_OUTPUT,w,b
	    subwf   default_duty_cycle,w,b ; new ccp = default - output
	    ; check if new ccp < than MIN_DUTY
	    bnn	    $+10
	    negf    WREG,a
	    ADDLW   MIN_DUTY
	    ADDLW   MIN_DUTY
	    bra	    wheel_reversing
	    
	    ; need to check if the value is bigger or less than MIN_DUTY
	    sublw   MIN_DUTY
	    bnn	    $+10
	    ; no reversing
	    sublw   MIN_DUTY
	    BRA	    straight
	    
	    ; reversing
	    ADDLW   MIN_DUTY
	    bra	    wheel_reversing
	    
	    
	    ; a wheel needs to reverse
	    ;negf    WREG,a		; we dont put negative values into the PWM registers
	    wheel_reversing:
	    ; clamping because im not gonna tweak the PID vals now
	    ; max value is in default_duty_cycle
	    CPFSGT  default_duty_cycle,b
	    movf    default_duty_cycle,w,b
	    
	    ; which wheel needs to reverse
	    tstfsz  PD_SIGN,b
	    bra	    left_reverse
	    bra	    right_reverse
	    ; both wheels forward
		; which weel needs to slow down
	    straight:
	    tstfsz  PD_SIGN,b
	    bra	    slow_left
	    bra	    slow_right
	    
	   
	    right_reverse:
		; never set one of these first, extra safety for the H-Bridge
		BCF	    STR1C
		BSF	    STR1B
		
		BCF	    STR2B
		BSF	    STR2C
		
		movwf   CCPR2L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR1L,a
		
		bra	CHANGE_OUTPUTS_END	
	
	    left_reverse:
		BCF	    STR2C
		BSF	    STR2B
		
		BCF	    STR1B
		BSF	    STR1C
		
		movwf   CCPR1L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR2L,a
		
		bra	CHANGE_OUTPUTS_END
		
	    slow_right:
		BCF	    STR1C
		BCF	    STR2C
		BSF	    STR1B
		BSF	    STR2B
		
		movwf   CCPR2L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR1L,a
		
		bra	CHANGE_OUTPUTS_END
		
	    slow_left:
		BCF	    STR1C
		BCF	    STR2C
		BSF	    STR1B
		BSF	    STR2B
		
		movwf   CCPR1L,a
		movf    default_duty_cycle,w,b
		movwf   CCPR2L,a
		
		CHANGE_OUTPUTS_END: 
		
	    
	;</editor-fold>
	
	    GOTO    TRANSITION1
	    
	    
	  
	  LOST:
	    LOST_STOP:
		clrf	BLACK_FLAG,a
		
		INCFSZ	lost_count,a
		return
		
		CALL BRAKES
          ;REVERSE UNTIL WE SEE LINE
		REVERSE:
		    ; change from the forward pins to the reverse pins
		    BCF	    STR1B
		    BCF	    STR2B
		    
		    BSF	    STR1C
		    BSF	    STR2C
    
		    movf    default_duty_cycle,w,b
		    movwf   CCPR1L,a
		    movwf   CCPR2L,a
		    
		  return
         
	BRAKES:
	    clrf    CCPR1L,a
	    clrf    CCPR2L,a
	    
	    BTFSS   black_flag
	    bra	    $+8
	    decfsz  black_seen_count,a
	    return
	    bra	    $+0
	    
	    BCF	    black_flag
	    movlw   black_seen_thresh
	    movwf   black_seen_count,a
	    
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
	    BSF	    black_flag
	    BRA	    BRAKES
    
TRANSITION2:
    ;return
    BSF	    follow_line  ;LOOP OVER LLI

;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Tests">
		
    STATE3:
    software_tests:
	BTFSS   code_tests
	GOTO    STATE4

	TODO_code_tests: ; to-do todo to do
	    nop
    ;   state 2 code
	; to be added later

    TRANSITION3:
	BCF	    code_tests
    
    		
STATE4:
test_hardware:
    BTFSS   hardware_tests
    GOTO    SUBROUTINE0
    
    TODO_hardware_tests: ; to-do todo to do
	   ; getting the min value in ccprxl for the motors to turn
	   movlw    35
	   movwf    CCPR1L,a
	   movwf    CCPR2L,a
    
	    bra	TODO_hardware_tests
;   state 2 code
    ; to be added later
    
TRANSITION4:
    BCF	    hardware_tests
    
;</editor-fold>
    
;==========SUBROUTINES=======================
    
TRY_ALL_SUBROUTINES:
    
;<editor-fold defaultstate="collapsed" desc="333ms Delay">
    
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
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Delay for RGBs">
        
SUBROUTINE1:
delay_RGB:
    BTFSS   RGB_delay_call
    GOTO    SUBROUTINE2
	BTFSC	skip_delay_RGB
	return
	
	; save context
	movwf    extra,a
	
	TODO_maybe_give_the_option_to_wait_for_it:
	; set the timer to overflow in 80 instruction cycles
	; about 80 us, which is the settling time 
	    ; might change to 20us, because that is the rise time
	    ; would have to change the calibration code a bit to account for the 
	    ; range of values between 90% and 100% of the steady state
		; this might distort the ADC reading tho, so nah
	movlw	-80
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
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Read Sensors">
        
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
	    bsf	    red_pin,a
	    bsf	RGB_delay_call
	    call delay_RGB
	    bcf	RGB_delay_call

	    call    read_all_sensors
	    bcf	    red_pin,a

	; shine green
	    bsf	    green_pin,a
	    bsf	RGB_delay_call
	    call delay_RGB
	    bcf	RGB_delay_call

	    call    read_all_sensors
	    bcf	    green_pin,a

	; shine blue
	    bsf	    blue_pin,a
	    bsf	RGB_delay_call
	    call delay_RGB
	    bcf	RGB_delay_call

	    call    read_all_sensors
	    bcf	    blue_pin,a

	    return
	    GOTO	SUB_TRANSITIONS2

	    read_all_sensors:
	    ; read from AN0
		; ADCON0 = x 00000 1 1
		movlw   ADC_AN0	; select AN0
		call    read_sensor

	    ; read from AN1
		; ADCON0 = x 00001 1 1
		movlw   ADC_AN1	; select AN1
		call    read_sensor

	    ; read from AN2
		; ADCON0 = x 00010 1 1
		movlw   ADC_AN2	; select AN2
		call    read_sensor

	    ; read from AN3
		; ADCON0 = x 00011 1 1
		movlw   ADC_AN3	; select AN3
		call    read_sensor

	    ; read from AN4
		; ADCON0 = x 00100 1 1
		movlw   ADC_AN4	; select AN4
		call    read_sensor

		return

		read_sensor:
		    movwf   ADCON0,a	; begin ADC

		    btfsc   ADCON0,1,a	; check if ADC is done (0)
		    bra	    $-2		; no, check again
										    ; 3TAD is done
		    movff   ADRESH,POSTINC0	; MOVE ADC result bits <9:2> into FSR0L + 4
						; Increment FSR0
										    ; 5TAD is done
										    ; 6TAD is done
						    ;happens on 7TAD
		    bcf	    ADCON0,1,a						    ; shuts ADC down on 8TAD

		    return

    SUB_TRANSITIONS2:
	BCF	    read_sensors_call
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Colour Detection">
        
    SUBROUTINE3:
    detect_colour:
	BTFSS   check_colour
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
	    BSF read_sensors_call
	    call    read_sensors
	    BCF read_sensors_call
	    ; back to bank 2
	    LFSR    0, 200h	

	;<editor-fold defaultstate="collapsed" desc="White Check">
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

	;</editor-fold>

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

	;<editor-fold defaultstate="collapsed" desc="Red Check">

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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Green Check">

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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Blue Check">

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

	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="Get Sensor Colours">

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

	;</editor-fold>

	    return

	;<editor-fold defaultstate="collapsed" desc="Decode Colour">

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
		    btfsc	check,2,a
		    RETLW	'e'

		    ; default to ERROR
		    RETLW   'E'

	;</editor-fold>

    SUB_TRANSITIONS3:
	BCF	    check_colour
        
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="colour display">
    
    SUBROUTINE4:
	TODO_this_should_be_changed_for_serial_bridge_comms:
	nop
	TODO_this_could_be_done_with_the_RGB_LEDs_if_we_connect_their_grounds_to_the_PIC:
    show_colour:
	BTFSS   show_the_colours
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
	BCF	    show_the_colours
        
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="3Hz Flash">
    
    SUBROUTINE5:
     flash:
	BTFSS   flash_colour_display
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
	    bsf	wait_for_timer333
	    bsf	delay_333_call
	    call    delay_333
	    bcf	delay_333_call
		;start 0.166 second timer
	    bsf	delay_333_call
	    call    delay_333
	    bcf	delay_333_call
	    ; do this because i will do things while waiting for the timer.
	    bsf	wait_for_timer333
		; turn on
	    MOVF	DISPLAYED_COLOUR,w,a
	    BSF	colour_display
	    call	display_colour
	    BCF	colour_display
		;wait 0.166 seconds
	    btfsc	wait_for_timer333
	    bra	$-10
	    ; did we flash enough?
	    decfsz  count,a
	    bra	BEGIN_FLASH	; no
	    ; yes
	    return

    SUB_TRANSITIONS5:
	BCF	    flash_colour_display
    
;</editor-fold>
        
;<editor-fold defaultstate="collapsed" desc="Wait for Button Press and Show Colour">
    
    SUBROUTINE6:
    wait_for_button_press_show_colour:
	BTFSS   button_press_check
	GOTO    display_colour

	    ; show the colour to calibrate
	    BSF	colour_display
	    call	display_colour
	    BCF	colour_display

	    btfss   INT0IF	    ;wait for button press
	    bra	    $-10
	    ; delay so that we dont have to debounce
	bsf	wait_for_timer333
	    bsf	delay_333_call
	    call    delay_333
	    bcf	delay_333_call
	bsf	wait_for_timer333
	    bsf	delay_333_call
	    call    delay_333
	    bcf	delay_333_call
	    ; reset button wait
	    bcf	    INT0IF
	    ; go back
	    clrf LATA,a
	    return

    SUB_TRANSITIONS6:
	BCF	    button_press_check
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Colour Displays on RGB LEDs">
    
    SUBROUTINE7:
    display_colour:
	BTFSS   colour_display
	GOTO    STATE_MACHINE_END

	    nop
	    nop
	    nop
	    nop
	    nop
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

	    ;<editor-fold defaultstate="collapsed" desc="Off">
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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Black (orange)">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="White">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Red">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Green">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Blue">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Race error">

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

	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="Error">

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

	    ;</editor-fold>

    SUB_TRANSITIONS7:
	BCF	    colour_display
    
;</editor-fold>
    
STATE_MACHINE_END:
    
GOTO    STATE_MACHINE_START   ; LOOP OVER ALL STATES

;<editor-fold defaultstate="collapsed" desc="INTERRUPTS">
    
    ISR:
	btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
	goto    race_colour_reset   
	btfsc   TMR0IF	    ; was it timer 0?
	goto    timer0_interrupt
        btfsc   TMR2IF	    ;was it timer 2?
        goto    TIMER2_ISR
	

        BCF	    wait_for_timer2

	retfie

    TIMER2_ISR:   
        BCF	    wait_for_timer2
        BCF	    TMR2IF
        RETFIE

    race_colour_reset:
	bcf	    INT1IF		; clear interrupt flag
	;pop
	goto	race_colour_selection
	retfie			            ;return from interrupt

    timer0_interrupt:
	; check if the wait bit for timmer333 was set
	btfsS   wait_for_timer333
	bra	    $+10
	; if it was, just clear the wait and return
	bcf	    wait_for_timer333
	clrf    T0CON,a
	bcf	    TMR0IF
	retfie
	; if not, do other things first, then return

	nop
	retfie
	
	;---------- RX Interrupt service routine ---------------------------------------
    Rx_ISR:
	;BCF    RC1IF	; Cannot clear RC1IF in firmware (Read only bit)
			    ; Need to read RC1REG to clear RC1IF
	MOVF    RCREG1,0,0	; write received byte to W
			    ; Note: You have to read RCREG1 in ISR to clear RC1IF
			    ; RC1IF is read only, i.e. you cannot clear it in firmware
	MOVF    RCSTA1	; Read RCSTA (Datasheet RX#7)
	BSF	    RCFlag,0

	; Error handling : overrun error
	BTFSC   RCSTA1,1		;if overrun error occurred
	BRA	    ErrSerialOverr	;then go handle error
	; Error handling : framing error
	BTFSC   RCSTA1,2		
	BRA	    ErrSerialFrame	
	; Test if error occured
	BTFSC   ERRORFlag,0	
	BRA	    EXIT_NO_RC

	; If byte was received, write byte to POSTINC0
    EXIT_RC:    
	MOVF    RCREG1,0		
	; MOVWF   PORTD
	; CALL    BYTE_TX ;ECHO to terminal
	MOVWF	POSTINC0
	CLRF    RCREG1     
	
	; end of transmission checker
	XORLW	0x0D
	BNZ	$+6
	
	BSF	Rx_done
	RETFIE
	
	BCF	Rx_done
	RETFIE

	; If byte was not received, i.e. error occured, clear PORTD
    EXIT_NO_RC:
	CLRF    PORTD
	CLRF    ERRORFlag
	CLRF    RCREG1
	RETFIE

    ;--- OERR overrun error bit is set ---
    ErrSerialOverr:	bcf	RCSTA1,4	;reset the receiver logic
		    bsf	RCSTA1,4	;enable reception again
		    bsf	ERRORFlag,0
		    retfie

    ;--- FERR framing error bit is set ---
    ErrSerialFrame:	movf	RCREG1,W	;discard received data that has error
		    bsf	ERRORFlag,0
		    retfie
    
;</editor-fold>
	
;<editor-fold defaultstate="collapsed" desc="Serial Code">
	
    ;---------- Subroutines --------------------------------------------------------
    ;--- Transmit Sequence ---
    TRANSMIT_tesT:
	movlw   't'
	CALL BYTE_TX

	movlw   'e'
	CALL BYTE_TX

	movlw   's'
	CALL BYTE_TX

	movlw   'T'
	CALL BYTE_TX

	movlw   0x0D    ;CR
	CALL BYTE_TX

	RETURN

    ;--- Delay ---		
    Serial_DELAY:			
	MOVLW   0xFF
	MOVWF   DelayCount		
    LOOP:	
	DECFSZ  DelayCount,f	
	BRA	    LOOP		
	RETURN

    ;--- Tx Byte (Byte must be pre-loaded in WREG) ---
    BYTE_TX:
	MOVWF   TXREG1
    POLL_TX:
	BTFSS   TXSTA1,1
	GOTO    POLL_TX
	; MOVWF   PORTD
	RETURN
	
;</editor-fold>
	
;<editor-fold defaultstate="collapsed" desc="I2C Code">
	
    ;<editor-fold defaultstate="collapsed" desc="Multi Page Write">
	
    MULTI_PAGE_WRITE:
	;--- Fetch the letter to send
;	TBLRD*+
;	movf   TABLAT,w,a
	movf	POSTINC0,W
	MOVWF   CHAR_WRITE   
    
	;<editor-fold defaultstate="collapsed" desc="1. Generate start condition">
	CALL    I2C_START_CONDITION
	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="2. Load & send the control byte/slave address (WRITE)">    
	MOVLW   WRITE_CONTROL
	MOVWF   TX_BYTE
	CALL    my_I2C_WRITE

	;--- Optional ACK check
	BTFSC   SSP1CON2,6       ; ACKSTAT = 1 means no ACK received
	GOTO    I2C_ERROR
	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="3. Load & send the address">
	MOVF    EEPROM_ADDRESS,W
	MOVWF   TX_BYTE
	CALL    my_I2C_WRITE    

	;--- Optional ACK check
	BTFSC   SSP1CON2,6
	GOTO    I2C_ERROR
	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="4. Load & send the data in pages">
	MOVLW   8
	movwf   page_byte_count,a

    page_loop:

	MOVF    CHAR_WRITE,W
	MOVWF   TX_BYTE
	CALL    my_I2C_WRITE

	;--- Optional ACK check
	BTFSC   SSP1CON2,6
	GOTO    I2C_ERROR

	;--- Increment the EEPORM address
	INCF    EEPROM_ADDRESS,F


	decfsz  page_byte_count,a
	bra	page_loop


	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="5. Generate stop condition">    
	CALL    I2C_STOP_CONDITION
	;</editor-fold>

	;<editor-fold defaultstate="collapsed" desc="6. Wait for EEPROM internal write cycle to finish">
	CALL    POLLING_WRITE_ACK
	;</editor-fold>

	; Repeat PAGE_COUNT more times to write PAGE_COUNT*8 characters in total
	CALL    I2C_DELAY
	DECFSZ  PAGE_COUNT,F
	GOTO    MULTI_PAGE_WRITE
	
	return
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="Read EEPROM">
    
	READ_EEPROM:

	    ;<editor-fold defaultstate="collapsed" desc="1. Generate start condition">
	    CALL    I2C_START_CONDITION
	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="2. Load & send the control byte/slave address: WRITE">
	    MOVLW   WRITE_CONTROL
	    MOVWF   TX_BYTE
	    CALL    my_I2C_WRITE

	    BTFSC   SSP1CON2,6
	    GOTO    I2C_ERROR
	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="3. Load and send the EEPROM word address">
	    MOVF    EEPROM_ADDRESS,W
	    MOVWF   TX_BYTE
	    CALL    my_I2C_WRITE

	    BTFSC   SSP1CON2,6
	    GOTO    I2C_ERROR
	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="4. Restart to switch to receive mode">
	    CALL    I2C_RESTART
	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="5. Load and send the control byte/slave address: READ">
	    MOVLW   READ_CONTROL
	    MOVWF   TX_BYTE
	    CALL    my_I2C_WRITE

	    BTFSC   SSP1CON2,6
	    GOTO    I2C_ERROR
	    ;</editor-fold>

	Read_char:
	    ;<editor-fold defaultstate="collapsed" desc="6. Read byte into POSTINC0">
	    CALL    my_I2C_READ_BYTE
	    ;</editor-fold>

	    ;<editor-fold defaultstate="collapsed" desc="7. ACK all but last byte, NACK the last byte">
	    
	    ; this check is here just for the power on message
	    XORLW   0x0D ; CR character
	    BZ	    Last_Byte
	    
	    MOVLW   0x01
	    CPFSEQ  CHAR_COUNT
	    GOTO    More_Bytes

	Last_Byte:
	    CALL    I2C_SEND_NACK
	    DECF    CHAR_COUNT,F
	    GOTO    Read_done

	More_Bytes:
	    CALL    I2C_SEND_ACK
	    DECF    CHAR_COUNT,F
	    GOTO    Read_char
	    ;</editor-fold>

	Read_done:
	    ;<editor-fold defaultstate="collapsed" desc="8. Stop">
	    CALL    I2C_STOP_CONDITION
	    ;</editor-fold>
	    
	    return
	    
    ;</editor-fold>

    ;-------------------------------------------------------------------------------
    ; Subroutines
    ;-------------------------------------------------------------------------------
    
    ;<editor-fold defaultstate="collapsed" desc="I2C Start">
    
    I2C_START_CONDITION:
	BCF     SSP1IF
	BSF     SSP1CON2,0      ; SEN = 1
    wait_START:
	BTFSC   SSP1CON2,0
	BRA     wait_START
	BTFSS   SSP1STAT,3      ; S bit should be set after Start
	SETF    PORTA
	RETURN

    ;</editor-fold>
    
    ;<editor-fold defaultstate="collapsed" desc="I2C Restart">
    
    I2C_RESTART:
	BCF     SSP1IF
	BSF     SSP1CON2,1      ; RSEN = 1
    wait_RESTART:
	BTFSC   SSP1CON2,1
	BRA     wait_RESTART
	RETURN
	
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Stop">
    
	I2C_STOP_CONDITION:
	    BCF     SSP1IF
	    BSF     SSP1CON2,2      ; PEN = 1
	wait_STOP:
	    BTFSC   SSP1CON2,2
	    BRA     wait_STOP
	    RETURN
    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Write Byte">
    
	my_I2C_WRITE:
	    BTFSC   SSP1STAT,0      ; BF = 1 means buffer full
	    GOTO    my_I2C_WRITE
	    BCF     SSP1IF
	    MOVF    TX_BYTE,W
	    MOVWF   SSP1BUF
	wait_WRITE:
	    BTFSS   SSP1IF
	    BRA     wait_WRITE
	    RETURN
	
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Recieve Byte">
    
	; Receive one byte and store at POSTINC0
	; Does NOT send ACK/NACK
	my_I2C_READ_BYTE:
	    BCF     SSP1IF
	    BSF     SSP1CON2,3      ; RCEN = 1, enable receive mode
	WAIT1_READ:
	    BTFSS   SSP1IF
	    BRA     WAIT1_READ
	    BTFSS   SSP1STAT,0      ; BF must be set when byte is received
	    BRA     WAIT1_READ
	    MOVF    SSP1BUF,W
	    MOVWF   POSTINC0
	    RETURN
	
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Send Read Ack">
    
	I2C_SEND_ACK:
	    BCF     SSP1CON2,5      ; ACKDT = 0 -> ACK
	    BCF     SSP1IF
	    BSF     SSP1CON2,4      ; ACKEN = 1
	WAIT_ACK:
	    BTFSS   SSP1IF
	    BRA     WAIT_ACK
	    RETURN
	
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Nack">
    
	I2C_SEND_NACK:
	    BSF     SSP1CON2,5      ; ACKDT = 1 -> NACK
	    BCF     SSP1IF
	    BSF     SSP1CON2,4      ; ACKEN = 1
	WAIT_NACK:
	    BTFSS   SSP1IF
	    BRA     WAIT_NACK
	    RETURN
	
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Write Ack Polling">

	; ACK polling for 24LC02B:
	; After STOP, issue START and resend WRITE control byte
	; until ACKSTAT = 0
	POLLING_WRITE_ACK:
	Poll_Loop:
	    CALL    I2C_START_CONDITION

	    MOVLW   WRITE_CONTROL
	    MOVWF   TX_BYTE
	    CALL    my_I2C_WRITE

	    ; ACKSTAT = 1 => EEPROM still busy
	    BTFSC   SSP1CON2,6
	    GOTO    Poll_NotReady

	Poll_Ready:
	    CALL    I2C_STOP_CONDITION
	    RETURN

	Poll_NotReady:
	    CALL    I2C_STOP_CONDITION
	    GOTO    Poll_Loop
	    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Error">
    
	I2C_ERROR:
	    CALL    FLASH_LED
	    GOTO    $
	    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Error Indicator">
    
	FLASH_LED:
;	    MOVLW   11000000B
;	    MOVWF   PORTA,a
;	    CALL    I2C_DELAY
;	    MOVLW   10000000B
;	    MOVWF   PORTA,a
	    RETURN
	    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="I2C Delay">
    
	I2C_DELAY:
	    MOVLW   0xFF
	    MOVWF   Delay2
	LOOP1:
	    MOVLW   0xFF
	    MOVWF   Delay1
	LOOP2:
	    DECFSZ  Delay1,F
	    GOTO    LOOP2
	    DECFSZ  Delay2,F
	    GOTO    LOOP1
	    RETURN
	    
    ;</editor-fold>

;</editor-fold>
    
end			