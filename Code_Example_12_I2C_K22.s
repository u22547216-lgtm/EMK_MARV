;-------------------------------------------------------------------------------
; EMK310
; MARVellous Micros Code Example 12
; Lecturer: Prof T Hanekom
; Date of last revision: April 2026
;-------------------------------------------------------------------------------
; I2C firmware to send and receive three bytes
; The received bytes are streamed to data memory from 0x200
; EEPROM device: 24AA02 / 24LC02B
;-------------------------------------------------------------------------------

    PROCESSOR   18F45K22

;--- Configuration bits
    CONFIG FOSC = INTIO67
    CONFIG WDTEN = OFF

;--- Include files
    #include    <xc.inc>
    #include    "pic18f45k22.inc"

;--- Variables
    TX_BYTE         EQU 0x0
    POLL_COUNTER    EQU 0x1
    Delay1          EQU 0x2
    Delay2          EQU 0x3
    EEPROM_ADDRESS  EQU 0x4
    CHAR_COUNT      EQU 0x5
    CHAR_WRITE      EQU 0x6
    TABLE_COUNTER   EQU 0x7
   
    PAGE_COUNT	    equ 0x8
    chars_left	    equ 0x9
    page_byte_count equ 0xA

    WRITE_CONTROL   EQU 10100000B
    READ_CONTROL    EQU 10100001B

;-------------------------------------------------------------------------------
; Vectors
;-------------------------------------------------------------------------------
PSECT code,abs
    org     00h
    GOTO    INIT
    
    
    org	    20h
    chars equ 86

    DB "Choose your MARV mode?", 0x0A, "(C)colour", 0x0A, "(R)eference", 0x0A, "(A)ttack", 0x0A, "(S)imulate race", 0x0A, "(H)otload EEPROM"
    
    
    org	    78h
    
;-------------------------------------------------------------------------------
; Initialisation
;-------------------------------------------------------------------------------
;<editor-fold defaultstate="collapsed" desc="Initialisation"> 
INIT:
    MOVLB   0x0F

;--- Oscillator @4MHz
    BSF     IRCF2
    BCF     IRCF1
    BSF     IRCF0

;--- PORTA Setup
    CLRF    PORTA,a
    MOVLW   00000000B
    MOVWF   TRISA,a
    CLRF    ANSELA,b

;--- PORTC Setup
    BSF     TRISC,3          ; RC3 = SCL1
    BSF     TRISC,4          ; RC4 = SDA1
    CLRF    ANSELC,b

;--- I2C setup
    ; 100 kHz @ Fosc = 4 MHz
    MOVLW   00001001B
    MOVWF   SSP1ADD

    ; SSP1STAT
    CLRF    SSP1STAT
    BSF     SSP1STAT,7       ; SMP = 1 for standard speed mode

    ; SSP1CON1: I2C Master mode, clock = FOSC/(4 * (SSPADD + 1))
    MOVLW   00101000B
    MOVWF   SSP1CON1

    ; SSP1CON2
    CLRF    SSP1CON2

    ; Clear interrupt flags
    BCF     SSP1IF
    BCF     BCL1IF

    MOVLB   0x00


    ;<editor-fold defaultstate="collapsed" desc="Setup for writing the menu screen to EEPROM">
    
    ; ---Setup for writing the menu screen to EEPROM with table stuff
    
    ; tbl works on program memory
    movlw   0b10000000
    movwf   EECON1,a
    
    ; set address of Table
    movlw   0
    movwf   TBLPTRU,a
    movwf   TBLPTRH,a
    movlw   0x20
    movwf   TBLPTRL,a
    
    
    ; page write count (im hard codeing this cause the menu is constant)
    movlw   10
    movwf   PAGE_COUNT,a
    movlw   6
    movwf   chars_left,a
    
    
    CLRF    EEPROM_ADDRESS
    
    MOVLW   29
    MOVWF   CHAR_COUNT
    
    ;<editor-fold defaultstate="collapsed" desc="Team 28 - our MARV is awesome">
    ;Team 28 - our MARV is awesome
    LFSR    0,0x200
    movlw 'T'
    movwf POSTINC0,a
    movlw 'e'
    movwf POSTINC0,a
    movlw 'a'
    movwf POSTINC0,a
    movlw 'm'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw '2'
    movwf POSTINC0,a
    movlw '8'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw '-'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw 'o'
    movwf POSTINC0,a
    movlw 'u'
    movwf POSTINC0,a
    movlw 'r'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw 'M'
    movwf POSTINC0,a
    movlw 'A'
    movwf POSTINC0,a
    movlw 'R'
    movwf POSTINC0,a
    movlw 'V'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw 'i'
    movwf POSTINC0,a
    movlw 's'
    movwf POSTINC0,a
    movlw ' '
    movwf POSTINC0,a
    movlw 'a'
    movwf POSTINC0,a
    movlw 'w'
    movwf POSTINC0,a
    movlw 'e'
    movwf POSTINC0,a
    movlw 's'
    movwf POSTINC0,a
    movlw 'o'
    movwf POSTINC0,a
    movlw 'm'
    movwf POSTINC0,a
    movlw 'e'
    movwf POSTINC0,a
    
    ;</editor-fold>

    ;MOVLW   'A'

