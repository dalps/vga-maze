org 100h ; code offset in the current segment
global main

SCREEN_WIDTH    equ 320
SCREEN_HEIGHT   equ 200
SCREEN_PIXELS   equ SCREEN_WIDTH*SCREEN_HEIGHT
CELL_SIZE       equ 8
MAZE_COLS       equ SCREEN_WIDTH/CELL_SIZE
MAZE_ROWS       equ SCREEN_HEIGHT/CELL_SIZE
WALK_DELAY      equ 5000 ; time to wait between visits; can range from 0 to65535

START_COLOR         equ 0x36
WALL_COLOR          equ 0x08
BORDER_COLOR        equ 0x08
BACKGROUND_COLOR    equ 0x0f
VISITED_COLOR       equ 0x42
DISCOVERED_COLOR    equ 0x1e

section .data
Visited         times MAZE_ROWS*MAZE_COLS db 0 ; keeps track of visited cells
Neighbors       dw -1, MAZE_COLS, 1, -MAZE_COLS ; cardinal directions offsets; WEST, SOUTH, EAST, NORTH respectively

section .bss
Color           resb 1 ; each pixel is a byte representing the displayed color
Seed            resw 1

 
section .text
main:
    ; load ES with the video screen segment's base address
    mov ax, 0xA000
    mov es, ax

    ; enter video mode (AH = 0) in graphical mode (AL = 0x13)
    mov ax, 0x0013
    int 0x10

    ; get system time (AH = 0) to initialize the RNG state
    xor ax, ax
    int 0x1a            ; BIOS stores number of ticks since midnight in CX:DX
    mov word [Seed], dx ; the lower two bytes will suffice

    Restart:
        ; flood the screen with a solid color, then draw a grid pattern
        mov byte [Color], BACKGROUND_COLOR   
        call FillScreen
        call DrawWalls

        ; pick a random cell from where to begin walking the pattern
        push MAZE_ROWS*MAZE_COLS-MAZE_COLS-2    ; cell at (24;38)
        push MAZE_ROWS+1                        ; cell at (1;1)
        call MiniRNG 
        push ax
        call DrawMaze
     
    GetChar:
        ; read a keystroke from the keyboard (AH = 0x0)
        xor ax, ax
        int 16h ; BIOS stores ASCII character in AL; waits if buffer is empty
        
        ; q / Q: quit the program
        ; r / R: run the generator again
        cmp al, 'q'
        je ResetMode
        cmp al, 'Q'
        je ResetMode
        cmp al, 'r'
        je Restart
        cmp al, 'R'
        je Restart
        jmp GetChar ; consume another character from the keyboard buffer if none matches

    ResetMode:
        ; set the video mode back to text mode (AL = 0x03)
        mov ax, 0x0003
        int 0x10

    ret


