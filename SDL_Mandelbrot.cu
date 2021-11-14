#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_timer.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <thrust/complex.h>
#include <math.h>
#include <iostream>

#ifdef __CUDACC__
#define CUDA_CALLABLE_MEMBER __host__ __device__
#else
#define CUDA_CALLABLE_MEMBER
#endif

SDL_Window* win;
SDL_Renderer* rend;

//Width and Height of window
const int WIDTH = 1024;
const int HEIGHT = 1024;

//Classify a coordinate with a magnitude larger than DIVERGE as diverged (will stop further itterations of that coordinate).
const double DIVERGE = 2;

//Define class which give coordinate information
class coordInfo
{
  public:
    double start_x;
    double end_x;
    double start_y;
    double end_y;

    double step_x;
    double step_y;

    //Step sizes of real and imaginary axis
    void Steps()
    {
      step_x = (end_x - start_x) / (WIDTH - 1);
      step_y = (end_y - start_y) / (HEIGHT - 1);
    }

    //returns x coordinate given the pixel value on the x axis
    double xValue(int i)
    {
      return(start_x + i * step_x);
    }

    //returns y coordinate given the pixel value on the y axis
    double yValue(int j)
    {
      return(start_y + j * step_y);
    }
};

class fracVals
{
  public:
    thrust::complex<double> c; //Coordinate on complex plane
    thrust::complex<double> I = thrust::complex<double>(0, 1);; // 1i
    thrust::complex<double> z; //z_nth iteration
    int n; //Number of iterations
    bool isDiverged; //False if not above DIVERGE

    //Here you can change the iterative formular (Mandelbrot is z = z * z + c)
    CUDA_CALLABLE_MEMBER void Itterate()
    {
      /* Mandelbrot function
      z = z * z + c;
      if(thrust::abs(z) > DIVERGE)
      {
        isDiverged = true;
      }
      n++;
      */

      ////////////////////////////////////////////Custom formula start
      if(n == 0)
      {
        z = c;
      }
      z = thrust::tan(thrust::pow(z, z)) + c; //tan(z^z) + c
      //z = z * z + c;
      if(thrust::abs(z) > DIVERGE) //Mathematically this is incorrect for this formula since tan is periodic (This formula just creates a nice looking fractal)
      {
        isDiverged = true;
      }
      n++;
      ////////////////////////////////////////////Custom formula end
    }

    //Colour is a [Red, Green, Blue] array
    void RGB(coordInfo Grid, int N, int* colour)
    {
      //ORIGINAL DIMENTION


      if(n == N) //Give colour depending on where the iteration z is on the complex plane (green for real, blue for imaginary)
      {
        colour[0] = 200; //Customise value to change colour
        colour[1] = (int)floor(255 * (z.real() - DIVERGE) / (2 * DIVERGE));
        colour[2] = (int)floor(255 * (z.imag() - DIVERGE) / (2 * DIVERGE));
      }
      else //Give colour depending on how quickly z diverged. Darker the red, the quicker it diverged
      {
        colour[0] = (int)floor(255 * log(n) / log(N));
        colour[1] = 50; //Customise value to change colour
        colour[2] = 50; //Customise value to change colour
      }
    }
};

////////////////////////////////////////////////////////////////////////////////

fracVals** init_Fractal(coordInfo Grid) //Create 2D array of fractal points
{
  double x, y;
  int i, j;

  fracVals** M;
  cudaMallocManaged(&M, WIDTH * sizeof(fracVals*));

  for(i = 0; i < WIDTH; i++)
  {
    x = Grid.xValue(i);
    cudaMallocManaged(&M[i], HEIGHT * sizeof(fracVals));
    for(j = 0; j < HEIGHT; j++)
    {
      y = Grid.yValue(j);
      M[i][j].c= thrust::complex<double>(x, y);
      M[i][j].z= thrust::complex<double>(0, 0);
      M[i][j].n= 0;
      M[i][j].isDiverged = false;
    }
  }
  return(M);
}

__global__
void itterateAll_Fractal(fracVals** M, int N, coordInfo Grid)
{
  int i, j, k;
  //int index_k = threadIdx.z;
  //int stride_k = blockDim.z;

  i = blockIdx.x * blockDim.x + threadIdx.x;
  j = blockIdx.y * blockDim.y + threadIdx.y;

  if(i < WIDTH && j < HEIGHT)
  {
    for(k = 0; k < N; k++)
    {
      M[i][j].Itterate();
      if(M[i][j].isDiverged == true) //Once diverged, move to next point
      {
        break;
      }
    }
  }
}

void draw_Fractal(fracVals** M, int N, coordInfo Grid)
{
  cudaDeviceSynchronize();
  SDL_RenderClear(rend);
  int i, j;
  int* colour = (int*)calloc(3, sizeof(int));
  for(i = 0; i < WIDTH; i++)
  {
    for(j = 0; j < HEIGHT; j++)
    {
      M[i][j].RGB(Grid, N, colour);
      SDL_SetRenderDrawColor(rend, colour[0], colour[1], colour[2], 0xFF); //Draw pixel
      SDL_RenderDrawPoint(rend, i, j); //Draw pixel

    }
  }
  SDL_RenderPresent(rend);
  printf("Fractal made %d\n", N);

  SDL_Texture* target = SDL_GetRenderTarget(rend);
  SDL_SetRenderTarget(rend, NULL);
  //SDL_QueryTexture(NULL, NULL, NULL, &width, &height);
  SDL_Surface* surface = SDL_CreateRGBSurface(0, WIDTH, HEIGHT, 32, 0, 0, 0, 0);
  SDL_RenderReadPixels(rend, NULL, surface->format->format, surface->pixels, surface->pitch);
  SDL_SaveBMP(surface, "Fractal.bmp");
  SDL_FreeSurface(surface);
  SDL_SetRenderTarget(rend, target);
}