;--- Clear file registers from 0x200 to 0x220
    LFSR    0, 0x100
    MOVLW   0x20
    MOVWF   TABLE_COUNTER

Clear_Data_Table:
    CLRF    POSTINC0
    DECFSZ  TABLE_COUNTER,f
    GOTO    Clear_Data_Table
    
start_char_of_write_data:
    ; inc pointer after a read
    TBLRD*+
    movwf   TABLAT,a
    MOVWF   CHAR_WRITE
    ;</editor-fold>
    
;</editor-fold>

;-------------------------------------------------------------------------------
; Write three characters to EEPROM
;-------------------------------------------------------------------------------
Main_write:
    ;<editor-fold defaultstate="collapsed" desc="1. Generate start condition">
    CALL    I2C_START_CONDITION
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="2. Load & send the control byte/slave address (WRITE)">    
    MOVLW   WRITE_CONTROL
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE
    
    ;--- Optional ACK check
    BTFSC   SSP1CON2,6       ; ACKSTAT = 1 means no ACK received
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="3. Load & send the address">
    MOVF    EEPROM_ADDRESS,W
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE    

    ;--- Optional ACK check
    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="4. Load & send the data in pages">
    MOVLW   8
    movwf   page_byte_count,a
    
page_loop:
    
    MOVF    CHAR_WRITE,W
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    ;--- Optional ACK check
    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    
    ;--- Increment the EEPORM address
    INCF    EEPROM_ADDRESS,F
    
    ;--- Fetch next letter to send
    TBLRD*+
    movwf   TABLAT,a
    MOVWF   CHAR_WRITE   
    
    decfsz  page_byte_count,a
    bra	page_loop
    
    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="5. Generate stop condition">    
    CALL    I2C_STOP_CONDITION
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="6. Wait for EEPROM internal write cycle to finish">
    CALL    POLLING_WRITE_ACK
    ;</editor-fold>
    
    ; Repeat 10 more times to write 80 characters in total
    CALL    DELAY
    DECFSZ  PAGE_COUNT,F
    GOTO    Main_write
    
    ; handling the last bit of chars that dont fill a full 8 bytes
    
    ;<editor-fold defaultstate="collapsed" desc="1. Generate start condition">
    CALL    I2C_START_CONDITION
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="2. Load & send the control byte/slave address (WRITE)">    
    MOVLW   WRITE_CONTROL
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE
    
    ;--- Optional ACK check
    BTFSC   SSP1CON2,6       ; ACKSTAT = 1 means no ACK received
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="3. Load & send the address">
    MOVF    EEPROM_ADDRESS,W
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE    

    ;--- Optional ACK check
    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="4. Load & send the last data in a page of 6 bytes">
    MOVLW   chars_left
    movwf   page_byte_count,a
    
page_loop_left_over:
    
    MOVF    CHAR_WRITE,W
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    ;--- Optional ACK check
    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    
    ;--- Increment the EEPORM address
    INCF    EEPROM_ADDRESS,F
    
    ;--- Fetch next letter to send
    TBLRD*+
    movwf   TABLAT,a
    MOVWF   CHAR_WRITE   
    
    decfsz  page_byte_count,a
    bra	page_loop_left_over
    
    
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="5. Generate stop condition">    
    CALL    I2C_STOP_CONDITION
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="6. Wait for EEPROM internal write cycle to finish">
    CALL    POLLING_WRITE_ACK
    ;</editor-fold>

;-------------------------------------------------------------------------------
; Read characters and stream to data memory
;-------------------------------------------------------------------------------
;--- Reload parameters
    CLRF    EEPROM_ADDRESS
    MOVLW   29
    MOVWF   CHAR_COUNT

;--- Stream data to 0x100 in data memory
    LFSR    0, 0x100

Main_read:

    ;<editor-fold defaultstate="collapsed" desc="1. Generate start condition">
    CALL    I2C_START_CONDITION
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="2. Load & send the control byte/slave address: WRITE">
    MOVLW   WRITE_CONTROL
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="3. Load and send the EEPROM word address">
    MOVF    EEPROM_ADDRESS,W
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="4. Restart to switch to receive mode">
    CALL    I2C_RESTART
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="5. Load and send the control byte/slave address: READ">
    MOVLW   READ_CONTROL
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    BTFSC   SSP1CON2,6
    GOTO    I2C_ERROR
    ;</editor-fold>

