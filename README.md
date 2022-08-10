# vga-maze

A pseudorandom maze generator for MS-DOS written in 80x86 real mode assembly and featuring ground-breaking mode 13h VGA graphics.

This is a simple, recursive implementation of a randomized depth-first traversal algorithm of a connected graph here encoded as an array of maze cells for the purpose [maze generation](https://en.wikipedia.org/wiki/Maze_generation_algorithm#Randomized_depth-first_search). The program provides a step-by-step visualization of the algorithm as it makes way through the walls of a square grid pattern and backtracks along the visited paths until the initial cell is reached. 


## Installation

An 80x86 assembler and MS-DOS machine with VGA graphics support are required to assemble and run the program, which lives in the single source file `vgamaze.asm`.
[NASM](https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/dos/) for [DOSBox](https://www.dosbox.com/download.php?main=1) is a clean solution to emulate such an architecture.

Mount the folder with the assembler executables (make sure it includes `nasm.exe` and `cwsdpmi.exe`) on the emulator. To assemble and run the source file:

`C:\> nasm vgamaze.asm -fbin -o vgamaze.com`

`C:\> vgamaze`


## Usage

Just watch as the algorithm walks the grid in a depth first, randomized fashion. You'll know the generation animation is complete once all the visited cells are filled with a solid color. Then, you can run the generator again by pressing R or exit the program with Q.

The parameters of the gerenator are hardcoded - for now - in the assembly code. The maze's dimensions are parametric to the cell size, which should divide both the screen's width and height (in mode 13h these are 320 and 200 pixels respectively). A maze cell comprises a square of pixels whose side is defined by the `CELL_SIZE` constant.

Shrink or enlarge the maze output by playing with the `CELL_SIZE` constant (beware of values less than 4 as they lead to stack overflow). Adjust the color constants to your liking using a subset of values drawn from the [VGA standard palette](https://www.fountainware.com/EXPL/vga_color_palettes.htm).

## Gallery

The generator in action.

![Animation](https://user-images.githubusercontent.com/96267363/183705523-bb96a507-d130-4b4b-b025-99479b608deb.gif)

Have fun adjusting the cell size and color palette to your liking.

![vgamaze_006](https://user-images.githubusercontent.com/96267363/183630366-258361ab-7b62-49de-a8b5-b0aee8711c80.png)

![tmp_045](https://user-images.githubusercontent.com/96267363/183630516-c3d1e705-5b6d-449d-bc0d-769071a804ee.png)

![tmp_047](https://user-images.githubusercontent.com/96267363/183630423-74615960-f93f-4b3d-9359-59c9a4038bff.png)

## Notes

`vga-maze` was realized in the context of a low-level computing course over at my Uni.

Further improvements to the code include:
- assembly optimization
- user menu offering customization options
- an iterative implementation of the search
