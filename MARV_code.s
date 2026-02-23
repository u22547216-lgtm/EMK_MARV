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
;       Pins:   RA4,6,7 (HIGH turns the colour off)
;       Colours:  R,G,B
;	Register dump:
;	    Port C
;	Colour display:
;	    Port D
;		
; -----------------------------------------------------------------------------

    title	"Our second assembler program"
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
    
    ; setup ADC and RGB pins
    CLRF    PORTA,a 	; Initialize PORTA by clearing output data latches
    CLRF    LATA,a 	    ; Alternate method to clear output data latches
    movlw   0b00101111
    movwf   ANSELA,b 	; sets pins A 0,1,2,3 and 5 to analogue     ADC
                        ; also sets pins A 4,6 and 7 to digital     RGB
    movwf   TRISA,a	    ; sets pins A 0,1,2,3 and 5 to input        ADC
                        ; also sets pins A 4,6 and 7 to outputs     RGB
    
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
    clrf    ANSELB, a
    clrf    TRISB, a
    bsf	    TRISB,1,a	; RB1 is input(INT1I)
    clrf    WPUB,a
    
    ; set up interrupts
    bcf	    RCON,7,b	; disable priority in interrupts.
    ; just in case some flags are set or some interrupts are enabled when i enable interrupts
    clrf    INTCON,a
    clrf    INTCON2,a
    clrf    PIE1,a
    clrf    PIE2,a
    clrf    PIE3,a
    clrf    PIE4,a
    clrf    PIE5,a
    
    bsf	    INTCON,7,a	;enable global interupts
    bsf	    INTCON,6,a	;enable periphital interupts
    
    bsf	    INTCON2,7,a	; no RBPU
    bsf	    INTCON2,5,a	; INT1I reacts on rising edge
    
    clrf    INTCON3,a	;
    bsf	    INTCON3,3,a	; INT1I is enabled
    
    MOVLB   0x00	; back to bank 0 for normal opperations
; testing setup		
    bsf	    test_en, a
    btfsc   test_en, a
    goto    test
end_test:
    bcf	    test_en, a
		
start: 	

    goto start
    
	
register_dump:
    movff   line_reg, PORTC     ; put line_reg into PORTC
    bcf	    INTCON3,0,a         ; clear interrupt flag
    retfie			            ;return from interrupt
    
show_colour:
    
read_sensors:
    
calibration:
    
LLI:

flash:
    
delay_333:
    movlw   53
    movwf   delay_outer,a
delay_outside:
    movlw   255
    movwf   delay_inner,a
delay_inside:
    decfsz  delay_inner,a
    goto delay_inside
    
    decfsz  delay_outer,a
    goto delay_outside
    
ISR:
    btfsc   INTCON3,0,a	    ; was it INT1IF(RB1)?
    goto    register_dump   
    
    return
    
test:
; this is just a software engineering practice
; basically disecting the code you made, making the input fixed, and seeing if the output is what you expect
; just comment or uncomment what needs to be tested
    
    call test_register_dump
    
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
    
    end			





