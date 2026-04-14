
    #include    <xc.inc>
    #include    "pic18f45k22.inc"

    org     0h
    goto init

init:
    MOVLB   Fh

    CLRF    PORTD,a
    CLRF    LATD,a
    CLRF    ANSELD,b
    CLRF    TRISD,a

    
    MOVLB   0h

    movlw   0
main:
    movlw   2 ; displays 0
    call    lookup_num
    movwf   PORTD,a

    movlw   4
    call    lookup_num
    movwf   PORTD,a

    movlw   6
    call    lookup_num
    movwf   PORTD,a

    movlw   8
    call    lookup_num
    movwf   PORTD,a

    movlw   10
    call    lookup_num
    movwf   PORTD,a

    movlw   12
    call    lookup_num
    movwf   PORTD,a

    movlw   14
    call    lookup_num
    movwf   PORTD,a
    
    movlw   16
    call    lookup_num
    movwf   PORTD,a
    
    movlw   18
    call    lookup_num
    movwf   PORTD,a
    ; displays 9
    movlw   20
    call    lookup_num
    movwf   PORTD,a
    


    goto main

lookup_num:
    org     200h
    MOVWF   0x01
    movf    PCL,w,a
    movf    0x01,w,a
    ADDWF   PCL
    RETLW   0b00111111 ;0
    RETLW   0b00000011 ;1
    RETLW   0b01011011 ;2
    RETLW   0b01001111 ;3
    RETLW   0b01100110 ;4
    RETLW   0b01101101 ;5
    RETLW   0b01111101 ;6
    RETLW   0b00000111 ;7
    RETLW   0b01111111 ;8
    RETLW   0b01101111 ;9

