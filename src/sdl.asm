%ifndef SDL_ASM
%define SDL_ASM

extern SDL_Init, SDL_Quit, SDL_CreateWindow, SDL_DestroyWindow, SDL_CreateRenderer, SDL_DestroyRenderer, SDL_RenderSetLogicalSize
extern IMG_Init, IMG_Quit, IMG_Load, SDL_FreeSurface, SDL_CreateTextureFromSurface, SDL_DestroyTexture
extern SDL_PollEvent, SDL_GetKeyboardState, SDL_RenderCopy, SDL_RenderPresent, SDL_GetTicks, SDL_Delay
extern Mix_OpenAudio, Mix_CloseAudio, Mix_LoadWAV, Mix_FreeChunk, Mix_PlayChannel, Mix_HaltChannel

struc SDL_Event
    .type: resd 1
    .padding: resb 52
endstruc

struc SDL_Rect
    .x: resd 1
    .y: resd 1
    .w: resd 1
    .h: resd 1
endstruc

SDL_INIT_AUDIO: equ 0x10
SDL_INIT_VIDEO: equ 0x20
SDL_WINDOWPOS_UNDEFINED: equ 0x1fff0000
AUDIO_U8: equ 8
SDL_QUIT: equ 0x100
SDL_SCANCODE_SPACE: equ 44
SDL_SCANCODE_RIGHT: equ 79
SDL_SCANCODE_LEFT: equ 80
IMG_INIT_PNG: equ 2

%endif ; SDL_ASM
