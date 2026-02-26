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

; Sensor storage variables, the adresses here can be used with indirect addressing
     ; name format is [colour flash]_[sensor number]
red_0		equ 0x60
red_1		equ 0x61
red_2		equ 0x62
red_3		equ 0x63
red_4		equ 0x64

green_0		equ 0x66
green_1		equ 0x67
green_2		equ 0x68
green_3		equ 0x69
green_4		equ 0x6A

blue_0		equ 0x6B
blue_1		equ 0x6C
blue_2		equ 0x6D
blue_3		equ 0x6E
blue_4		equ 0x6F


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
    
    MOVLB   0x00	; back to bank 0 for normal opperations
		
		
start: 	

;    hehe haha
    goto start
    
	
register_dump:
    
show_colour:
    
read_sensors:
    
calibration:
    
    LFSR 0, 060h
    ; ; movf    INDF0,w,a ; sensor 0, red shine
    ; addFSR  0, blue_4
    ; movf    INDF0,w,A

    movf    POSTINC0,w,a    ; move red_0 to WREG
    movf    red_0,w,a
    movf    POSTINC0,w,a    ; move red_1 to WREG
    movf    POSTINC0,w,a    ; move red_2 to WREG
    movf    POSTINC0,w,a    ; move red_3 to WREG
    movf    POSTINC0,w,a    ; move red_4 to WREG

    movf    POSTINC0,w,a    ; move green_0 to WREG
    movf    POSTINC0,w,a    ; move green_1 to WREG
    movf    POSTINC0,w,a    ; move green_2 to WREG
    movf    POSTINC0,w,a    ; move green_3 to WREG
    movf    POSTINC0,w,a    ; move green_4 to WREG

    movf    POSTINC0,w,a    ; move blue_0 to WREG
    movf    POSTINC0,w,a    ; move blue_1 to WREG
    movf    POSTINC0,w,a    ; move blue_2 to WREG
    movf    POSTINC0,w,a    ; move blue_3 to WREG
    movf    POSTINC0,w,a    ; move blue_4 to WREG

    goto start

    mask_red    equ 0x50    ;
    movlw       0xff        ;
    movwf       mask_red,a  ; mask red = 0b 1111 1111

comp_r0_r1:
    movf    red_0,w,b
    cpfseq  red_1,b         ; if red_0 = red_1
    bra $+6                 ; no
    goto    comp_r1_r2      ; yes, go to next compare

    rlncf   mask_red,f,a    ; mask red -> 0b 1111 1110 -> 0b 1111 1100
    movf    mask_red,w,a    ; move mask red to WREG
    andwf   red_0,f,b       ; cut a bit off red_0
    andwf   red_1,f,b       ; cut a bit off red_1
    goto    comp_r0_r1      ; repeat

comp_r1_r2:
    
    movf    mask_red,w,a    ; move mask red to WREG
    andwf   red_2,f,b       ; cut noise bits off 
    movf    red_1,w,b
    cpfseq  red_2,b         ; if red_0 = red_1

comp_r2_r3:

comp_r3_r4:

;red_mask = 0b 1111 0000
;   we can use this as a threshold 

    red_ref equ 0x51
    movf    red_2,w,B
    movwf   red_ref,a

    ; colour detection
        movf    red_mask,w,a
        andwf   red_0,w,B
        cmpfseq red_ref,a

; do same for green and blue
;       green_mask and blue_mask

; simpler code, this just finds the lowest sensor value, we can use as a threshold
    movf        red_0,w,b       ;assume red 0 is smallest
    cpfsgt      red_1,b         ;is red 1 smaller?
    movf        red_1,w,b       ;yes, save red_1

    cpfsgt      red_2,b         ;is red 2 smaller
    movf        red_2,w,b       ;yes, save red_2

    cpfsgt      red_3,b
    movf        red_3,w,b
    
    cpfsgt      red_4,b
    movf        red_4,w,b

    movwf       red_ref,a
    


    
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





