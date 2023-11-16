.EQU OUTPORT = PORTA ;PORT A hi?n th?
.EQU OUTPORT_DR = DDRA
.EQU SW=0 ;k? hi?u chân SW
.EQU SS=4 ;k? hi?u chân /SS
.EQU MOSI=5 ;k? hi?u chân MOSI
.EQU MISO=6 ;k? hi?u chân MISO
.EQU SCK=7 ;k? hi?u chân SCK
.ORG 0
RJMP MAIN
.org INT_VECTORS_SIZE
cnt0:
.db "Key:",0
MAIN: 
	call LCD_Init
	ldi ZH, high(cnt0) ; point to the information that is to be displayed
	ldi ZL, low(cnt0)
	call LCD_Send_String
	call USART_Init
	LDI R16,0XFF
	OUT OUTPORT_DR,R16;Port hi?n th? output
	LDI R16,0X00
	OUT OUTPORT,R16 ;xóa hi?n th?
	CBI DDRD,2
	LDI R16,(1<<SS)|(1<<SCK)|(1<<MOSI) ;khai báo các output SPI
	OUT DDRB,R16
	SBI PORTB,SS ;d?ng truy?n SPI
	LDI R16 ,(1<<SPE0)|(1<<MSTR0)|(1<<SPR00) ;SPI Master,SCK=Fosc/16,cho phép SPI l?y m?u c?nh lên ? c?nh trý?c,MSB truy?n trý?c
	OUT SPCR0,R16
START: 
	SBI PORTB,SS
	SBIS PIND,2
	RJMP START
	ldi r17,0xF0
	CBI PORTB,SS ;cho phép truy?n SPI
	RCALL SPI_TRANS ;truy?n SPI
	mov r16,r18
	call USART_SendChar
	call screen
	RJMP START ;l?p v?ng l?i t? ð?u
screen:
	ldi r16,0x84 //key
	call LCD_Send_Command
	mov r16,r18
	call LCD_SEND_DATA
;SPI_TRANS truy?n data SPI gi?a Master và Slaver
;Input: R17 ch?a data ghi ra Slaver
;Output: R18 ch?a data ð?c t? Slaver S? d?ng R16
SPI_TRANS:
	OUT SPDR0,R17 ;ghi data ra SPI
WAIT_SPI:
	IN R16,SPSR0 ;ð?c c? SPIF0
	SBRS R16,SPIF0 ;c? SPIF0=1 truy?n SPI xong
	RJMP WAIT_SPI ;ch? c? SPIF0=1
	IN R18,SPDR0 ;ð?c data t? SPI
	RET

