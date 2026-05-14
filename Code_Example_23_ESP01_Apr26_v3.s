; -----------------------------------------------------------------------------
; EMK310
; ESP-01 Example
; Lecturer: Prof T Hanekom
; Date of last revision: April 2025
;-------------------------------------------------------------------------------
; Example to implement communication with ESP-01 via RS232
;-------------------------------------------------------------------------------
; https://github.com/beckdac/ESP8266-transparent-bridge
;+++AT                                    # do nothing, print OK
;+++AT MODE                               # print current opmode
;+++AT MODE <mode: 1= STA, 2= AP, 3=both> # set current opmode
;+++AT STA                                # print current ssid and password connected to
;+++AT STA <ssid> <password>              # set ssid and password to connect to
;+++AT AP                                 # print the current soft ap settings
;+++AT AP <ssid>                          # set the AP as open with specified ssid
;+++AT AP <ssid> <pw> [<authmode> [hide-ssid [<ch>]]]]
;                                         # set the AP ssid and password, authmode:1= WEP,2= WPA,3= WPA2,4= WPA+WPA2, 
;                                         # hide-ssid:1-hide, 0-show(not hide), channel: 1..13
;+++AT BAUD                               # print current UART settings
;+++AT BAUD <baud> [data [parity [stop]]] # set current UART baud rate and optional data bits = 5/6/7/8 , parity = N/E/O, stop bits = 1/1.5/2
;+++AT PORT                               # print current incoming TCP socket port
;+++AT PORT <port>                        # set current incoming TCP socket port (restarts ESP)
;+++AT FLASH                              # print current flash settings
;+++AT FLASH <1|0>                        # 1: The changed UART settings (++AT BAUD ...) are saved ( Default after boot), 0= no save to flash.
;+++AT RESET                              # software reset the unit
;+++AT GPIO2 <0|1|2 100>                  # 1: pull GPIO2 pin up (HIGH) 0: pull GPIO2 pin down (LOW) 2: reset GPIO2, where 100 is optional to specify reset delay time in ms (default 100ms)
;+++AT SHOWIP				  # Display Station IP Address, gateway and netmask
;+++AT SHOWMAC				  # Display Station MAC.
;+++AT SCAN				  # Display available networks around
    
    
    
;--- Device definition ---
    PROCESSOR    18F45K22
    
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
    
;--- Header files ---
    #include    "pic18f45K22.inc"
    #include	<xc.inc>
    
;--- Register definitions ---
    						
    Delay1	EQU 0x0
    Delay2	EQU 0x1
    Flags	EQU 0x2
    BUFF1	EQU 0x3
    CHAR_count  EQU 0x4   
    RX_Start	EQU 0x5
    LINK_ID	EQU 0x6
    TEMP1	EQU 0x7
    TEMP2	EQU 0x8
    
;--- Flag definitions ---
    RCB		EQU 0	; Reception Busy
    TXB		EQU 1	; Transmission Busy
    YOK		EQU 2	; Yes, OK detected
    SER		EQU 3	; Serial error detected
    HiMARV	EQU 4	; Hi MARV! received from browser

;--- Vectors ---
PSECT code, abs
    org	    00h
    goto    Start
    org	    08h
    goto    ISR
 
;---------- Configuration ------------------------------------------------------
;<editor-fold defaultstate="collapsed" desc="Initialization for ESP-01 comms">
Start:	
    ;Initialize variables
    CLRF    Flags,0
    CLRF    BUFF1,0
    
    MOVLB   0xF
    
    ; Set up oscillator @ 16 MHz
    BSF	    IRCF0
    BSF	    IRCF1
    BSF	    IRCF2
    
    ; Port A configuration    
    CLRF    TRISA,a
    CLRF    LATA,a    
    CLRF    ANSELA,b    
       
    ; Port D configuration    
    CLRF    TRISD,a
    CLRF    LATD,a    
    CLRF    ANSELD,1
       
