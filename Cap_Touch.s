PROCESSOR 18F45K22

;========== Configuration bits ==========
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
    
    #include    <xc.inc>
    #include    "pic18f45k22.inc"
    
    ;========== Definition of variables ==========

    Delay	equ 0x00
    RESULTHI	equ 0x01
    flags	equ 0x30
    Vread	equ 0x31
    OpenSW	equ 0x32
    Trip	equ 0x33
    Hyst	equ 0x34
    DIFF	equ 0x35
    PSECT code,abs //Start of main code.
        org 00h
	goto init
	org 08h
	goto TIMER1_ISR
	
    ; ========== Setup ADC ==========
init:
    bsf 	IRCF0
    bcf		IRCF1
    bsf		IRCF2
	
    MOVLB	0xFF
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
    movlw   0b00001001
    movwf   ADCON0,a
    
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

    ;CTMU init for capacitive touch
    CLRF    CTMUCONH
    movlw   0b00000010
    movwf   CTMUICON
    movlw   0b10010000 ;0b10010000
    movwf   CTMUCONL
    movlw   0b10001000
    movwf   CTMUCONH
    
    
;    movlw   0b00000001
;    movwf   T1CON
    movlw   0b00000000
    movwf   T2CON
    movlw   125
    movwf   PR2
    ; INTCON2 = 0b 0 0 0 0 x 0 x 0 
    ; bsf	    INTCON2,7,a	; no RBPU
    ; bsf	    INTCON2,5,a	; INT1I reacts on rising edge
    ; INTCON3 = 0b 0 1 x 0 1 x 0 0
    clrf    INTCON3,a	;
    bsf     INT1IP	    ; INT1I priority is high
    bsf	    INT1IE	    ; INT1I is enabled
    ; INTCON = 0b 1 0 0 0 0 0 0 0
    bsf	    GIE
    BSF	    PEIE	; Peripheral interrupt enable
    BSF	    TMR2IE
    
    
    MOVLB	0x00
    
CAP_TOUCH:
    movlw   5
    movwf   OpenSW
    movlw   1
    movwf   Trip
    movlw   1
    movwf   Hyst
CHECK_TOUCH:
    MOVF    Trip,W
    SUBWF   OpenSW,0
    MOVWF   DIFF
    ;Discharge touch pad
    BSF	    CTMUEN
    BCF	    EDG1STAT
    BCF	    EDG2STAT
    BSF	    IDISSEN
    CALL    CAP_DELAY
    BCF	    IDISSEN
    
    ;Charge circuit
    BSF	    EDG1STAT
    CALL    CAP_DELAY
    BCF	    EDG1STAT
    
    ;AD conversion
    BSF	    GO
    BTFSC   GO
    BRA	    $-2
    MOVF    ADRESH,W
    MOVWF   Vread
    ;test if Vread = 0
    MOVLW   0
    CPFSEQ   Vread
    GOTO    CHK_P_OR_UP
    GOTO    CHECK_TOUCH
    ;Check if pressed or unpressed
CHK_P_OR_UP:
    MOVF    DIFF,W
    CPFSLT  Vread  
    GOTO    SW_PRESS
    MOVF    Hyst,W
    ADDWF   DIFF
    MOVF    DIFF,W
    CPFSGT  Vread
    GOTO    SW_UNPRESS
    GOTO    CHECK_TOUCH
CAP_DELAY:    
;    CLRF    TMR1	; Clear the timer of the few counts that accumulated since the previous roll-over.
;    BSF	    TMR1ON
    CLRF    TMR2
    BSF	    TMR2ON
WAIT1:
    BTFSS   flags,0
    BRA	    WAIT1
    BCF	    flags,0
    BCF	    TMR2ON
;    BRA	    CAP_TOUCH
    RETURN
SW_PRESS:
    BCF	    PORTA,7
    BSF	    PORTA,4
    GOTO    CHECK_TOUCH
SW_UNPRESS:
    BCF	    PORTA,4
    BSF	    PORTA,7
    GOTO    CHECK_TOUCH
TIMER1_ISR:   
    BSF	    flags,0
    BCF	    TMR2IF
    RETFIE
end
    