LCD_Move_Cursor:
cpi r16,0 ;check if first row
brne LCD_Move_Cursor_Second
andi r17, 0x0F
ori r17,0x80
mov r16,r17
; Send command to LCD
call LCD_Send_Command
ret
LCD_Move_Cursor_Second:
cpi r16,1 ;check if second row
brne LCD_Move_Cursor_Exit ;else exit
andi r17, 0x0F
ori r17,0xC0
mov r16,r17
; Send command to LCD
call LCD_Send_Command
LCD_Move_Cursor_Exit:
; Return from function
ret
; Subroutine to send string to LCD
;address of the string on ZH-ZL
;string end with Null
.def LCDData = r16
LCD_Send_String:
push ZH ; preserve pointer registers
push ZL
push LCDData
; fix up the pointers for use with the 'lpm' instruction
lsl ZL ; shift the pointer one bit left for the lpm instruction
rol ZH
; write the string of characters
LCD_Send_String_01:
lpm LCDData, Z+ ; get a character
cpi LCDData, 0 ; check for end of string
breq LCD_Send_String_02 ; done
; arrive here if this is a valid character
call LCD_Send_Data ; display the character
rjmp LCD_Send_String_01 ; not done, send another character
; arrive here when all characters in the message have been sent to the LCD module
LCD_Send_String_02:
pop LCDData
pop ZL ; restore pointer registers
pop ZH
ret
; Subroutine to send command to LCD
;Command code in r16
;LCD_D7..LCD_D4 connect to PA7..PA4
;LCD_RS connect to PA0
;LCD_RW connect to PA1
;LCD_EN connect to PA2
LCD_Send_Command:
push r17
call LCD_wait_busy ; check if LCD is busy
mov r17,r16 ;save the command
; Set RS low to select command register
; Set RW low to write to LCD
andi r17,0xF0
; Send command to LCD
out LCDPORT, r17
nop
nop
; Pulse enable pin
sbi LCDPORT, LCD_EN
nop
nop
cbi LCDPORT, LCD_EN
swap r16
andi r16,0xF0
; Send command to LCD
out LCDPORT, r16
; Pulse enable pin
sbi LCDPORT, LCD_EN
nop
nop
cbi LCDPORT, LCD_EN
pop r17
ret
LCD_Send_Data:
push r17
call LCD_wait_busy ;check if LCD is busy
mov r17,r16 ;save the command
; Set RS high to select data register
; Set RW low to write to LCD
andi r17,0xF0
ori r17,0x01
; Send data to LCD
out LCDPORT, r17
nop
; Pulse enable pin
sbi LCDPORT, LCD_EN
nop
cbi LCDPORT, LCD_EN
; Delay for command execution
;send the lower nibble
nop
swap r16
andi r16,0xF0
; Set RS high to select data register
; Set RW low to write to LCD
andi r16,0xF0
ori r16,0x01
; Send command to LCD
out LCDPORT, r16
nop
; Pulse enable pin
sbi LCDPORT, LCD_EN
nop
cbi LCDPORT, LCD_EN
pop r17
ret
;init the LCD
;LCD_D7..LCD_D4 connect to PA7..PA4
;LCD_RS connect to PA0
;LCD_RW connect to PA1
;LCD_EN connect to PA2
.equ LCDPORT = PORTA ; Set signal port reg to PORTA
.equ LCDPORTDIR = DDRA ; Set signal port dir reg to PORTA
.equ LCDPORTPIN = PINA ; Set clear signal port pin reg to PORTA
.equ LCD_RS = PINA0
.equ LCD_RW = PINA1
.equ LCD_EN = PINA2
.equ LCD_D7 = PINA7
.equ LCD_D6 = PINA6
.equ LCD_D5 = PINA5
.equ LCD_D4 = PINA4
LCD_Init:
; Set up data direction register for Port A
ldi r16, 0b11110111 ; set PA7-PA4 as outputs, PA2-PA0 as output
out LCDPORTDIR, r16
; Wait for LCD to power up
call DELAY_10MS
call DELAY_10MS
; Send initialization sequence
ldi r16, 0x02 ; Function Set: 4-bit interface
call LCD_Send_Command
ldi r16, 0x28 ; Function Set: enable 5x7 mode for chars
call LCD_Send_Command
ldi r16, 0x0E ; Display Control: Display OFF, Cursor ON
call LCD_Send_Command
ldi r16, 0x01 ; Clear Display
call LCD_Send_Command
ldi r16, 0x80 ; Clear Display
call LCD_Send_Command
ret
LCD_wait_busy:
push r16
ldi r16, 0b00000111 ; set PA7-PA4 as input, PA2-PA0 as output
out LCDPORTDIR, r16
ldi r16,0b11110010 ; set RS=0, RW=1 for read the busy flag
out LCDPORT, r16
nop
LCD_wait_busy_loop:
sbi LCDPORT, LCD_EN
nop
nop
in r16, LCDPORTPIN
cbi LCDPORT, LCD_EN
nop
sbi LCDPORT, LCD_EN
nop
nop
cbi LCDPORT, LCD_EN
nop
andi r16,0x80
cpi r16,0x80
breq LCD_wait_busy_loop
ldi r16, 0b11110111 ; set PA7-PA4 as output, PA2-PA0 as output
out LCDPORTDIR, r16
ldi r16,0b00000000 ; set RS=0, RW=1 for read the busy flag
out LCDPORT, r16
pop r16
ret

;init UART 0 
;CPU clock is 1Mhz 
USART_Init: 
; Set baud rate to 9600 bps with 1 MHz clock 
ldi r16, 103
sts UBRR0L, r16 
;set double speed 
ldi r16, (1 << U2X0) 
sts UCSR0A, r16 
; Set frame format: 8 data bits, no parity, 1 stop bit 
ldi r16, (1 << UCSZ01) | (1 << UCSZ00) 
sts UCSR0C, r16 
; Enable transmitter and receiver 
ldi r16, (1 << RXEN0) | (1 << TXEN0) 
sts UCSR0B, r16 
ret 
;send out 1 byte in r16 
USART_SendChar: 
push r17 
; Wait for the transmitter to be ready 
USART_SendChar_Wait: 
lds r17, UCSR0A 
sbrs r17, UDRE0 ;check USART Data Register Empty bit 
rjmp USART_SendChar_Wait 
add r16,r29
sts UDR0, r16 ;send out 
pop r17 
ret 
;receive 1 byte in r16 
USART_ReceiveChar: 
push r17 
; Wait for the transmitter to be ready 
USART_ReceiveChar_Wait: 
lds r17, UCSR0A 
sbrs r17, RXC0 ;check USART Receive Complete bit 
rjmp USART_ReceiveChar_Wait 
lds r16, UDR0 ;get data 
pop r17 
ret 

DELAY_10MS:
LDI R21,80 ;1MC
L1: LDI R20,250 ;1MC
L2: DEC R20 ;1MC
NOP ;1MC
BRNE L2 ;2/1MC
DEC R21 ;1MC
BRNE L1 ;2/1MC
RET ;4MC
