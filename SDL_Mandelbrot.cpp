#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_timer.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <complex.h>
#include <math.h>


SDL_Window* win;
SDL_Renderer* rend;

const int WIDTH = 1024;
const int HEIGHT = 1024;
const double DIVERGE = 2;

class coordInfo
{
  public:
    double start_x;
    double end_x;
    double start_y;
    double end_y;

    double step_x;
    double step_y;

    void Steps()
    {
      step_x = (end_x - start_x) / (WIDTH - 1);
      step_y = (end_y - start_y) / (HEIGHT - 1);
    }

    double xValue(int i)
    {
      return(start_x + i * step_x);
    }

    double yValue(int j)
    {
      return(start_y + j * step_y);
    }
};

class fracVals
{
  public:
    std::complex<double> c;
    std::complex<double> z; //z_nth iteration
    int n; //Number of iterations
    bool isDiverged;

    void Itterate()
    {
      z = z * z + c;
      if(std::abs(z) > 2)
      {
        isDiverged = true;
      }
      n++;
    }

    void RGB(coordInfo Grid, int N, int* colour)
    {
      if(n == N)
      {
        colour[0] = 0;
        colour[1] = (int)floor(255 * (z.real() - 2) / (2 + 2));
        colour[2] = (int)floor(255 * (z.imag() - 2) / (2 + 2));
      }
      else
      {
        colour[0] = (int)floor(255 * log(n) / log(N));
        colour[1] = 0;
        colour[2] = 0;
      }
    }

};

////////////////////////////////////////////////////////////////////////////////

fracVals** init_Fractal(coordInfo Grid)
{
  double x, y;
  int i, j;

  fracVals** M = (fracVals**)calloc(WIDTH, sizeof(fracVals*));
  for(i = 0; i < WIDTH; i++)
  {
    x = Grid.xValue(i);
    M[i] = (fracVals*)calloc(HEIGHT, sizeof(fracVals));
    for(j = 0; j < HEIGHT; j++)
    {
      y = Grid.yValue(j);
      M[i][j].c = x + 1j * y;
      M[i][j].z= 0;
      M[i][j].n= 0;
      M[i][j].isDiverged = false;
    }
  }
  return(M);
}

void itterateAll_Fractal(fracVals** M, int N, coordInfo Grid)
{
  int i, j, k;
  for(i = 0; i < WIDTH; i++)
  {
    for(j = 0; j < HEIGHT; j++)
    {
      for(k = 0; k < N; k++)
      {
        M[i][j].Itterate();
        if(M[i][j].isDiverged == true)
        {
          break;
        }
      }
    }
  }
}

void draw_Fractal(fracVals** M, int N, coordInfo Grid)
{
  SDL_RenderClear(rend);
  int i, j;
  int* colour = (int*)calloc(3, sizeof(int));
  for(i = 0; i < WIDTH; i++)
  {
    for(j = 0; j < HEIGHT; j++)
    {
      M[i][j].RGB(Grid, N, colour);
      //printf("%f %f\n", real(M[i][j].z), imag(M[i][j].z));

      SDL_SetRenderDrawColor(rend, colour[0], colour[1], colour[2], 0xFF); //Draw vertical line
      SDL_RenderDrawPoint(rend, i, j);

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
  win = SDL_CreateWindow("GAME", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);

  // triggers the program that controls
  // your graphics hardware and sets flags
  Uint32 render_flags = SDL_RENDERER_ACCELERATED;

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
  int* RightClickPos = (int*)calloc(2, sizeof(int));
  int* LeftClickPos = (int*)calloc(2, sizeof(int));

  // annimation loop
  int x, y;
  Uint32 buttons;
  SDL_Event event;

  int historySize = 1000;
  int historyIndex = 0;
  coordInfo* GridHistory = (coordInfo*)calloc(historySize, sizeof(coordInfo));

  while (!close)
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
            case SDL_SCANCODE_E:
              printf("Enter number of itterations\n");
              scanf("%d", &N);
              GridHistory[historyIndex] = media_SDL(GridHistory[historyIndex].start_x, GridHistory[historyIndex].end_x, GridHistory[historyIndex].start_y, GridHistory[historyIndex].end_y, N);
              break;

            case SDL_SCANCODE_BACKSPACE:
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

      if ((buttons & SDL_BUTTON_LMASK) != 0)
      {
        LeftButton = true;
        LeftClickPos[0] = x;
        LeftClickPos[1] = y;
      }

      if ((buttons & SDL_BUTTON_RMASK) != 0)
      {
        RightButton = true;
        RightClickPos[0] = x;
        RightClickPos[1] = y;
      }

      if(LeftButton && RightButton)
      {
        printf("%f %f %f %f\n", GridHistory[historyIndex].xValue(LeftClickPos[0]), GridHistory[historyIndex].yValue(LeftClickPos[1]), GridHistory[historyIndex].xValue(RightClickPos[0]), GridHistory[historyIndex].yValue(RightClickPos[1]));

        GridHistory[historyIndex + 1] = media_SDL(GridHistory[historyIndex].xValue(LeftClickPos[0]), GridHistory[historyIndex].xValue(RightClickPos[0]), GridHistory[historyIndex].yValue(LeftClickPos[1]), GridHistory[historyIndex].yValue(RightClickPos[1]), N);
        historyIndex++;

        LeftButton = false;
        RightButton = false;
      }
    }
    SDL_DestroyRenderer(rend);

    // calculates to 60 fps
    //SDL_Delay(1000 / 60);
  }
}

coordInfo media_SDL(double start_x, double end_x, double start_y, double end_y, int N)
{
  fracVals** init_Fractal(coordInfo);
  void itterateAll_Fractal(fracVals**, int, coordInfo);

  coordInfo Grid;
  Grid.start_x = start_x;
  Grid.end_x = end_x;
  Grid.start_y = start_y;
  Grid.end_y = end_y;

  Grid.Steps();

  fracVals** Fractal = init_Fractal(Grid);
  itterateAll_Fractal(Fractal, N, Grid);

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
