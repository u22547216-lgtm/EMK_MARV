; -----------------------------------------------------------------------------
; EMK310 
; MARVelous Micros Code Example 8
; Lecturer: Prof T Hanekom
; Contributors: Dylan Brown, Natalie Hanekom
; Date of last revision: February 2025
; -----------------------------------------------------------------------------
; Description:
; RB change interrupt on PortB.5 example
; LED on, flash 3 times when interrupt occurs
; -----------------------------------------------------------------------------
; Check list: 	
; 1. Stimulator to simulate interrupt
; -----------------------------------------------------------------------------

    PROCESSOR   18F45K22
	
;========== Definition of variables ==========
;EQU statements where CBlock used to be:
    Delay1	EQU    0x0
    Delay2	EQU    0x1
    Count	EQU    0x2
    SecondIOCB	EQU    0x3 ; For flagging the second IOCB
	
;------- End of legacy CBlock -------
	; Assign constant value to No_of_blinks
    No_of_blinks set 0x03  


;========== Configuration bits ==========
  CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
  CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
  
  #include    <xc.inc>
  #include    "pic18f45k22.inc"

  ;========== Reset vector ==========
    PSECT code,abs //Start of main code.
	org 	00h
	goto 	Setup

;========== Interrupt vector ==========
	org 	08h
	goto 	ISR ;goto interrupt service routine
	
;========== Setup ==========
		
Setup:
	; Initialize Port A
	MOVLB	0xF
	CLRF 	PORTA 		; Initialize PORTA by clearing output data latches
	CLRF 	LATA 		; Alternate method to clear output data latches
	CLRF	ANSELA 		; Configure I/O
	CLRF 	TRISA		; All digital outputs
		
	; Set up Port B pin B.4 for interrupt on change
	BSF 	TRISB,0x04	; make IO Pin B.4 an input
	BSF 	IOCB4		; Set IOCB4 to enable Interrupt on change on Port B.4
	CLRF 	ANSELB		; Configure I/O

	; Set up Port B change interrupt
	clrf 	INTCON		; clear all interrupt bits
	BSF 	RBIE 	; enable RB change interrupt
	BSF	GIE	; enable interrupts
	MOVLB	0x00
	
;========== Main program ==========
Main:
	BSF	PORTA,4		; turn on LED A.4
	NOP
	NOP
	NOP
	GOTO 	Main
	
;========== Interrupt service routine ==========
ISR:	MOVF	PORTB 		; Why do we need this line of code?
	BTG	SecondIOCB,0	; Toggle the value of bit 0
	BTFSC	SecondIOCB,0	; Only execute on the first IOCB
	GOTO	ExitISR
	MOVLW	No_of_blinks
	MOVWF	Count
flash:	BCF	PORTA,4		; turn off LED
	CALL 	Delay_loop
	BSF	PORTA,4		; turn on LED 
	CALL 	Delay_loop
	DECFSZ 	Count,1
	GOTO 	flash
ExitISR:
	BCF 	RBIF	; clear RB change interrupt flag
	RETFIE

;========== Delay subroutine ==========
Delay_loop:			
	MOVLW	0xAA
	MOVWF	Delay2		
Go1:					
	MOVLW	0xBB
	MOVWF	Delay1
Go2:
	DECFSZ	Delay1,f	
	GOTO	Go2		
	DECFSZ	Delay2,f	
	GOTO	Go1		

	RETURN
	
	end