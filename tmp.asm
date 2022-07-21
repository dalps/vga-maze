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
    mov byte [Color], 0xf
    mov al, [Color]

ClearScreen:
    mov [es:bx], al
    inc bx

    loop ClearScreen

    mov word [Color], 0x7
    call DrawGrid 

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
; Color is set by the caller
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


; x1 is at bp+4
; x2 is at bp+6
; y is at bp+8
; Color is set by the caller
HLine:
    push bp
    mov bp, sp

    ; x2 < SCREEN_WIDTH
    cmp word [bp+6], 320
    jge EndHLine
    ; x1 <= x2
    mov ax, word [bp+6]
    cmp word [bp+4], ax
    jg EndHLine
    ; 0 <= x1
    cmp word [bp+4], 0
    jl EndHLine
    ; 0 <= y < SCREEN_HEIGHT
    cmp word [bp+8], 0
    jl EndHLine
    cmp word [bp+8], 200
    jge EndHLine

    ; line start at offset := 320*y + x1
    mov ax, 320
    imul word [bp+8]
    add ax, word [bp+4]
    mov bx, ax

    ; draw x2 - x1 + 1 pixels
    mov cx, word [bp+6]
    sub cx, word [bp+4]
    inc cx

    mov al, [Color]

HLineLoop:
    mov [es:bx], al
    inc bx
    loop HLineLoop

EndHLine:
    pop bp
    ret 6


; x is at bp+4
; y1 is at bp+6
; y2 is at bp+8
; Color is set by the caller
VLine:
    push bp
    mov bp, sp

    ; y2 < SCREEN_HEIGHT
    cmp word [bp+8], 200
    jge EndVLine
    ; y1 <= y2
    mov ax, word [bp+8]
    cmp word [bp+6], ax
    jg EndVLine
    ; 0 <= y1
    cmp word [bp+6], 0
    jl EndVLine
    ; 0 <= x < SCREEN_WIDTH
    cmp word [bp+4], 0
    jl EndVLine
    cmp word [bp+4], 320 ; YOU LEFT 200 IDIOT! DON'T COPY PASTE!!! WASTED SLEEP BECAUSE OF THIS
    jge EndVLine

    ; line start at offset := 320*y1 + x
    mov ax, 320
    imul word [bp+6]
    add ax, word [bp+4]
    mov bx, ax

    ; draw y2 - y1 + 1 pixels
    mov cx, word [bp+8]
    sub cx, word [bp+6]
    inc cx

    mov al, [Color]

VLineLoop:
    mov [es:bx], al
    add bx, 320 ; step between raster lines (320 bytes apart)
    loop VLineLoop

EndVLine:
    pop bp
    ret 6


; Color is set by the caller
DrawGrid:
    push bp
    mov bp, sp

    xor dx, dx
    mov cx, word 25 

RowLoop:
    push cx
    push dx
    push dx ; y
    push word 319; x2
    push word 0; x1
    call HLine

    pop dx
    add dx, 8
    pop cx

    loop RowLoop

    xor dx, dx
    mov cx, word 40

ColLoop:
    push cx
    push dx
    push word 199 ; y2
    push word 0; y1
    push dx; x
    call VLine

    pop dx
    add dx, 8
    pop cx

    loop ColLoop

    pop bp
    ret