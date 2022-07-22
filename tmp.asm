org 100h ; offset in the current segment

SCREEN_WIDTH    equ 320
SCREEN_HEIGHT   equ 200
SCREEN_PIXELS   equ SCREEN_WIDTH*SCREEN_HEIGHT
MAZE_COLS       equ 40
MAZE_ROWS       equ 25
CELL_SIZE       equ 8
DELAY           equ 50000 ; 0-65535
VISITED_COLOR   equ 0xa
DISCOVERED_COLOR equ 0xc

section .data
Visited         times MAZE_ROWS*MAZE_COLS db 0
Neighbors       dw -1, MAZE_COLS, 1, -MAZE_COLS

section .bss
Color           resb 1 ; pointer to variable Color in data section
Seed            resw 1
 
section .text
main:
    mov ax, 0xA000
    mov es, ax

    mov ax, 0x0013
    int 0x10

    mov ax, 0
    int 0x1a
    mov word [Seed], dx ; number of ticks since midnight is stored in cx:dx (we're just taking the lower 2 bytes here)

    mov byte [Color], 0xf   
    call ClearScreen

    mov byte [Color], 0x7 
    call DrawWalls

    push MAZE_ROWS*MAZE_COLS-MAZE_COLS-2    ; cell at (24;38)
    push MAZE_ROWS+1                        ; cell at (1;1)
    call MiniRNG ; pick a starting cell randomly from the interval [41;958]
    push ax
    call DrawMaze
    
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

; fills the inside of a cell with a solid color (set by the caller)
; cell top-left corner's x is at bp+6
; cell top-left corner's y is at bp+8
FillCell:
    push cx
    push bp
    mov bp, sp
    
    mov cx, CELL_SIZE-1
    Fill:
        inc word [bp+8]
        ; HLine(x+1, x+7, y)
        push word [bp+8] ; y
        mov ax, word [bp+6]
        add ax, 7
        push ax
        mov ax, word [bp+6]
        inc ax
        push ax
        call HLine
        loop Fill

    pop bp
    pop cx
    ret 4


; cell's linear offset is at bp+4
; DI <- x; SI <- y
GetScreenCoords:
    push bp
    mov bp, sp

    mov ax, [bp+4]
    mov dl, MAZE_COLS
    div dl

    xor dx, dx
    mov dl, ah
    mov di, dx
    mov dl, al
    mov si, dx

    mov ax, di
    mov dl, CELL_SIZE
    imul dl
    mov di, ax
    
    mov ax, si
    mov dl, CELL_SIZE
    imul dl
    mov si, ax

    pop bp
    ret 2


; start cell is at bp+4
DrawMaze:
    push bp
    mov bp, sp

    call VisitBorder

    push word [bp+4]
    call GetScreenCoords

    mov byte [Color], 0x9
    push si ; y
    push di ; x
    call FillCell

    mov byte [Color], 0xf
    push word [bp+4]
    call Walk

    pop bp
    ret 2


; linear index of current cell is at [bp+6]
Walk:
    push cx ; save caller's iteration number
    push bp
    mov bp, sp
    sub sp, 2 ; space for next neighbor's index

    ; visit the current cell
    mov bx, word [bp+6]
    mov byte [Visited + bx], 1

    ; get a random starting point for the scan of the neightbors' list
    push 3
    push 0
    call MiniRNG
    mov word [bp-2], ax

    ; each cell waits a few microsecond before visiting its neighbors
    mov ah, 0x86
    xor cx, cx
    mov dx, DELAY
    int 0x15

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
        push bx
        call GetScreenCoords

        mov byte [Color], DISCOVERED_COLOR
        push si ; y
        push di ; x
        call FillCell

        mov byte [Color], DISCOVERED_COLOR

        ; destroy the wall separating current cell and visited neighbor
        cmp word [bp-2], 0
        je DestroyRightWall     ; when visiting the western neighbor, destroy its eastern wall
        cmp word [bp-2], 1
        je DestroyTopWall       ; when visiting the southern neighbor, destroy its northern wall
        cmp word [bp-2], 2
        je DestroyLeftWall      ; when visiting the eastern neighbor, destroy its western wall
        cmp word [bp-2], 3
        je DestroyBottomWall    ; when visiting the northern neighbor, destory its southern wall

        ; cancel only the inner pixels so walls don't intersect
        ; this is achieved by increasing the lower limit and decreasing the upper limit
        DestroyLeftWall:
            ; VLine(x, y+1, y+7)
            mov ax, si
            add ax, 7
            push ax ; y2
            mov ax, si
            inc ax
            push ax ; y1
            push di ; x
            call VLine
            jmp Recurse
        DestroyBottomWall:
            ; HLine(x+1, x+7, y+8)
            add si, 8
            push si ; y
            mov ax, di
            add ax, 7
            push ax ; x2
            mov ax, di
            inc ax
            push ax ; x1
            call HLine
            jmp Recurse
        DestroyRightWall:
            ; VLine(x+8, y+1, y+7)
            mov ax, si
            add ax, 7
            push ax ; y2
            mov ax, si
            inc ax
            push ax ; y1
            add di, 8
            push di ; x
            call VLine
            jmp Recurse
        DestroyTopWall:
            ; HLine(x+1, x+7, y)
            push si ; y
            mov ax, di
            add ax, 7
            push ax ; x2
            mov ax, di
            inc ax
            push ax ; x1
            call HLine
            jmp Recurse

        Recurse:
            push bx
            call Walk

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
        jnz VisitNeighbors

    ; cell and all of its neighbors have been visited; mark accordingly
    push word [bp+6]
    call GetScreenCoords

    mov byte [Color], VISITED_COLOR
    push si ; y
    push di ; x
    call FillCell

    Exit:
        mov sp, bp
        pop bp
        pop cx ; restore caller's iteration number
        ret 2 ; you gotta clear the parameter (word) from the stack!


VisitBorder:
    push bp
    mov bp, sp

    xor bx, bx
    mov cx, MAZE_COLS

    VisitHorzBorder:
        mov byte [Visited + bx], 1
        mov byte [Visited + bx + MAZE_COLS*MAZE_ROWS-MAZE_COLS], 1
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


; min is at bp+4
; max is at bp+6
; generates a random number between min and max inclusive
MiniRNG:
    push bp
    mov bp, sp

    ; seed := time()
    ; seed ^= seed << 7
    ; seed ^= seed >> 9
    ; seed ^= seed << 8
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

    mov word [Seed], ax ; updatedSeed

    ; return min + updatedSeed % (max - min + 1)
    xor dx, dx
    mov cx, word [bp+6]
    sub cx, word [bp+4]
    inc cx
    div cx
    add dx, [bp+4]
    
    mov ax, dx
    pop bp
    ret 4


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



; x1 is at bp+14
; x2 is at bp+16
; y is at bp+18
; Color is set by the caller
HLine:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    mov bp, sp

    ; x2 < SCREEN_WIDTH
    cmp word [bp+16], SCREEN_WIDTH
    jge EndHLine
    ; x1 <= x2
    mov ax, word [bp+16]
    cmp word [bp+14], ax
    jg EndHLine
    ; 0 <= x1
    cmp word [bp+14], 0
    jl EndHLine
    ; 0 <= y < SCREEN_HEIGHT
    cmp word [bp+18], 0
    jl EndHLine
    cmp word [bp+18], SCREEN_HEIGHT
    jge EndHLine

    ; line start at offset := 320*y + x1
    mov ax, SCREEN_WIDTH
    imul word [bp+18]
    add ax, word [bp+14]
    mov bx, ax

    ; draw x2 - x1 + 1 pixels
    mov cx, word [bp+16]
    sub cx, word [bp+14]
    inc cx

    mov al, [Color]

    HLineLoop:
        mov [es:bx], al
        inc bx
        loop HLineLoop

    EndHLine:
        pop bp
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret 6



; x is at bp+14
; y1 is at bp+16
; y2 is at bp+18
; Color is set by the caller
VLine:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    mov bp, sp

    ; y2 < SCREEN_HEIGHT
    cmp word [bp+18], SCREEN_HEIGHT
    jge EndVLine
    ; y1 <= y2
    mov ax, word [bp+18]
    cmp word [bp+16], ax
    jg EndVLine
    ; 0 <= y1
    cmp word [bp+16], 0
    jl EndVLine
    ; 0 <= x < SCREEN_WIDTH
    cmp word [bp+14], 0
    jl EndVLine
    cmp word [bp+14], SCREEN_WIDTH
    jge EndVLine

    ; line start at offset := 320*y1 + x
    mov ax, SCREEN_WIDTH
    imul word [bp+16]
    add ax, word [bp+14]
    mov bx, ax

    ; draw y2 - y1 + 1 pixels
    mov cx, word [bp+18]
    sub cx, word [bp+16]
    inc cx

    mov al, [Color]

    VLineLoop:
        mov [es:bx], al
        add bx, SCREEN_WIDTH ; step between raster lines (320 bytes apart)
        loop VLineLoop

    EndVLine:
        pop bp
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret 6



; Color is set by the caller
DrawWalls:
    push bp
    mov bp, sp


    xor dx, dx
    mov cx, word MAZE_ROWS 
    RowLoop:
        push dx ; y
        push word SCREEN_WIDTH-1 ; x2
        push word 0 ; x1
        call HLine

        add dx, CELL_SIZE
        loop RowLoop


    xor dx, dx
    mov cx, word MAZE_COLS
    ColLoop:
        push word SCREEN_HEIGHT-1 ; y2
        push word 0; y1
        push dx; x
        call VLine

        add dx, CELL_SIZE
        loop ColLoop


    xor dx, dx
    mov cx, word CELL_SIZE
    DrawBorder:
        push dx ; y
        push SCREEN_WIDTH-1 ; x2
        push 0 ; x1
        call HLine

        mov ax, dx
        add ax, SCREEN_HEIGHT-CELL_SIZE
        push ax ; y
        push SCREEN_WIDTH-1 ; x2
        push 0 ; x1
        call HLine

        push SCREEN_HEIGHT-1 ; y2
        push 0 ; y1
        push dx ; x
        call VLine

        mov ax, dx
        add ax, SCREEN_WIDTH-CELL_SIZE
        push SCREEN_HEIGHT-1
        push 0
        push ax
        call VLine

        inc dx
        loop DrawBorder


    pop bp
    ret
