org 100h ; offset in the current segment

section .data
SCREEN_WIDTH    equ 320
SCREEN_HEIGHT   equ 200
SCREEN_PIXELS   equ SCREEN_WIDTH*SCREEN_HEIGHT
MAZE_COLS       equ 40
MAZE_ROWS       equ 25
CELL_SIZE       equ 8

section .data
Visited         times 1000 db 0
Neighbors       dw -1, 40, 1, -40 ; needs to be a list of initalizers!

section .bss
Color           resb 1 ; pointer to variable Color in data section
Seed            resw 1
 
section .text
main:
    mov ax, 0x0013
    int 0x10

    xor ax, ax
    int 0x1a
    ; number of ticks since midnight is stored in cx:dx (we're just taking the lower 2 bytes here)
    mov word [Seed], dx

    mov ax, 0xA000
    mov es, ax
    
    mov byte [Color], 0xf   
    call ClearScreen

    mov word [Color], 0x7
    call DrawGrid

    call VisitBorder

    push 41
    call DFS

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

; ---------------------------------------------------------------------------------------------------------------------
; Procedures
;

; linear index of current cell is at [bp+4]
DFS:
    push cx ; save caller's iteration number
    push bp
    mov bp, sp

    sub sp, 2 ; space for next neighbor's index

    mov byte [Color], 0xf
    push 8
    push 7
    push 1
    call HLine

    ; visit the current cell
    mov bx, word [bp+6]
    mov byte [Visited + bx], 1

    ; get a random starting point for the scan of the neightbors' list
    call MiniRNG
    mov word [bp-2], ax

    mov cx, 4

VisitNeighbors:
    ; compute the linear offset of the neighbor
    mov bx, word [bp-2]
    add bx, bx
    mov ax, word [bp+6]
    add ax, word [Neighbors + bx]
    mov bx, ax

    cmp byte [Visited + bx], 1
    je Continue ; neighbor has been visited and must be skipped

    ; get the coordinates of the neighbor's cell top-left corner
    mov ax, bx
    mov dl, MAZE_COLS
    div dl ; neighbor_x := AH; neighbor_y := AL

    ; convert to screen coordinates: vga_x := neighbor_x*8; vga_y := neighbor_y*8
    xor dx, dx
    mov dl, ah
    mov di, dx ; save neighbor_x
    mov dl, al
    mov si, dx ; save neighbor_y

    mov ax, di
    mov dl, CELL_SIZE
    imul dl
    mov di, ax
    
    mov ax, si
    mov dl, CELL_SIZE
    imul dl
    mov si, ax

    ; destroy the wall separating current cell and visited neighbor
    cmp word [bp-2], 0
    je DestroyLeftWall
    cmp word [bp-2], 1
    je DestroyBottomWall
    cmp word [bp-2], 2
    je DestroyRightWall
    cmp word [bp-2], 3
    je DestroyTopWall

    mov byte [Color], 0xf

DestroyLeftWall:
    ; VLine(x, y1, y1+8)
    push cx
    push bx
    add si, 8
    push si
    push si
    push di
    call VLine
    pop bx
    pop cx
    jmp Recursion
DestroyBottomWall:
    ; HLine(x, x+8, y+8)
    push cx
    push bx
    push si
    add si, 8
    push si
    add di, 8
    push di
    call HLine
    pop bx
    pop cx
    jmp Recursion
DestroyRightWall:
    ; VLine(x+8, y, y+8)
    push cx
    push bx
    add si, 8
    push si
    push si
    add di, 8
    push di
    call VLine
    pop bx
    pop cx
    jmp Recursion
DestroyTopWall:
    ; HLine(x, x+8, y)
    push cx
    push bx
    push si
    add di, 8
    push di
    push di
    call HLine
    pop bx
    pop cx
    jmp Recursion

Recursion:
    push bx
    call DFS

Continue:
    ; next <- (next + 1) % 4
    mov ax, word [bp-2]
    inc ax
    mov dl, 4
    div dl
    mov al, ah
    mov ah, 0
    mov word [bp-2], ax

    dec cx
    cmp cx, 0
    je VisitNeighbors

    mov sp, bp
    pop bp
    pop cx ; restore caller's iteration number
    ret 2 ; you gotta clear the parameter from the stack!


VisitBorder:
    push bp
    mov bp, sp

    xor bx, bx
    mov cx, MAZE_COLS

VisitHorzBorder:
    mov byte [Visited + bx], 1
    mov byte [Visited + bx + MAZE_COLS*MAZE_ROWS-MAZE_COLS], 1 ; wasted a lot of time cause i subtracted rows instead of columns, thus writing out of bounds
    inc bx
    loop VisitHorzBorder

    xor bx, bx
    mov cx, MAZE_ROWS

VisitVertBorder:
    mov byte [Visited + bx-1], 1
    mov byte [Visited + bx], 1
    add bx, MAZE_COLS
    loop VisitVertBorder

    pop bp
    ret


; generates a random number between 0 and 3 inclusive
MiniRNG:
    push bp
    mov bp, sp

    mov ax, word [Seed]
    mov dx, ax
    shl ax, 7
    xor dx, ax
    mov ax, dx
    shr ax, 9
    xor dx, ax
    mov ax, dx
    shl ax, 8
    xor dx, ax
    mov ax, dx

    mov word [Seed], ax
    and ax, 3
    
    pop bp
    ret


; Color is set by the caller
ClearScreen:
    push bp
    mov bp, sp

    mov cx, SCREEN_PIXELS
    xor bx, bx
    mov al, [Color]

ClearScreenLoop:
    mov [es:bx], al
    inc bx

    loop ClearScreenLoop

    pop bp
    ret


; x is at bp+4
; y is at bp+6
; Color is set by the caller
SetPixel:
    push bp
    mov bp, sp

    ; check if parameters are legal offsets
    cmp word [bp+4], 0
    jl EndSetPixel
    cmp word [bp+4], SCREEN_WIDTH
    jge EndSetPixel
    cmp word [bp+6], 0
    jl EndSetPixel
    cmp word [bp+6], SCREEN_HEIGHT
    jge EndSetPixel

    ; offset := 320*y + x
    mov ax, SCREEN_WIDTH
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
    cmp word [bp+6], SCREEN_WIDTH
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
    cmp word [bp+8], SCREEN_HEIGHT
    jge EndHLine

    ; line start at offset := 320*y + x1
    mov ax, SCREEN_WIDTH
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
    cmp word [bp+8], SCREEN_HEIGHT
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
    cmp word [bp+4], SCREEN_WIDTH ; YOU LEFT 200 IDIOT! DON'T COPY PASTE!!! WASTED SLEEP BECAUSE OF THIS
    jge EndVLine

    ; line start at offset := 320*y1 + x
    mov ax, SCREEN_WIDTH
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
    add bx, SCREEN_WIDTH ; step between raster lines (320 bytes apart)
    loop VLineLoop

EndVLine:
    pop bp
    ret 6


; Color is set by the caller
DrawGrid:
    push bp
    mov bp, sp

    xor dx, dx
    mov cx, word MAZE_ROWS 

RowLoop:
    push cx ; we're saving registers in the caller's frame here (HLine overrides them)
    push dx
    push dx ; y
    push word SCREEN_WIDTH-1 ; x2
    push word 0 ; x1
    call HLine

    pop dx
    add dx, CELL_SIZE
    pop cx

    loop RowLoop

    xor dx, dx
    mov cx, word MAZE_COLS

ColLoop:
    push cx
    push dx
    push word SCREEN_HEIGHT-1 ; y2
    push word 0; y1
    push dx; x
    call VLine

    pop dx
    add dx, CELL_SIZE
    pop cx

    loop ColLoop

    pop bp
    ret