////////////////////////////////////////////////////////////////////////////////

void init_SDL()
{
  // retutns zero on success else non-zero
  if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
      printf("error initializing SDL: %s\n", SDL_GetError());
  }
  win = SDL_CreateWindow("Fractal", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);

  // triggers the program that controls
  // your graphics hardware and sets flags
  Uint32 render_flags = SDL_RENDERER_TARGETTEXTURE;

  // creates a renderer to render our images
  rend = SDL_CreateRenderer(win, -1, render_flags);
}

void close_SDL()
{
  // destroy renderer
  SDL_DestroyRenderer(rend);

  // destroy window
  SDL_DestroyWindow(win);

  // close SDL
  SDL_Quit();
}

//SDL event function
void events_SDL()
{
  coordInfo media_SDL(double, double, double, double, int);
  // controls annimation loop
  int close = 0;
  int N = 1000;
  bool OldFractal;

  bool RightButton = false;
  bool LeftButton = false;
  //bool NewState = true;
  int* RightClickPos = (int*)calloc(2, sizeof(int)); //[x, y] top right
  int* LeftClickPos = (int*)calloc(2, sizeof(int)); //[x, y] bottom left

  // annimation loop
  int x, y;
  Uint32 buttons;
  SDL_Event event;

  int historySize = 1000; //History size of zoom
  int historyIndex = 0;
  coordInfo* GridHistory = (coordInfo*)calloc(historySize, sizeof(coordInfo)); //Stores history of different zooms

  while (!close) //While SDL window is open
  {
    historyIndex = 0;
    GridHistory[historyIndex] = media_SDL(-DIVERGE, DIVERGE, -DIVERGE, DIVERGE, N);
    OldFractal = true;

    // Events management
    while (SDL_PollEvent(&event) || OldFractal)
    {
      switch (event.type)
      {
        case SDL_QUIT:
          // handling of close button
          close = 1;
          OldFractal = false;
          break;

        case SDL_KEYDOWN:
          // keyboard API for key pressed
          switch (event.key.keysym.scancode)
          {
            case SDL_SCANCODE_E: //Changer number of iterations
              printf("Enter number of itterations\n");
              scanf("%d", &N);
              GridHistory[historyIndex] = media_SDL(GridHistory[historyIndex].start_x, GridHistory[historyIndex].end_x, GridHistory[historyIndex].start_y, GridHistory[historyIndex].end_y, N);
              break;

            case SDL_SCANCODE_BACKSPACE: //Zoom out
              if(historyIndex > 0)
              {
                printf("Undone zoom\n");
                historyIndex--;
                GridHistory[historyIndex + 1] = media_SDL(GridHistory[historyIndex].start_x, GridHistory[historyIndex].end_x, GridHistory[historyIndex].start_y, GridHistory[historyIndex].end_y, N);
              }
              else
              {
                printf("Already at original zoom\n");
              }
              break;

            default:
              break;
          }
      }

      SDL_PumpEvents();  // make sure we have the latest mouse state.
      buttons = SDL_GetMouseState(&x, &y);

      if ((buttons & SDL_BUTTON_LMASK) != 0) //Bottom left (left click)
      {
        LeftButton = true;
        LeftClickPos[0] = x;
        LeftClickPos[1] = y;
      }

      if ((buttons & SDL_BUTTON_RMASK) != 0) //Top right (right click)
      {
        RightButton = true;
        RightClickPos[0] = x;
        RightClickPos[1] = y;
      }

      if(LeftButton && RightButton) //Once both left and right corners are made, zoom in.
      {
        printf("%f %f %f %f\n", GridHistory[historyIndex].xValue(LeftClickPos[0]), GridHistory[historyIndex].yValue(LeftClickPos[1]), GridHistory[historyIndex].xValue(RightClickPos[0]), GridHistory[historyIndex].yValue(RightClickPos[1]));

        GridHistory[historyIndex + 1] = media_SDL(GridHistory[historyIndex].xValue(LeftClickPos[0]), GridHistory[historyIndex].xValue(RightClickPos[0]), GridHistory[historyIndex].yValue(LeftClickPos[1]), GridHistory[historyIndex].yValue(RightClickPos[1]), N);
        historyIndex++;

        LeftButton = false;
        RightButton = false;
      }
    }
    SDL_DestroyRenderer(rend);
  }
}

coordInfo media_SDL(double start_x, double end_x, double start_y, double end_y, int N)
{
  fracVals** init_Fractal(coordInfo);

  coordInfo Grid;
  Grid.start_x = start_x;
  Grid.end_x = end_x;
  Grid.start_y = start_y;
  Grid.end_y = end_y;

  Grid.Steps();

  //Total threads = THREADS_x * THREADS_y, MAXIMUM IS 32 by 32 for this program on any GPU (even if it has more than 1024 threads).
  int THREADS_x = 32;
  int THREADS_y = 32;
  int BLOCKSIZE_x = (int)ceil(WIDTH / THREADS_x) + 1;
  int BLOCKSIZE_y = (int)ceil(HEIGHT / THREADS_y) + 1;

  dim3 threads(THREADS_x, THREADS_y);
  dim3 blocks(BLOCKSIZE_x, BLOCKSIZE_y);

  fracVals** Fractal = init_Fractal(Grid);
  itterateAll_Fractal<<<blocks, threads>>>(Fractal, N, Grid);

  void draw_Fractal(fracVals**, int, coordInfo);
  draw_Fractal(Fractal, N, Grid);

  return Grid;
}

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
  //Start SDL
  init_SDL();

  //SDL events
  events_SDL();

  //Close SDL
  close_SDL();

  return 0;
}
