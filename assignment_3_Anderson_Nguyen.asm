;;Anderson Nguyen
;; #68319094
;the values are updated in registers, but LCD doesnt update value so change the value before running the program

ORG 0				; reset vector
	JMP main		; jump to the main program

ORG 3				; external 0 interrupt vector
	JMP ext0ISR		; jump to the external 0 ISR

ORG 0BH				; timer 0 interrupt vector
	JMP timer0ISR		; jump to timer 0 ISR

ORG 30H				; main program starts here
main:
	E EQU P3.2
	RS EQU P3.3
	mov r7, #0h
	mov r6, #0h
	mov r5, #0h
	SETB IT0		; set external 0 interrupt as edge-activated
	SETB EX0		; enable external 0 interrupt
	CLR P0.7		; enable DAC WR line
	MOV TMOD, #2		; set timer 0 as 8-bit auto-reload interval timer

	MOV TH0, #-200	; | put -50 into timer 0 high-byte - this reload value, 
   				; | with system clock of 12 MHz, will result in a timer 0 overflow every 50 us

	MOV TL0, #-200		; | put the same value in the low byte to ensure the timer starts counting from 
   				; | 236 (256 - 50) rather than 0

	SETB TR0		; start timer 0
	SETB ET0		; enable timer 0 interrupt
	SETB EA			; set the global interrupt enable bit
	JMP $			; jump back to the same line (ie: do nothing)

; end of main program


; timer 0 ISR - simply starts an ADC conversion
timer0ISR:
	CLR P3.6		; clear ADC WR line
	SETB P3.6		; then set it - this results in the required positive edge to start a conversion
	RETI			; return from interrupt


; external 0 ISR - responds to the ADC conversion complete interrupt
ext0ISR:
	CLR P3.7	; clear the ADC RD line - this enables the data lines
	MOV A, P2		; take the data from the ADC on P2 and send it to the DAC data lines on P1
	SETB P3.7		; disable the ADC data lines by setting RD
	mov r3, A
	
	mov B, #0Ah
	div AB
	mov r7, B

	mov B, #0Ah
	div AB
	mov r6, B

	mov B, #0Ah
	div AB
	mov r5, B

;multiplying 3 digits by 2	
	mov B, #02h
	mov A, r7
	mul AB
	mov r7, A

	mov B, #02h
	mov A, r6
	mul AB
	mov r6, A

	mov B, #02h
	mov A, r5
	mul AB
	mov r5, A

;checking for overflow
	mov B, #0Ah
	mov A, r7
	div AB
	mov r7, B
	jz cont1
	inc r6
cont1:
	mov B, #0Ah
	mov A, r6
	div AB
	mov r6, B
	jz cont2
	inc r5
cont2:
call display
RETI

display:
; put data in RAM
	CLR RS
		MOV A, R5
	ADD A, #30H
	MOV 30H, A

	MOV 31H, #2EH

	MOV A, R6
	ADD A, #30H
	MOV 32H, A

	MOV A, R7
	ADD A, #30H
	MOV 33H, A

	MOV 34H, #0	; end of data marker

	MOV 34H, #0	; end of data marker


; initialise the display
; see instruction set for details


	CLR P3.3		; clear RS - indicates that instructions are being sent to the module

; function set	
	CLR P1.7		; |
	CLR P1.6		; |
	SETB P1.5		; |
	CLR P1.4		; | high nibble set

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E

	CALL delay		; wait for BF to clear	
					; function set sent for first time - tells module to go into 4-bit mode
; Why is function set high nibble sent twice? See 4-bit operation on pages 39 and 42 of HD44780.pdf.

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E
					; same function set high nibble sent a second time

	SETB P1.7		; low nibble set (only P1.7 needed to be changed)

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E
				; function set low nibble sent
	CALL delay		; wait for BF to clear


; entry mode set
; set to increment with no shift
	CLR P1.7		; |
	CLR P1.6		; |
	CLR P1.5		; |
	CLR P1.4		; | high nibble set

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E

	SETB P1.6		; |
	SETB P1.5		; |low nibble set

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E

	CALL delay		; wait for BF to clear


; display on/off control
; the display is turned on, the cursor is turned on and blinking is turned on
	CLR P1.7		; |
	CLR P1.6		; |
	CLR P1.5		; |
	CLR P1.4		; | high nibble set

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E

	SETB P1.7		; |
	SETB P1.6		; |
	SETB P1.5		; |
	SETB P1.4		; | low nibble set

	SETB P3.1		; |
	CLR P3.1		; | negative edge on E

	CALL delay		; wait for BF to clear


; send data
	SETB P3.3		; clear RS - indicates that data is being sent to module
	MOV R1, #30H	; data to be sent to LCD is stored in 8051 RAM, starting at location 30H
loop:
	MOV A, @R1		; move data pointed to by R1 to A
	JZ finish		; if A is 0, then end of data has been reached - jump out of loop
	CALL sendCharacter	; send data in A to LCD module
	INC R1			; point to next piece of data
	JMP loop		; repeat

finish:
	RET


sendCharacter:
	MOV C, ACC.7		; |
	MOV P1.7, C			; |
	MOV C, ACC.6		; |
	MOV P1.6, C			; |
	MOV C, ACC.5		; |
	MOV P1.5, C			; |
	MOV C, ACC.4		; |
	MOV P1.4, C			; | high nibble set

	SETB P3.1			; |
	CLR P3.1			; | negative edge on E

	MOV C, ACC.3		; |
	MOV P1.7, C			; |
	MOV C, ACC.2		; |
	MOV P1.6, C			; |
	MOV C, ACC.1		; |
	MOV P1.5, C			; |
	MOV C, ACC.0		; |
	MOV P1.4, C			; | low nibble set

	SETB P3.1			; |
	CLR P3.1			; | negative edge on E

	CALL delay			; wait for BF to clear
	RET

delay:
	MOV R0, #50
	DJNZ R0, $
	RET


