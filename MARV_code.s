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
;SENSOR STORAGES TO BE USED IN LLI

	SENSOR0        EQU 0x55
	SENSOR1        EQU 0x56
	SENSOR2        EQU 0x57
	SENSOR3        EQU 0x58
	SENSOR4        EQU 0x59
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

	SENSOR0        EQU 0x55
	SENSOR1        EQU 0x56
	SENSOR2        EQU 0x57
	SENSOR3        EQU 0x58
	SENSOR4        EQU 0x59
	RACE_COLOUR    EQU 0x5A
	BLACK_FLAG     EQU 0x5B
	K	       EQU 0x5C
	sensor0	       EQU 0x5D
	sensor1	       EQU 0x5E
	sensor2	       EQU 0x5F
	sensor3	       EQU 0x60
	sensor4	       EQU 0x61
    
    MOVLB   0x00	; back to bank 0 for normal opperations
		
		
start: 	

    goto start
    
	
register_dump:
    
show_colour:
    
read_sensors:
    
calibration:
    
LLI:
; 5 sensors --> left sensor (LL), middle left sensor (ML), middle sensor (M), middle right sensor (MR), right sensor (RR)

;go straight --> M detects line
;turn left 	--> LL or ML detects line
;turn right --> RR or MR detects line
;if all the sensors detect white STOP (SOS MODE). 
	;Suggestion: turn 90 degrees to the left and see if the sensors detect the line. If not go back to previous position (-90 degrees)
				;turn 90 degrees to the right and see if the sensors detect the line.
				;One of these two actions should detect the intended line and thus follow the original line-intepreter algorithm
; if all sensor detect black, STOP (End of maze)



 MOVFF   SENSOR0,sensor0
          MOVFF   SENSOR1,sensor1
          MOVFF   SENSOR2,sensor2
          MOVFF   SENSOR3,sensor3
          MOVFF   SENSOR4,sensor4
	

	STRAIGHT:
	    MOVF    RACE_COLOUR,W
	    SUBWF   sensor0,a
	    BZ	    TURN_LEFT_ALOT
	    MOVF    RACE_COLOUR
	    SUBWF   sensor1,a
	    BZ	    TURN_LEFT_ALITTLE
	    MOVF    RACE_COLOUR
	    SUBWF   sensor3,a
	    BZ	    TURN_RIGHT_ALITTLE
	    MOVF    RACE_COLOUR
	    SUBWF   sensor4,a
	    BZ	    TURN_RIGHT_ALOT
	    MOVF    RACE_COLOUR,W
	    SUBWF   sensor2,a
	    BNZ	    CHECK_BLACK
	    MOVLW   0b00100000
	    MOVWF   PORTB,a
	    RETURN
    TURN_LEFT_ALOT:
	    MOVLW 0b10000000
	    MOVWF PORTB,a
	    RETURN
    TURN_LEFT_ALITTLE:
	    MOVLW 0b01000000
	    MOVWF PORTB,a
	    RETURN
    TURN_RIGHT_ALOT:
	    MOVLW 0b00001000
	    MOVWF PORTB,a
	    RETURN
    TURN_RIGHT_ALITTLE:
	    MOVLW 0b00010000
	    MOVWF PORTB,a
	    RETURN
    LOST:
	    CALL LOST_STOP
	    CALL TURN_LEFT_ALOT
	    BRA STRAIGHT
	    RETURN
	    
    LOST_STOP:
	    CALL BRAKES
	    CALL delay_333
	    CLRF PORTB,a
	    RETURN
         
    BRAKES:
	    MOVLW 0b11111000
	    MOVWF PORTB,a
	    RETURN   
	    
    CHECK_BLACK:
	    MOVF    K,W
	    CPFSEQ   SENSOR0,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,0
	    MOVF   K,W
	    CPFSEQ   SENSOR1,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,1
	    MOVF   K,W
	    CPFSEQ   SENSOR3,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,2
	    MOVF   K,W
	    CPFSEQ   SENSOR4,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,3
	    MOVF   K,W
	    CPFSEQ   SENSOR2,a
	    BRA	    LOST
	    BSF	    BLACK_FLAG,4
	    MOVLW   0b00011111
	    CPFSEQ  BLACK_FLAG
	    RETURN
	    BRA	    BRAKES
	   			



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
    
    return
    
    
    end			





