Color:  equ 0x2

section .text
    mov ax, 0x0013
    int 0x10

    mov cx, 64000
    mov ax, 0xA000
    mov es, ax
    xor bx, bx

ClearScreen:
    mov al, Color
    mov es:[bx], al ; why does es:[bx] work while [es:bx] doesn't?
    inc bx

    loop ClearScreen

