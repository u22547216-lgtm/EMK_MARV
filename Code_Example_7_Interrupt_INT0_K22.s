; -----------------------------------------------------------------------------
; EMK310 
; MARVellous Micros Code Example 7
; Lecturer: Prof T Hanekom
; Contributors: Dylan Brown, Natalie Hanekom
; Date of last revision: February 2024
; -----------------------------------------------------------------------------
; Description:
; External interrupt example
; LED on, flash 3 times when interrupt occurs
; -----------------------------------------------------------------------------
; Check list: 	1. Simulation vs ICD functionality
;               2. Stimulator to simulate interrupt
; -----------------------------------------------------------------------------

    PROCESSOR   18F45K22
	
;========== Definition of variables ==========

    Delay1			    EQU    0x0
    Delay2			    EQU    0x1
    Count			    EQU    0x2

; Assign constant value to No_of_blinks
No_of_blinks set 0x03   ; check the difference between set and equ
;No_of_blinks equ 0x03	; alternative to set

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
	GOTO	ISR
	ORG	18H
	goto 	ISR ;goto interrupt service routine
	
;========== Setup ==========
		
Setup:
; Initialize Port A 
	MOVLB	0xF
	CLRF 	PORTC,0		; Initialize PORTA by clearing output data latches
				; 0 = access bank
	CLRF 	LATC,0 		; Alternate method to clear output data latches
				; 0 = access bank
	CLRF	ANSELC,1 	; Configure I/O; 
				; 1 = banked ram
	CLRF 	TRISC,0		; All digital outputs
				; 0 = access bank
	
	; Set up Port B pin B.0 for external interrupt
	BSF 	TRISB,0x01,0	; make IO Pin B.0 an input
				; 0 = access bank
	CLRF	ANSELB,1
	MOVLB	0x00

	; Set oscillator speed at 4 MHz
	bsf 	IRCF0
	bcf	IRCF1
	bsf	IRCF2

	; Set up external interrupt
	CLRF 	INTCON,0    ; clear all interrupt bits
			    ; 0 = access bank
	CLRF	INTCON2,0
	CLRF	INTCON3,0
	BSF 	INT1IE	    ; enable RB1 interrupt
	BSF	INT1IP
	BSF	GIE	    ; enable interrupts
	
;========== Main program ==========
Main:
	BSF	PORTC,4,0		; turn on LED A.4; 0 = access bank
	NOP
	NOP
	NOP
	GOTO 	Main
	
;========== Interrupt service routine ==========
ISR:		; GIE automatically cleared upon branching to interrupt vector	
	MOVLW	No_of_blinks
	MOVWF	Count,a
		
flash:	BCF	PORTC,4,0		; turn off LED on pin 4
					; 0 = access bank
	CALL 	Delay_loop
	BSF	PORTC,4,0		; turn on LED on pin 4
					; 0 = access bank
	CALL 	Delay_loop
	DECFSZ 	Count,1,0		; 1 = store result in file; 0 = access bank
	GOTO 	flash
	BCF 	INT1IF			; clear RB0 interrupt flag
	RETFIE				;GIE automatically set upon return from ISR

;========== Delay subroutine ==========
Delay_loop:			
	MOVLW	0xAA
	MOVWF	Delay2,0		; 0 = access bank
Go1:					
	MOVLW	0xBB
	MOVWF	Delay1,0		; 0 = access bank
Go2:
	DECFSZ	Delay1,1,0		; 1 = store result in file; 0 = access bank
	GOTO	Go2		
	DECFSZ	Delay2,1,0		; 1 = store result in file; 0 = access bank
	GOTO	Go1		

	RETURN
	
	end