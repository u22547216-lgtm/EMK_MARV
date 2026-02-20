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
;
; -------------	
; PROGRAM START	
; -------------
;
    PSECT code,abs //Start of main code.
    org	    0x00 			; startup address = 0000h
    goto init

init:
    MOVLB   0xF		; work in bank 15, not all SFRs are in access bank
    
    ; setup ADC pins
    CLRF    PORTA,a 	; Initialize PORTA by clearing output data latches
    CLRF    LATA,a 	; Alternate method to clear output data latches
    movlw   0b00101111
    movwf   ANSELA,b 	; set pins A 0,1,2,3 and 5 to analogue
    movwf   TRISA,a	; set pins A 0,1,2,3 and 5 to input
    
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
    bsf	    PORTD,5,A
    call	delay_333
    bcf	    PORTD,5,a
    call	delay_333
    goto start
    
	
register_dump:
    
show_colour:
    
read_sensors:
    
calibration:
    
LLI:
    
delay_333:
    movlw   53
    movwf   0x69,a
delay_big:
    movlw   255
    movwf   0x67,a
delay_in:
    decfsz  0x67,a
    goto delay_in
    
    decfsz  0x69,a
    goto delay_big
    
    
    return
    
    
    end			





