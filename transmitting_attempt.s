

    
    title	"Funny joke transmission"
    PROCESSOR	18F45K22
    
    CONFIG  FOSC = INTIO67
    CONFIG WDTEN = OFF
    CONFIG  LVP = ON 
    
    
;--- Header files ---
    #include    "pic18f45K22.inc"
    #include	<xc.inc>
    
    
    chars equ 2041
    chars_start equ 7000h
    char_st_L	equ 00h
    char_st_H	equ 70h
    char_st_U	equ 00h
    
    
    DelayCount	    EQU 0x3  
    
	
    org 0h
    goto init
    
    
    
    init:
	movlb	0xf
	
	
    ; Set up oscillator for 4MHz fosc
    BSF	    IRCF0
    BCF	    IRCF1
    BSF	    IRCF2
    
    ; baud rate setup
    BSF     TXSTA1,2		; Enable high BAUDrate
    BCF	    BAUDCON1,3		; Use 8 bit baud generator
    
    movlw   12	    ; for 19200 bPS baud rate
    movwf   SPBRG1
    clrf    SPBRGH1
    
    ; Port C RX/TX pin configuration (Datasheet RX#2)
    MOVLW   11000000B		; Setup port C for serial port.
                        	; TRISC<7>=1 and TRISC<6>=1.
    MOVWF   TRISC
    
    ; Enable asynchronous serial port
    BCF     TXSTA1,4		; Enable asynchronous transmission
    BSF	    RCSTA1,7		; Enable Serial Port (Datasheet RX#3)
    
    ; Transmit setup (TX)
    BCF	    BAUDCON1,4		
    BSF	    TXSTA1,5		; Enable transmit
    
    ; set up interrupts
    BCF    RCIF			; Clear RCIF Interrupt Flag
    BSF    RCIE			; Set RCIE Interrupt Enable (Datasheet RX#4)
    BSF    PEIE			; Enable peripheral interrupts
    BSF    GIE			; Enable global interrupts
    
    ; Receive setup (RX)
    BCF	    BAUDCON1,5		
    BSF	    RCSTA1,4		; Enable continuous reception (Datasheet RX#6)
    
    
    MOVLB   0x0
    
Main:
    
    ; table setup
    movlw   char_st_L
    movwf   TBLPTRL
    movlw   char_st_H
    movwf   TBLPTRH
    movlw   char_st_U
    movwf   TBLPTRU

    ; Wait for Port to stabilize
    CALL    DELAY    
    CALL    DELAY  
    CALL    DELAY  
    
    transmit:
    TBLRD*+
    movf    TABLAT,w
    ;movlw   'e'
    CALL BYTE_TX
    
    movlw   77h
    CPFSEQ  TBLPTRH
    bra	    transmit
    movlw   0xF9
    CPFSEQ  TBLPTRL
    bra	    transmit
    
    CALL    DELAY    
    CALL    DELAY  
    CALL    DELAY  
    
    bra $-0
    goto Main
    
    
    BYTE_TX:
    MOVWF   TXREG1
POLL_TX:
    BTFSS   TXSTA1,1
    GOTO    POLL_TX
    RETURN
    
    
    
    		
;--- Delay ---		
DELAY:			
    MOVLW   0xFF
    MOVWF   DelayCount		
LOOP:	
    DECFSZ  DelayCount,f	
    BRA	    LOOP		
    RETURN
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    ; 7000 + 7f9
    ; 77f9
    org 7000h
    DB "We're no strangers to love", 0x0A, "You know the rules and so do I", 0x0A, "A full commitment's what I'm thinking of", 0x0A, "You wouldn't get this from any other guy", 0x0A, "I just wanna tell you how I'm feeling", 0x0A, "Gotta make you understand", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "We've known each other for so long", 0x0A, "Your heart's been aching, but you're too shy to say it", 0x0A, "Inside, we both know what's been going on", 0x0A, "We know the game, and we're gonna play it", 0x0A, "And if you ask me how I'm feeling", 0x0A, "Don't tell me you're too blind to see", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "Ooh (Give you up)", 0x0A, "Ooh-ooh (Give you up)", 0x0A, "Ooh (Never gonna give, never gonna give)", 0x0A, "Give you up", 0x0A, "Ooh-ooh (Never gonna give, never gonna give)", 0x0A, "Give you up", 0x0A, "We've known each other for so long", 0x0A, "Your heart's been aching, but you're too shy to say it", 0x0A, "Inside, we both know what's been going on", 0x0A, "We know the game, and we're gonna play it", 0x0A, "I just wanna tell you how I'm feeling", 0x0A, "Gotta make you understand", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you", 0x0A, "Never gonna give you up", 0x0A, "Never gonna let you down", 0x0A, "Never gonna run around and desert you", 0x0A, "Never gonna make you cry", 0x0A, "Never gonna say goodbye", 0x0A, "Never gonna tell a lie and hurt you"