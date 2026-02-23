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
    CONFIG WDTEN = off      ; Turn off the watchdog timer
  
    
    #include    <xc.inc>
    #include    "pic18f45k22.inc"

; variables

delay_inner     equ 0x00
delay_outer     equ 0x01

#define red_pin     PORTA,4
#define green_pin   PORTA,6
#define blue_pin    PORTA,7

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
    
    MOVLB   0x00	; back to bank 0 for normal opperations
		
		
start: 	

    goto start
    
	
register_dump:
    movff   line_reg, PORTC
    bcf	    INTCON3,0,a
    retfie			;return from interrupt
    
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
    
    
    end			





