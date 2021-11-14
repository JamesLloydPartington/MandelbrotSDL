# MandelbrotSDL
Create fractals with different iterative formulas, change colours, zoom in/out, SDL window graphics, use CPU or GPU (NVIDIA only).)

What you need:
SDL2
C++

Optional:
NVIDIA GPU
CUDA

With Linux, Compile code with either line in RunLine.txt. Run executable with wither ./runCPU or ./runGPU depending on which one used.

Use SDL_Mandelbrot.cpp for running only on CPU (No GPU needed)

Use SDL_Mandelbrot.cu for running on CPU + GPU. (If your GPU has less than 1024 CUDA cores, you can reduce this by changing THREADS_x and THREADS_y).


GUI Functions:

Zoom in - Zoom into a section by making a rectangle on the graphic window, the top left corner is selected by pressing the left mouse button, the bottom right corner is selected by pressing the right mouse button.

Zoom out - Press Backspace.

Change number of iterations - press "e" on the keyboard (make sure graphic window is active by moving the window). Enter integer number of iterations on terminal.

Code:
Feel free to change colour scheme and iterative function ect
