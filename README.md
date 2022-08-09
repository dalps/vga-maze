# vga-maze

A pseudorandom maze generator for MS-DOS featuring ground-breaking VGA graphics. Written in 80x86 real mode assembly.

This is a simple implementation of the randomized DFS algorithm for exploring a graph. Watch the algorithm as it makes way through the walls of a square grid and backtracks all the way back along the visited cells until the initial cell is reached. 

---

## Installation

An 80x86 assembler and MS-DOS machine with VGA graphics support are required to assemble and run the program, which lives in the single source file vgamaze.asm.
[NASM](https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/dos/) for [DOS(Box)](https://www.dosbox.com/download.php?main=1) is a clean solution to emulate such an architecture.

Mount the folder with the assembler executables (make sure it includes nasm.exe and cwsdpmi.exe) on the emulator. To assemble and run the source file:

`C:\> nasm vgamaze.asm -fbin -o vgamaze.com`

`C:\> vgamaze`

---

## Usage & Parameters

Just watch as the algorithm walks the grid in a depth first, randomized fashion. You'll know the generation animation is complete once all the visited cells are filled with a solid color. Then, you can run the generator again by pressing R or exit the program with Q.

The parameters of the gerenator are hardcoded - for now - in the assembly code. The maze's dimensions are parametric to the cell size, which should divide both the screen's width and height (in mode 13h these are 320 and 200 pixels respectively). A maze cell comprises a square of pixels whose side is defined by the CELL_SIZE constant.

---

## Gallery

Play with the cell size and the colors to get fun results!

![vgamaze_006](https://user-images.githubusercontent.com/96267363/183630366-258361ab-7b62-49de-a8b5-b0aee8711c80.png)
![vgamaze_004](https://user-images.githubusercontent.com/96267363/183630374-22349120-1307-42b7-9d90-189df7511fc7.png)
![tmp_045](https://user-images.githubusercontent.com/96267363/183630516-c3d1e705-5b6d-449d-bc0d-769071a804ee.png)
![tmp_047](https://user-images.githubusercontent.com/96267363/183630423-74615960-f93f-4b3d-9359-59c9a4038bff.png)

---

## TODO

- Menu for cell size and palette selection;
- Iterative DFS (should fix stack overflowing when cell size is very small)
- Function arguments can be passed through registers for optimization purposes