Read_char:
    ;<editor-fold defaultstate="collapsed" desc="6. Read byte into POSTINC0">
    CALL    my_I2C_READ_BYTE
    ;</editor-fold>

    ;<editor-fold defaultstate="collapsed" desc="7. ACK all but last byte, NACK the last byte">
    MOVLW   0x01
    CPFSEQ  CHAR_COUNT
    GOTO    More_Bytes

Last_Byte:
    CALL    I2C_SEND_NACK
    DECF    CHAR_COUNT,F
    GOTO    Read_done

More_Bytes:
    CALL    I2C_SEND_ACK
    DECF    CHAR_COUNT,F
    GOTO    Read_char
    ;</editor-fold>

Read_done:
    ;<editor-fold defaultstate="collapsed" desc="8. Stop">
    CALL    I2C_STOP_CONDITION
    ;</editor-fold>

    ; Code ends here in endless loop.
    CALL    DELAY
    GOTO    $               ; Hang here

;-------------------------------------------------------------------------------
; Subroutines
;-------------------------------------------------------------------------------

;-------------------------------------------------------
I2C_START_CONDITION:
    BCF     SSP1IF
    BSF     SSP1CON2,0      ; SEN = 1
wait_START:
    BTFSC   SSP1CON2,0
    BRA     wait_START
    BTFSS   SSP1STAT,3      ; S bit should be set after Start
    SETF    PORTA
    RETURN

;-------------------------------------------------------
I2C_RESTART:
    BCF     SSP1IF
    BSF     SSP1CON2,1      ; RSEN = 1
wait_RESTART:
    BTFSC   SSP1CON2,1
    BRA     wait_RESTART
    RETURN

;-------------------------------------------------------
I2C_STOP_CONDITION:
    BCF     SSP1IF
    BSF     SSP1CON2,2      ; PEN = 1
wait_STOP:
    BTFSC   SSP1CON2,2
    BRA     wait_STOP
    RETURN

;-------------------------------------------------------
my_I2C_WRITE:
    BTFSC   SSP1STAT,0      ; BF = 1 means buffer full
    GOTO    my_I2C_WRITE
    BCF     SSP1IF
    MOVF    TX_BYTE,W
    MOVWF   SSP1BUF
wait_WRITE:
    BTFSS   SSP1IF
    BRA     wait_WRITE
    RETURN

;-------------------------------------------------------
; Receive one byte and store at POSTINC0
; Does NOT send ACK/NACK
my_I2C_READ_BYTE:
    BCF     SSP1IF
    BSF     SSP1CON2,3      ; RCEN = 1, enable receive mode
WAIT1_READ:
    BTFSS   SSP1IF
    BRA     WAIT1_READ
    BTFSS   SSP1STAT,0      ; BF must be set when byte is received
    BRA     WAIT1_READ
    MOVF    SSP1BUF,W
    MOVWF   POSTINC0
    RETURN

;-------------------------------------------------------
I2C_SEND_ACK:
    BCF     SSP1CON2,5      ; ACKDT = 0 -> ACK
    BCF     SSP1IF
    BSF     SSP1CON2,4      ; ACKEN = 1
WAIT_ACK:
    BTFSS   SSP1IF
    BRA     WAIT_ACK
    RETURN

;-------------------------------------------------------
I2C_SEND_NACK:
    BSF     SSP1CON2,5      ; ACKDT = 1 -> NACK
    BCF     SSP1IF
    BSF     SSP1CON2,4      ; ACKEN = 1
WAIT_NACK:
    BTFSS   SSP1IF
    BRA     WAIT_NACK
    RETURN

;-------------------------------------------------------
; ACK polling for 24LC02B:
; After STOP, issue START and resend WRITE control byte
; until ACKSTAT = 0
POLLING_WRITE_ACK:
Poll_Loop:
    CALL    I2C_START_CONDITION

    MOVLW   WRITE_CONTROL
    MOVWF   TX_BYTE
    CALL    my_I2C_WRITE

    ; ACKSTAT = 1 => EEPROM still busy
    BTFSC   SSP1CON2,6
    GOTO    Poll_NotReady

Poll_Ready:
    CALL    I2C_STOP_CONDITION
    RETURN

Poll_NotReady:
    CALL    I2C_STOP_CONDITION
    GOTO    Poll_Loop

;-------------------------------------------------------
I2C_ERROR:
    CALL    FLASH_LED
    GOTO    $

;-------------------------------------------------------
FLASH_LED:
    MOVLW   11000000B
    MOVWF   PORTA,a
    CALL    DELAY
    MOVLW   10000000B
    MOVWF   PORTA,a
    RETURN

;-------------------------------------------------------
DELAY:
    MOVLW   0xFF
    MOVWF   Delay2
LOOP1:
    MOVLW   0xFF
    MOVWF   Delay1
LOOP2:
    DECFSZ  Delay1,F
    GOTO    LOOP2
    DECFSZ  Delay2,F
    GOTO    LOOP1
    RETURN

    end
