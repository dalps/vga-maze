# vga-maze
A pseudorandom maze generator for 16-bit architectures featuring ground-breaking VGA graphics.
This is a simple implementation of the randomized DFS algorithm for exploring a graph. Watch the algorithm as it makes way through the walls of a square grid and backtracks all the way back the visited cells until the initial cell is reached. 
---
## Assemble
NASM for [DOS(Box)](https://www.dosbox.com/download.php?main=1) is required. Download it [here](https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/dos/). 
Mount the folder with the assembler executables (make sure it includes at list nasm.exe and cwsdpmi.exe) on the emulator, then assemble the source code with
`nasm vgamaze.asm -fbin -o vgamaze.com`
Run the generator
`vgamaze`
---
## Parameters
The parameters of the gerenator are hardcoded - for now - in the assembly code. The maze's dimensions are parametric to the cell size, which should divide both the screen's width and height (in mode 13h these are 320 and 200 pixels respectively). A maze cell comprises a square of pixels whose side is defined by the CELL_SIZE constant.
---
## Gallery
Play with the cell size and the colors to get fun results!
![tmp_048](https://user-images.githubusercontent.com/96267363/181917816-bf2c156b-5437-42c5-9351-8d2979fa64bc.png)
![tmp_045](https://user-images.githubusercontent.com/96267363/181917833-787e5d7e-f3cf-4710-b624-93eac60e3c2c.png)
![vgamaze_008](https://user-images.githubusercontent.com/96267363/183624702-ed24eaa9-4394-4cba-b514-dd4425eadfed.png)
![vgamaze_009](https://user-images.githubusercontent.com/96267363/183624864-43e2bf6e-dc08-4cb8-9c73-75e3f6bd5e9c.png)
---
## TODO
- Menu for cell size and palette selection;
- Iterative DFS (should fix stack overflowing when cell size is very small)
- Function arguments can be passed through registers for optimization purposes
