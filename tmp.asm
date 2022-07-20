global SetPixel

section .bss
Color   resb 1 ; pointer to variable Color in data section

section .text
main:
    mov ax, 0x0013
    int 0x10

    mov cx, 64000
    mov ax, 0xA000
    mov es, ax
    xor bx, bx
    mov byte [Color], 0x1

ClearScreen:
    mov al, [Color]
    mov [es:bx], al
    inc bx

    loop ClearScreen

    push word 20
    push word 32
    mov byte [Color], 0x1
    call SetPixel

    push word 20
    push word 33
    mov byte [Color], 0xe
    call SetPixel

    push word 20
    push word 31
    mov byte [Color], 0xe
    call SetPixel

    push word 19
    push word 32
    mov byte [Color], 0xe
    call SetPixel

    push word 21
    push word 32
    mov byte [Color], 0xe
    call SetPixel

getKeyStroke:
    xor ax, ax
    int 16h ; read a keystroke, ASCII char is stored in AL

    cmp al, 0x71 ; 'q'
    je exitVideoMode
    cmp al, 0x51 ; 'Q'
    je exitVideoMode

    jmp getKeyStroke

exitVideoMode:
    mov ax, 0x0003
    int 0x10
    ret ; setting the mode is not enough, you gotta return to the shell!

; x is at bp+4
; y is at bp+6
SetPixel:
    push bp
    mov bp, sp

    ; check if parameters are legal offsets
    cmp word [bp+4], 0
    jl EndSetPixel
    cmp word [bp+4], 320
    jge EndSetPixel
    cmp word [bp+6], 0
    jl EndSetPixel
    cmp word [bp+6], 200
    jge EndSetPixel

    ; offset := 320*y + x
    mov ax, 320
    imul word [bp+6]
    add ax, word [bp+4]
    mov bx, ax

    mov al, [Color]
    mov [es:bx], al

EndSetPixel:
    pop bp
    ret 4