; ----------------------------------------------------------------------------------------------------------------------
; Fills the inside of a maze cell of coordinates (x,y) with a solid color.
; Caller may specify the desired color in the global variable Color.
;
; Stack at start of useful work:
;           y           BP+8 (cell's row number)
;           x           BP+6 (cell's column number)
;           RET ADDR    BP+4
;           CX          BP+2 (caller's iteration counter)
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
FillCell:
    push cx
    push bp
    mov bp, sp
    
    mov cx, CELL_SIZE-1
    Fill:
        ; HLine(x+1, x+7, y+1)
        inc word [bp+8]
        push word [bp+8]
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


; ----------------------------------------------------------------------------------------------------------------------
; Get the screen coordinates (x,y) of a maze cell's top-left corner from its offset in the maze array. This is done by
; obtaining the cell coordinates from the equation cell_offset = cell_y*MAZE_COLS + cell_x and then scaling them down by
; a factor of the square cell size.
; Returns x in DI and y in SI.
;
; Stack at start of useful work:
;           cell_offset BP+4 (cell's linear offset; can be any value in [0;MAZE_ROWS*MAZE_COLS])
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
GetScreenCoords:
    push bp
    mov bp, sp

    ; convert the linear offset to cell coordinates
    ; cell_x := cell_offset % MAZE_COLS
    ; cell_y := cell_offset / MAZE_COLS 
    mov ax, [bp+4]
    mov dl, MAZE_COLS
    div dl

    ; DI <- cell_x
    ; SI <- cell_y
    xor dx, dx
    mov dl, ah
    mov di, dx
    mov dl, al
    mov si, dx

    ; convert cell coordinates to screen coordinates
    ; DI <- DI*CELL_SIZE
    ; SI <- SI*CELL_SIZE
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


; ----------------------------------------------------------------------------------------------------------------------
; Explores the grid of cells using randomized Depth First Search. The function accepts the starting cell in the form of
; its linear offset in the maze grid (that is, if the starting cell is identified by the couple (x,y), its linear offset
; is y*40 + x, where y lies in [0;MAZE_ROWS] and x lies in [0;MAZE_COLS]). The starting cell is colored START_COLOR.
;
; Stack at start of useful work:
;           start_cell  BP+4 (cell's linear offset; can be any value in [0;MAZE_ROWS*MAZE_COLS])
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
DrawMaze:
    push bp
    mov bp, sp

    ; set Visited array so border cells cant be walked on
    call VisitBorder

    ; color-in the starting cell
    push word [bp+4]
    call GetScreenCoords

    mov byte [Color], START_COLOR
    push si ; y
    push di ; x
    call FillCell

    mov byte [Color], WALL_COLOR
    push word [bp+4]
    call Walk

    ; recolor the starting cell as it's been covered up by the previous call
    mov byte [Color], START_COLOR
    push si ; y
    push di ; x
    call FillCell

    pop bp
    ret 2


; ----------------------------------------------------------------------------------------------------------------------
; Visits the cell given as parameter and discovers all paths that can be walked from it recursively. Each neighbor that
; is visited from the parameter is colored DISCOVERED_COLOR and the  wall that separates them is colored VISITED_COLOR.
; Dead-ends (cells whose neighbors have all been visited) are colored VISITED_COLOR. Delay has been implemented between 
; visits to animate the search progression.
;
; Stack at start of useful work:
;           visitee     BP+6 (cell's linear offset; can be any value in [0;MAZE_ROWS*MAZE_COLS])
;           RET ADDR    BP+4
;           CX          BP+2
;           BP          BP+0
; SP -->    neighbor_id BP-2
; ----------------------------------------------------------------------------------------------------------------------
Walk:
    push cx ; save caller's iteration number
    push bp
    mov bp, sp
    sub sp, 2 ; make space for next neighbor's index

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
    mov dx, WALK_DELAY
    int 0x15

    mov cx, 4

    VisitNeighbors:
        ; compute the linear offset of the neighbor's cell
        mov bx, word [bp-2]
        add bx, bx
        mov ax, word [bp+6]
        add ax, word [Neighbors + bx]
        mov bx, ax

        cmp byte [Visited + bx], 1
        je Continue ; neighbor has already been visited and must be skipped

        ; get the coordinates of the neighbor's cell top-left corner
        push bx
        call GetScreenCoords

        mov byte [Color], DISCOVERED_COLOR
        push si ; y
        push di ; x
        call FillCell

        mov byte [Color], VISITED_COLOR ; wall's color blends in with visited cells
        ; destroy the wall separating current cell and the visited neighbor
        cmp word [bp-2], 0
        je DestroyRightWall     ; when visiting the western neighbor, destroy its eastern wall
        cmp word [bp-2], 1
        je DestroyTopWall       ; when visiting the southern neighbor, destroy its northern wall
        cmp word [bp-2], 2
        je DestroyLeftWall      ; when visiting the eastern neighbor, destroy its western wall
        cmp word [bp-2], 3
        je DestroyBottomWall    ; when visiting the northern neighbor, destory its southern wall

        ; cancel only the inner pixels so walls don't intersect
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
        ; next <- (next+1) % 4
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
        ret 2


; ----------------------------------------------------------------------------------------------------------------------
; Initializes the visit array to zero and marks the cells at the screen border as visited to prevent the walking
; algorithm going past the screen boundary .
;
; Stack at start of useful work:
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
VisitBorder:
    push bp
    mov bp, sp

    ; set all cells to unvisited
    xor bx, bx
    mov cx, MAZE_COLS*MAZE_ROWS

    SetZero:
        mov byte [Visited + bx], 0
        inc bx
        loop SetZero

    ; mark cells at top and bottom border as visited
    xor bx, bx
    mov cx, MAZE_COLS

    VisitHorzBorder:
        mov byte [Visited + bx], 1
        mov byte [Visited + bx + MAZE_COLS*MAZE_ROWS-MAZE_COLS], 1
        inc bx
        loop VisitHorzBorder

    ; mark cells at left and right border as visited
    xor bx, bx
    mov cx, MAZE_ROWS

    VisitVertBorder:
        mov byte [Visited + bx-1], 1
        mov byte [Visited + bx], 1
        add bx, MAZE_COLS
        loop VisitVertBorder

    pop bp
    ret


; ----------------------------------------------------------------------------------------------------------------------
; Generate a random number on the interval [min;max] using a simple xor-shift generator.
; Algorithm source: http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html
;
; Stack at start of useful work:
;           max         BP+6
;           min         BP+4
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
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


; ----------------------------------------------------------------------------------------------------------------------
; Floods the entire screen with a single color specified in the global variable Color.
;
; Stack at start of useful work:
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
FillScreen:
    push bp
    mov bp, sp

    mov cx, SCREEN_PIXELS
    xor bx, bx
    mov al, [Color]

    FillScreenLoop:
        mov [es:bx], al
        inc bx
        loop FillScreenLoop

    pop bp
    ret


; ----------------------------------------------------------------------------------------------------------------------
; Draws a horizontal line connecting the ends x1 and x2 within the raster row y. Color is specified by the caller.
;
; Stack at start of useful work:
;           y           BP+18 (raster row)
;           x2          BP+16 (x coordinate of the right end of the line)
;           x1          BP+14 (x coordinate of the left end of the line)
;           RET ADDR    BP+12
;           AX          BP+10
;           BX          BP+8
;           CX          BP+6
;           DX          BP+4
;           DI          BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
HLine:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    mov bp, sp

    ; validate the coordinates
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

    ; line starts at offset 320*y + x1
    mov ax, SCREEN_WIDTH
    imul word [bp+18]
    add ax, word [bp+14]
    mov bx, ax

    ; set the next x2 - x1 + 1 pixels
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


; ----------------------------------------------------------------------------------------------------------------------
; Draws a vertical line connecting the ends y1 and y2 within the raster column x. Color is specified by the caller.
;
; Stack at start of useful work:
;           y2          BP+18 (y coordinate of the higher end of the line)
;           y1          BP+16 (y coordinate of the lower end of the line)
;           x           BP+14 (raster column)
;           RET ADDR    BP+12
;           AX          BP+10
;           BX          BP+8
;           CX          BP+6
;           DX          BP+4
;           DI          BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
VLine:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    mov bp, sp

    ; validate the coordinates
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

    ; line starts at offset 320*y1 + x
    mov ax, SCREEN_WIDTH
    imul word [bp+16]
    add ax, word [bp+14]
    mov bx, ax

    ; set the next y2 - y1 + 1 pixels
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



; ----------------------------------------------------------------------------------------------------------------------
; Draws a grid pattern of MAZE_COLS*MAZE_ROWS square cells of side CELL_SIZE representing the labyrinth's walls.
; Walls (a cell's sides) are one-pixel-thick vertical and horizontal lines sharing the color specified in the WALL_COLOR
; constant. Cells at the border of the screen are filled with the color specified in the BORDER_COLOR constant.
;
; Stack at start of useful work:
;           RET ADDR    BP+2
; SP -->    BP          BP+0
; ----------------------------------------------------------------------------------------------------------------------
DrawWalls:
    push bp
    mov bp, sp

    mov byte [Color], WALL_COLOR

    ; draw MAZE_ROWS rows of length SCREEN_WIDTH spaced CELL_SIZE pixels each
    xor dx, dx
    mov cx, word MAZE_ROWS
    RowLoop:
        push dx ; y
        push word SCREEN_WIDTH-1 ; x2
        push word 0 ; x1
        call HLine

        add dx, CELL_SIZE
        loop RowLoop

    ; draw MAZE_COLS columns of length SCREEN_HEIGHT spaced CELL_SIZE pixels each
    xor dx, dx
    mov cx, word MAZE_COLS
    ColLoop:
        push word SCREEN_HEIGHT-1 ; y2
        push word 0; y1
        push dx ; x
        call VLine

        add dx, CELL_SIZE
        loop ColLoop


    mov byte [Color], BORDER_COLOR

    ; fill in the border cells with a single color by drawing 8 adjacent columns/rows for each side
    xor dx, dx
    mov cx, word CELL_SIZE
    FillBorder:
        ; top rows
        push dx ; y
        push SCREEN_WIDTH-1 ; x2
        push 0 ; x1
        call HLine

        ; bottom rows
        mov ax, dx
        add ax, SCREEN_HEIGHT-CELL_SIZE
        push ax ; y
        push SCREEN_WIDTH-1 ; x2
        push 0 ; x1
        call HLine

        ; left columns
        push SCREEN_HEIGHT-1 ; y2
        push 0 ; y1
        push dx ; x
        call VLine

        ; right columns
        mov ax, dx
        add ax, SCREEN_WIDTH-CELL_SIZE
        push SCREEN_HEIGHT-1
        push 0
        push ax
        call VLine

        inc dx
        loop FillBorder

    pop bp
    ret
