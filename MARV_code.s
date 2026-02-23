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

#define red_pin     PORTA,4
#define green_pin   PORTA,6
#define blue_pin    PORTA,7

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

init:
    MOVLB   0xF		; work in bank 15, not all SFRs are in access bank
    
    ; setup ADC and RGB pins
    CLRF    PORTA,a 	; Initialize PORTA by clearing output data latches
    CLRF    LATA,a	; Alternate method to clear output data latches
    movlw   0b00101111
    movwf   ANSELA,b 	; sets pins A 0,1,2,3 and 5 to analogue     ADC
                        ; also sets pins A 4,6 and 7 to digital     RGB
    movwf   TRISA,a	; sets pins A 0,1,2,3 and 5 to input        ADC
                        ; also sets pins A 4,6 and 7 to outputs     RGB
    movlw   0b11010000
    movwf   PORTA,a	; turn RGB pins on, turns transistor on, and RBG LEDs off

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
			; sets TAD to 2us
    bsf	    ADCON2,4,a	; acquisition time of 4 TAD or 8us
			; ADC works for 8+12*2 = 32us. ie: 32/4 = 8 instruction cycles.
    ; need to remember the ADC cooldown of 2 TAD, or 4us, which is 1 instruction cycle.
    
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
    
    
    
    LFSR 0, 060h
    call read_sensors
    
    goto start
    
	
register_dump:
    
show_colour:
    
read_sensors:
; setup for indirect adressing
    ; you need to use 'LFSR FSR0, XYZh' before calling this 
    ; X is the bank
    ; YZ is the starting register
;    LFSR 0, 100h ;need to remove, only here for initial creation purposes
    
; shine red
    bcf	    red_pin,a
    call    read_all_sensors
    bsf	    red_pin,a
    
; shine green
    bcf	    green_pin,a
    call    read_all_sensors
    bsf	    green_pin,a
    
; shine blue
    bcf	    blue_pin,a
    call    read_all_sensors
    bsf	    blue_pin,a
    
    return

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
    
    movff   ADRESH,POSTINC0	; MOVE ADC result bits <9:2> into FSR0L + 4
				; Increment FSR0

    return
    
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
    
    return
    

    end			