; Baud rate setup @ 115 200 kB(Circuitdigest.com)
    ; Setting I/O pins for UART
    BSF	    TRISC,6,0 ; TX Pin set as output
    BSF	    TRISC,7,0 ; RX Pin set as output
    CLRF    ANSELC,1
    
    ; Initialize SPBRG register for required baud rate and set BRGH for fast baud_rate
    BSF     TXSTA1,2,0   	; Enable high BAUDrate
    BSF	    BAUDCON1,3,0
    
    ; 115200 BAUD
    MOVLW   34
    MOVWF   SPBRG1,0
    CLRF    SPBRGH1,0
    
    ; Enable Asynchronous serial port
    BCF     TXSTA1,4,0		; Enable asynchronous transmission
    BSF	    RCSTA1,7,0		; Enable Serial Port (Datasheet RX#3)    
    
    ; Set up transmission & reception    
    BSF	    TXSTA1,5,0		; Enable transmittion    
    BSF	    RCSTA1,4,0		; Enable continuous reception  
    
    ; set up interrupts    
    BSF    RCIE			; Set RCIE Interrupt Enable (Datasheet RX#4)
    BSF    PEIE			; Enable peripheral interrupts
    BSF    GIE			; Enable global interrupts
    
    ; Clear all file registers    
    LFSR    0, 0x00 
    MOVLW   0x06		; Data memory only implemented to 0x5FF
NEXT: 
    CLRF    POSTINC0,0		; Clear INDF register then inc pointer
    CPFSEQ  FSR0H,0		; All done?
    BRA	    NEXT		; NO, clear next
    
    MOVLB   0x0   
;</editor-fold>
    
;---------- Main loop sending data to terminal ---------------------------------
Main:        
    ; Wait for Port to stabilize
    CALL    DELAY        

;----- Check if the module started 
; <editor-fold defaultstate="collapsed" desc="ESP Start">
ESP_ready:
    ; Set table address to read command (program memory)
    MOVLW   ESP_AT
    MOVWF   TBLPTRL,0
    ; Rotate the address at label ESP_AT right with 8 bits to move the high 
    ; byte into the WREG.
    MOVLW   (ESP_AT>>8)
    MOVWF   TBLPTRH,0
    ; Rotate the address at label ESP_AT right with 16 bits to move the upper
    ; byte into the WREG.
    MOVLW   (ESP_AT>>16)
    MOVWF   TBLPTRU,0
    
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
      
    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND     
    CALL    DELAY		; Wait for reception to finish           
    
    ; Test response
    CALL    RESPONSE_OK    
    ;</editor-fold>
    
;----- Restart ESP module  
;<editor-fold defaultstate="collapsed" desc="ESP Restart">    
ESP_restart:
    ; Test if module started
    BTFSC   Flags,YOK,0
    GOTO    SET_ESP_Wifi_Mode
    
    ; Set table address to read command (program memory)
    MOVLW   ESP_REST
    MOVWF   TBLPTRL,0
    MOVLW   (ESP_REST>>8)   ;high ESP_REST
    MOVWF   TBLPTRH,0
    MOVLW   (ESP_REST>>16)  ;upper ESP_REST
    MOVWF   TBLPTRU,0    
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
    
    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		; Wait for reception to finish
    
    ; Test response
    CALL    RESPONSE_OK
    BTFSS   Flags,YOK,0    
    
    GOTO    ESP_restart
    ;</editor-fold>
    
;----- Set Wifi Mode 
;<editor-fold defaultstate="collapsed" desc="SET ESP Wifi mode">
SET_ESP_Wifi_Mode:    
    ; Set table address for command    
    MOVLW   Set_WIFI_AP
    MOVWF   TBLPTRL,0
    MOVLW   (Set_WIFI_AP>>8)	    ;high Set_WIFI_STA
    MOVWF   TBLPTRH,0
    MOVLW   (Set_WIFI_AP>>16)    ;upper Set_WIFI_STA
    MOVWF   TBLPTRU,0
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
 
    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		    ; Wait for reception to finish
    
    ; Test response
    CALL    RESPONSE_OK
    ;</editor-fold>
    
;----- Check mode of ESP
;<editor-fold defaultstate="collapsed" desc="Query ESP Wifi mode">
Query_ESP_Wifi_Mode:
    ; Set table address for command    
    MOVLW   Qry_MODE
    MOVWF   TBLPTRL,0
    MOVLW   (Qry_MODE>>8)   ;high Qry_MODE
    MOVWF   TBLPTRH,0
    MOVLW   (Qry_MODE>>16)  ;upper Qry_MODE
    MOVWF   TBLPTRU,0
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
 
    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		; Wait for reception to finish 
    
    ; Test response
    CALL    RESPONSE_OK
    ;</editor-fold>

;=== For AP (access point) mode ===
;----- Set SSID credentials (AP mode)
;<editor-fold defaultstate="collapsed" desc="ESP SSID">
SET_ESP_SSID:
    ; Set table address for command    
    MOVLW   SET_SSID
    MOVWF   TBLPTRL,0
    MOVLW   (SET_SSID>>8)  ;high SET_SSID
    MOVWF   TBLPTRH,0
    MOVLW   (SET_SSID>>16) ;upper SET_SSID
    MOVWF   TBLPTRU,0
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200

    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		; Wait for reception to finish
    
    ; Test response
    CALL    RESPONSE_OK
    ;</editor-fold>       

;----- Enable multiple connections
;<editor-fold defaultstate="collapsed" desc="Enable multiple connections">
Enable_multiple_connections:
    ; Set table address for command    
    MOVLW   SET_MUL_CON
    MOVWF   TBLPTRL,0
    MOVLW   (SET_MUL_CON>>8)	;high SET_MUL_CON
    MOVWF   TBLPTRH,0
    MOVLW   (SET_MUL_CON>>16)	;upper SET_MUL_CON
    MOVWF   TBLPTRU,0
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200

    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		; Wait for reception to finish
    
    ; Test response
    CALL    RESPONSE_OK
    ;</editor-fold>
    
;----- Start the server at port 80
;<editor-fold defaultstate="collapsed" desc="Start server at port 80">
SET_ESP_Server_Port80:
    ; Set table address for command    
    MOVLW   SET_SRVR
    MOVWF   TBLPTRL,0
    MOVLW   (SET_SRVR>>8)   ;high SET_SRVR
    MOVWF   TBLPTRH,0
    MOVLW   (SET_SRVR>>16)  ;upper SET_SRVR
    MOVWF   TBLPTRU,0
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
 
    ; Serial comms
    CALL    TRANSMIT_ESP_COMMAND  
    CALL    DELAY		; Wait for reception to finish
    
    ; Test response
    CALL    RESPONSE_OK
    ;</editor-fold>    
    
;----- PIC receive data
;<editor-fold defaultstate="collapsed" desc="Receive data via Wifi">
; Connect to the "MyESP" network (no internet, that's normal). 
; Then, open a browser and enter: 
;	http://192.168.4.1/data?val=Hi MARV!
; Phone browser is stricter then PC browser, so you will have to send a 
; complete, properly formatted HTTP response (not shown here) for phone browser 
; not to time out.   
    
    ; Set buffer address to receive response (data memory)
    LFSR    0, 0x200
    CLRF    RX_Start
    
Wait_for_UART_data:
    BTFSS   RX_Start,0 
    GOTO    Wait_for_UART_data
    
    CALL    DELAY	; Wait for reception to finish    
    CALL    DELAY	; Wait for reception to finish    
    
    CALL    Parse_data_HTTP
			; Some subroutine to parse the received data
			; Look for GET/data?val= which will be followed by the data        
    

    CLRF    RX_Start   
    LFSR    0, 0x200
    GOTO    Wait_for_UART_data
;</editor-fold>        
    
;---------- Serial comms subroutines -------------------------------------------
;<editor-fold defaultstate="collapsed" desc="Transmit ESP command string">
;--- Transmit a string from table start address to 0x00    
TRANSMIT_ESP_COMMAND:       
    ;Read byte from table
Read_string:
    TBLRD*+ 
    ;hold the program till TX buffer is free
Wait_for_TX_ready:
    BTFSS   TXSTA1,1,0	
    BRA     Wait_for_TX_ready    
    
    ;test for \0    
    MOVLW   0x00   
    CPFSEQ  TABLAT,0
    GOTO    Continue_Tx
    GOTO    End_Tx
Continue_Tx:    
    ;transmit byte
    MOVFF   TABLAT,TXREG1    
    BRA	    Read_string    
    
End_Tx:
    ;Signal transmision done    
    CALL    FLASH_RA6_1    
    RETURN
;</editor-fold>    
    
;<editor-fold defaultstate="collapsed" desc="Transmit Byte">
;--- Tx Byte (Byte must be pre-loaded in BUFF1) ---
BYTE_TX:
    BTFSS   TXIF	;hold the program till TX buffer is free
    GOTO    BYTE_TX
    
    MOVFF   BUFF1,TXREG1
POLL_TX:    
    BTFSS   TXSTA1,1,0
    GOTO    POLL_TX
    MOVWF   PORTD,0
    bsf	    PORTA,6,0
    CALL    DELAY
    bcf	    PORTA,6,0
    RETURN
;</editor-fold>
 
;<editor-fold defaultstate="collapsed" desc="Receive bytes and write to buffer">
;---------- RX Interrupt service routine ---------------------------------------
ISR:        
      
    MOVFF   RCREG1,POSTINC0	; Write received byte to buffer
    BSF	    RX_Start,0		; Flag to indicate that reception started.
				; Will only use it when listening for incoming data
    
    ; Error handling : overrun error
    BTFSC   RCSTA1,1,0		;if overrun error occurred
    CALL    ErrSerialOverr	;then go handle error
    ; Error handling : framing error
    BTFSC   RCSTA1,2,0		
    CALL    ErrSerialFrame	
    ; Test if error occured
    BTFSC   Flags,SER,0	
    BRA	    EXIT_NO_RC
    
    ; If byte was correctly received, leave byte in buffer
EXIT_RC:        
    RETFIE
        
    ; If byte was not correctly received, delete byte from buffer
EXIT_NO_RC:    
    MOVLW   10000001B	    ;-1
    CLRF    PLUSW0,0   
    RETFIE
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Error subroutines">
;------------------- OERR overrun error bit is set ---
ErrSerialOverr:	
    bcf	    RCSTA1,4,0	;reset the receiver logic
    bsf	    RCSTA1,4,0	;enable reception again
    bsf	    Flags,SER,0
    return

;------------------- FERR framing error bit is set ---
ErrSerialFrame:	
    movf    RCREG1,0,0		;discard received data that has error
    bsf	    Flags,SER,0
    return
;</editor-fold>
		
;---------- Interpret responses ------------------------------------------------
;<editor-fold defaultstate="collapsed" desc="Response OK?">
RESPONSE_OK:
    ; Look for O (79d or 4Fh) and K (75d or 4Bh)    
    LFSR    0,0x200
    
    Find_O:
    MOVF    POSTINC0,0,0
    BZ      ESP_NotOK
    
    XORLW   'O'
    BNZ     Find_O
    
    MOVF    POSTINC0,0,0
    XORLW   'K'
    BNZ     Find_O
    
ESP_OK:
    CALL    FLASH_RA6_2
    BSF	    Flags,YOK,0
    GOTO    Exit_OK
    
ESP_NotOK:    
    CALL    FLASH_RA6_SOS
    BCF	    Flags,YOK,0
    GOTO    Exit_OK

Exit_OK:    
    CALL    Clear_Banks2and3    
    RETURN	
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Wifi connected?">
WIFI_CONNECTED:
    ; Look for WIFI GOT IP   
    LFSR    0,0x200

Find_W:
    MOVF    POSTINC0,0,0
    BZ      ESP_WIFI_Not_IP
   	
    XORLW   'W'
    BNZ     Find_W

    MOVF    POSTINC0,0,0
    XORLW   'I'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'F'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'I'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   0x0	    ; space
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'G'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'O'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'T'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   0x20	    ; space
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'I'
    BNZ     Find_W
    
    MOVF    POSTINC0,0,0
    XORLW   'P'
    BNZ     Find_W    
    
ESP_WIFI_GOT_IP:
    CALL    FLASH_RA6_2
    BSF	    Flags,YOK,0
    GOTO    Exit_WIFI_connected
    
ESP_WIFI_Not_IP:   
    CALL    FLASH_RA6_SOS
    BCF	    Flags,YOK,0
    GOTO    Exit_WIFI_connected

Exit_WIFI_connected:    
    CALL    Clear_Banks2and3    
    RETURN	
;</editor-fold>
  
;<editor-fold defaultstate="collapsed" desc="Parse HTTP data and respond">
Parse_data_HTTP:    
        
    ; Scan receive buffer at 0x200 for "+IPD,"
    LFSR    0, 0x200    

Find_IPD_Plus:
    MOVF    POSTINC0,0,0
    BNZ     CheckPlus
    RETURN                  ; end of buffer, nothing found

CheckPlus:
    XORLW   '+'
    BNZ     Find_IPD_Plus

    ; expect I
    MOVF    POSTINC0,0,0
    XORLW   'I'
    BNZ     Find_IPD_Plus

    ; expect P
    MOVF    POSTINC0,0,0
    XORLW   'P'
    BNZ     Find_IPD_Plus

    ; expect D
    MOVF    POSTINC0,0,0
    XORLW   'D'
    BNZ     Find_IPD_Plus

    ; expect ,
    MOVF    POSTINC0,0,0
    XORLW   ','
    BNZ     Find_IPD_Plus

    ; next byte should be link ID ASCII: '0'..'4'
    MOVFF   POSTINC0,LINK_ID

    ; Determine a response
    CALL    Parse_Hi_MARV
    BTFSC   Flags, HiMARV   
    GOTO    Send_Hi
    ; Random text: Hello from PIC
    CALL    SEND_HTTP_REPLY_random
    GOTO    Parse_done
    ; Answer to Hi MARV!: Hi buddy!

Send_Hi:
    CALL    SEND_HTTP_REPLY_HiMARV
    
Parse_done:
    BCF	    Flags, HiMARV    
    RETURN
;</editor-fold>
  
;<editor-fold defaultstate="collapsed" desc="Parse Hi MARV!">
;------------------------------------------------------------
Parse_Hi_MARV:
    ; Look for Hi MARV!   
    LFSR    0,0x200

Find_H:
    MOVF    POSTINC0,0,0
    BZ      Random_message
   	
    XORLW   'H'
    BNZ     Find_H

    MOVF    POSTINC0,0,0
    XORLW   'i'
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   '%'	    ; space: %20
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   '2'	    ; space: %20
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   '0'	    ; space: %20
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   'M'
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   'A'
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   'R'
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   'V'
    BNZ     Find_H
    
    MOVF    POSTINC0,0,0
    XORLW   '!'
    BNZ     Find_H    
    
HiMARV_message:
    BSF	    Flags,HiMARV,0
    GOTO    Exit_HiMARV
    
Random_message:   
    BCF	    Flags,HiMARV,0
    GOTO    Exit_HiMARV

Exit_HiMARV:        
    RETURN

;</editor-fold>
  
;<editor-fold defaultstate="collapsed" desc="Send HTTP reply to random message">
; HTTP reply to random text, e.g. MARV123
; Assumes LINK_ID contains ASCII '0'..'4'

SEND_HTTP_REPLY_random:
    ;-------------------------------
    ; Send: AT+CIPSEND=
    ;-------------------------------
    MOVLW   CIPSEND_HDR
    MOVWF   TBLPTRL,0
    MOVLW   (CIPSEND_HDR>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (CIPSEND_HDR>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    ; send link ID character
    MOVFF   LINK_ID,BUFF1
    CALL    BYTE_TX

    ; send: ,89\r\n
    MOVLW   CIPSEND_TAIL_random
    MOVWF   TBLPTRL,0
    MOVLW   (CIPSEND_TAIL_random>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (CIPSEND_TAIL_random>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    ; small wait for '>' prompt from ESP
    CALL    DELAY
    CALL    DELAY

    ;-------------------------------
    ; Send HTTP payload
    ; length must match CIPSEND_TAIL
    ;-------------------------------
    MOVLW   HTTP_REPLY_random
    MOVWF   TBLPTRL,0
    MOVLW   (HTTP_REPLY_random>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (HTTP_REPLY_random>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    CALL    DELAY
    CALL    DELAY  

    RETURN
;</editor-fold>
  
;<editor-fold defaultstate="collapsed" desc="Send HTTP reply to Hi MARV!">
    ; HTTP reply to Hi MARV!
    ; Assumes LINK_ID contains ASCII '0'..'4'
    
    SEND_HTTP_REPLY_HiMARV:
    ;-------------------------------
    ; Send: AT+CIPSEND=
    ;-------------------------------
    MOVLW   CIPSEND_HDR
    MOVWF   TBLPTRL,0
    MOVLW   (CIPSEND_HDR>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (CIPSEND_HDR>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    ; send link ID character
    MOVFF   LINK_ID,BUFF1
    CALL    BYTE_TX

    ; send: , \r\n
    MOVLW   CIPSEND_TAIL_HiMARV
    MOVWF   TBLPTRL,0
    MOVLW   (CIPSEND_TAIL_HiMARV>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (CIPSEND_TAIL_HiMARV>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    ; small wait for '>' prompt from ESP
    CALL    DELAY
    CALL    DELAY

    ;-------------------------------
    ; Send HTTP payload
    ; length must match CIPSEND_TAIL
    ;-------------------------------
    MOVLW   HTTP_REPLY_HiMARV
    MOVWF   TBLPTRL,0
    MOVLW   (HTTP_REPLY_HiMARV>>8)
    MOVWF   TBLPTRH,0
    MOVLW   (HTTP_REPLY_HiMARV>>16)
    MOVWF   TBLPTRU,0
    CALL    TRANSMIT_ESP_COMMAND

    CALL    DELAY
    CALL    DELAY  

    RETURN
;</editor-fold>
    
    
		
;---------- Auxiliary subroutines ----------------------------------------------
;<editor-fold defaultstate="collapsed" desc="Delay">
;--- Delay ---		
DELAY:        
    CLRF    Delay2,0
LOOP_OUTER:
    CLRF    Delay1,0
LOOP_INNER:	
    DECFSZ  Delay1,1,0
    BRA	    LOOP_INNER
    DECFSZ  Delay2,1,0
    BRA	    LOOP_OUTER
    RETURN
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Flash RA6">		
FLASH_RA6_1:
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0    
    RETURN
    
FLASH_RA6_2:
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0    
    RETURN
    
FLASH_RA6_SOS:
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0    
    CALL    DELAY
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0   
    CALL    DELAY
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0
    CALL    DELAY
    
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0
    CALL    DELAY    
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0        
    CALL    DELAY
    BSF	    PORTA,6,0
    CALL    DELAY
    CALL    DELAY
    BCF	    PORTA,6,0    
    CALL    DELAY
    
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0    
    CALL    DELAY
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0    
    CALL    DELAY
    BSF	    PORTA,6,0    
    CALL    DELAY
    BCF	    PORTA,6,0
    CALL    DELAY    
    RETURN
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Clear_Banks 2 and 3">
Clear_Banks2and3:
; Clear file registers in Bank 2   
    LFSR    0, 0x200	;
    MOVLW   0x04	; Start address of Bank 4, so stop.
Erase: 
    CLRF    POSTINC0,0	; Clear INDF register then inc pointer
    CPFSEQ  FSR0H ,0	; All done?
    BRA	    Erase	; NO, clear next
    RETURN
;</editor-fold>
  

;---------- AT command tables --------------------------------------------------    
;<editor-fold defaultstate="collapsed" desc="AT command tables">
;----------- Store AT commands
    ORG 0x1000    
;Check if the module started
ESP_AT:	    DB "AT",0x0D,0x0A,0x00		    ; Command\r\n\0
   ; Response = OK
    
;Restart module until proper response is received
ESP_REST:   DB "AT+RST",0x0D,0x0A,0x00
   ; Response = OK
	    
; Set Wifi mode to Station and AP mode
    ; In dual mode (both Station and Access Point), the ESP-01 Wi-Fi module functions as both a client and a host.
    ; As a Station, the ESP-01 connects to an external Wi-Fi network, allowing it to access internet services 
    ; or interact with other devices on that network. This mode is essential for applications where the ESP-01 
    ; needs to send or receive data over the internet or a local network.
    ;
    ; Concurrently, in Access Point mode, the ESP-01 acts as a Wi-Fi network, or access point itself, allowing 
    ; other Wi-Fi enabled devices to connect to it. This setup facilitates two-way communication between 
    ; the ESP-01 and the devices connected to it directly via Wi-Fi. It serves as a local hub for Wi-Fi 
    ; devices, enabling data exchange and direct control capabilities within a localized network environment.
    ;
    ; By operating in both modes simultaneously, the ESP-01 can bridge or relay data between the internet 
    ; or a broader network and its own local network of directly connected devices. This dual functionality 
    ; expands the module's use in various IoT applications, allowing it to function as an intermediary 
    ; that can both control local devices and communicate externally as needed.

Set_WIFI_STAAP:   DB "AT+CWMODE=3",0x0D,0x0A,0x00	    ; Command\r\n\0	    
    ; Response = OK
   
; Set Wifi mode to SoftAP mode
    ;In AP the Wi-Fi module acts as a Wi-Fi network, or access point allowing 
    ;other devices to connect to it. It establishes two way communication between
    ;the ESP and the device that is connected to it via Wi-Fi.
Set_WIFI_AP:   DB "AT+CWMODE=2",0x0D,0x0A,0x00	    ; Command\r\n\0	    
    ; Response = OK
    
; Set Wifi mode to station mode
    ;The ESP-01 can connect to an AP such as the Wi-Fi network from your house. 
    ;This allows any device connected to that network to communicate with the 
    ;module.
Set_WIFI_STA:   DB "AT+CWMODE=1",0x0D,0x0A,0x00	    ; Command\r\n\0	    
    ; Response = OK
	    
; Query softAP settings
Qry_SSID:   DB "AT+CWSAP?",0x0D,0x0A,0x00	    ; Command\r\n\0   

;SET_SSID:   DB "AT+CWSAP=\"MyESP\",\"0000\",1,0,4,0",0x0D,0x0A,0x00 ;Command\r\n\0
SET_SSID:   DB "AT+CWSAP=\"MyESP\",\"\",1,0,4,0",0x0D,0x0A,0x00 ;Command\r\n\0

; Connect to your network
SET_SECRET: DB "AT+CWJAP=\"Wi-FiNetwork\",\"Password\"",0x0D,0x0A,0x00 ;Command\r\n\0
   
;check if we are connected to wifi network
Qry_WiFi:   DB	"AT+CIFSR",0x0D,0x0A,0x00	    ;Command\r\n\0
   
;Start the server at port 80
   ; Single = 0
   ; Multiple = 1
SET_SRVR:   DB	"AT+CIPSERVER=1,80",0x0D,0x0A,0x00   ;Command\r\n\0 
   
;Check what mode your Wi-Fi module is in
Qry_MODE:   DB	"AT+CWMODE?",0x0D,0x0A,0x00	    ;Command\r\n\0 
   
; Enable multiple connections to allow ESP-01 to be configured as a server
SET_MUL_CON: DB	"AT+CIPMUX=1",0x0D,0x0A,0x00	    ;Command    
 
;------------------------------------------------------------
; Web reply support tables
;------------------------------------------------------------

; "AT+CIPSEND="
CIPSEND_HDR: DB "AT+CIPSEND=",0x00

; link id is inserted separately, then this tail is sent
; 98 bytes payload
CIPSEND_TAIL_random: DB ",98",0x0D,0x0A,0x00
 
; HTTP payload
HTTP_REPLY_random:
    DB "HTTP/1.1 200 OK",0x0D,0x0A	    ; HTTP/1.1 200 OK\r\n (17)
    DB "Content-Type: text/plain",0x0D,0x0A ; Content-Type: text/plain\r\n (26)
    DB "Content-Length: 14",0x0D,0x0A	    ; (Hello from PIC) (20)
    DB "Connection: close",0x0D,0x0A	    ; Connection: close\r\n (19)
    DB 0x0D,0x0A			    ; \r\n (2)
    DB "Hello from PIC",0x00		    ; Hello from PIC (14)
    
; link id is inserted separately, then this tail is sent
; 92 bytes payload
CIPSEND_TAIL_HiMARV: DB ",92",0x0D,0x0A,0x00
 
; HTTP payload
HTTP_REPLY_HiMARV:
    DB "HTTP/1.1 200 OK",0x0D,0x0A	    ; HTTP/1.1 200 OK\r\n (17)
    DB "Content-Type: text/plain",0x0D,0x0A ; Content-Type: text/plain\r\n (26)
    DB "Content-Length: 9",0x0D,0x0A	    ; (Hello from PIC) (19)
    DB "Connection: close",0x0D,0x0A	    ; Connection: close\r\n (19)
    DB 0x0D,0x0A			    ; \r\n (2)
    DB "Hi Buddy!",0x00			    ; Hi Buddy! (9)

;</editor-fold>
    
;--- End of code ---
    end





