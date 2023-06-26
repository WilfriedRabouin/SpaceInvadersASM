%include "sdl.asm"

extern puts, printf

screen_width: equ 224
screen_height: equ 256
scale: equ 2

cannon_y: equ 216
cannon_width: equ 13
cannon_height: equ 8

laser_height: equ 4
laser_speed: equ 4

small_alien_width: equ 8
medium_alien_width: equ 11
large_alien_width: equ 12
alien_height: equ 8
aliens_row_count: equ 5
aliens_column_count: equ 11
aliens_count: equ aliens_row_count * aliens_column_count

shelter_width: equ 22
shelter_height: equ 16
shelters_count: equ 4

struc entity
    .texture: resq 1
    .srcrect: resb SDL_Rect_size
    .dstrect: resb SDL_Rect_size
    .alive: resb 1
endstruc

%macro check_laser_collision 2
    mov rcx, %1 ; entities
    mov dl, %2 ; count
    call check_laser_collision_func
%endmacro

%macro create_aliens_row 3
    mov rcx, %1 ; texture
    mov edx, %2 ; width
    mov r8d, %3 ; row index
    call create_aliens_row_func
%endmacro

%macro set_entity_texture 2
    mov rax, [%2] ; texture
    mov [%1 + entity.texture], rax
%endmacro

%macro set_entity_srcrect 5
    mov dword [%1 + entity.srcrect + SDL_Rect.x], %2
    mov dword [%1 + entity.srcrect + SDL_Rect.y], %3
    mov dword [%1 + entity.srcrect + SDL_Rect.w], %4
    mov dword [%1 + entity.srcrect + SDL_Rect.h], %5
%endmacro

%macro set_entity_dstrect 5
    mov dword [%1 + entity.dstrect + SDL_Rect.x], %2
    mov dword [%1 + entity.dstrect + SDL_Rect.y], %3
    mov dword [%1 + entity.dstrect + SDL_Rect.w], %4
    mov dword [%1 + entity.dstrect + SDL_Rect.h], %5
%endmacro

%macro render_entity 1
    mov rcx, %1 ; entity
    call render_entity_func
%endmacro

%macro load_texture 2
    mov rcx, %1 ; file
    call load_texture_func
    mov [%2], rax ; texture
%endmacro

%macro render_texture 3
    mov rcx, [renderer]
    mov rdx, [%1] ; texture
    lea r8, [%2] ; srcrect
    lea r9, [%3] ; dstrect
    call SDL_RenderCopy
%endmacro

%macro free_texture 1
    mov rcx, [%1] ; texture
    call SDL_DestroyTexture
%endmacro

%macro load_sound 2
    mov rcx, %1 ; file
    call load_sound_func
    mov [%2], rax ; sound
%endmacro

%macro play_sound 1
    mov ecx, -1 ; channel
    mov rdx, [%1] ; sound
    mov r8d, 0 ; loops
    call Mix_PlayChannel
%endmacro

%macro free_sound 1
    mov rcx, [%1] ; sound
    call Mix_FreeChunk
%endmacro

section .text
global main
main:
    push rsi
    push rbx
    sub rsp, 56

    ; init SDL
    mov ecx, SDL_INIT_VIDEO | SDL_INIT_AUDIO ; flags
    call SDL_Init
    test eax, eax
    je .init_sdl_success
    mov rcx, init_sdl_msg_fail
    call puts
    jmp .main_end
.init_sdl_success:
    mov rcx, init_sdl_msg_success
    call puts

    ; create window
    mov rcx, title
    mov edx, SDL_WINDOWPOS_UNDEFINED ; x
    mov r8d, SDL_WINDOWPOS_UNDEFINED ; y
    mov r9d, screen_width * scale
    mov dword [rsp + 32], screen_height * scale
    mov dword [rsp + 40], 0 ; flags
    call SDL_CreateWindow
    test rax, rax
    jne .create_window_success
    mov rcx, create_window_msg_fail
    call puts
    jmp .free_sdl
.create_window_success:
    mov [window], rax
    mov rcx, create_window_msg_success
    call puts

    ; create renderer
    mov rcx, [window]
    mov edx, -1 ; index
    mov r8d, 0 ; flags
    call SDL_CreateRenderer
    test rax, rax
    jne .create_renderer_success
    mov rcx, create_renderer_msg_fail
    call puts
    jmp .free_window
.create_renderer_success:
    mov [renderer], rax
    mov rcx, create_renderer_msg_success
    call puts

    ; set renderer size
    mov rcx, [renderer]
    mov edx, screen_width
    mov r8d, screen_height
    call SDL_RenderSetLogicalSize
    test eax, eax
    je .set_renderer_size_success
    mov rcx, set_renderer_size_msg_fail
    call puts
    jmp .free_renderer
.set_renderer_size_success:
    mov rcx, set_renderer_size_msg_success
    call puts

    ; init SDL_image
    mov ecx, IMG_INIT_PNG ; flags
    call IMG_Init
    cmp eax, IMG_INIT_PNG
    je .init_sdl_image_success
    mov rcx, init_sdl_image_msg_fail
    call puts
    jmp .free_renderer
.init_sdl_image_success:
    mov rcx, init_sdl_image_msg_success
    call puts

    ; init SDL_mixer
    mov ecx, 44100 ; frequency
    mov dx, AUDIO_U8 ; format
    mov r8d, 1 ; channels
    mov r9d, 512 ; chunksize
    call Mix_OpenAudio
    test eax, eax
    je .init_sdl_mixer_success
    mov rcx, init_sdl_mixer_msg_fail
    call puts
    jmp .free_sdl_image
.init_sdl_mixer_success:
    mov rcx, init_sdl_mixer_msg_success
    call puts

    ; load textures
    load_texture space_texture_file, space_texture
    load_texture cannon_texture_file, cannon_texture
    load_texture laser_texture_file, laser_texture
    load_texture large_alien_texture_file, large_alien_texture
    load_texture medium_alien_texture_file, medium_alien_texture
    load_texture small_alien_texture_file, small_alien_texture
    load_texture shelter_texture_file, shelter_texture
    load_texture saucer_texture_file, saucer_texture

    ; load sounds
    load_sound laser_sound_file, laser_sound
    load_sound alien_explosion_sound_file, alien_explosion_sound

    ; create cannon
    set_entity_texture cannon, cannon_texture
    set_entity_srcrect cannon, 0, 0, cannon_width, cannon_height
    set_entity_dstrect cannon, 0, cannon_y, cannon_width, cannon_height
    mov byte [cannon + entity.alive], 1

    ; create laser
    set_entity_texture laser, laser_texture
    set_entity_srcrect laser, 0, 0, 1, laser_height
    set_entity_dstrect laser, 0, 0, 1, laser_height
    mov byte [laser + entity.alive], 0

    ; create aliens
    create_aliens_row large_alien_texture, large_alien_width, 0
    create_aliens_row large_alien_texture, large_alien_width, 1
    create_aliens_row medium_alien_texture, medium_alien_width, 2
    create_aliens_row medium_alien_texture, medium_alien_width, 3
    create_aliens_row small_alien_texture, small_alien_width, 4

    ; create shelters
    mov rcx, shelters
    mov r8d, 32
    mov dl, shelters_count
.create_shelter:
    set_entity_texture rcx, shelter_texture
    set_entity_srcrect rcx, 0, 0, shelter_width, shelter_height
    set_entity_dstrect rcx, r8d, 192, shelter_width, shelter_height
    mov byte [rcx + entity.alive], 1
    add rcx, entity_size
    add r8d, shelter_width + 23
    dec dl
    jnz .create_shelter

    ; get keyboard state
    mov rcx, 0 ; numkeys
    call SDL_GetKeyboardState
    mov [keyboard_state], rax

    ; init tick count
    call SDL_GetTicks
    mov [ticks], eax

.game_loop:

    ; poll events
.poll_event:
    mov rcx, event
    call SDL_PollEvent
    test eax, eax
    je .poll_event_end
    cmp dword [event + SDL_Event.type], SDL_QUIT
    je .game_loop_end
    jmp .poll_event
.poll_event_end:

    mov rax, [keyboard_state]

    ; handle right key
    cmp byte [rax + SDL_SCANCODE_RIGHT], 0
    je .right_key_end
    cmp dword [cannon + entity.dstrect + SDL_Rect.x], screen_width - cannon_width
    je .right_key_end
    inc dword [cannon + entity.dstrect + SDL_Rect.x]
.right_key_end:

    ; handle left key
    cmp byte [rax + SDL_SCANCODE_LEFT], 0
    je .left_key_end
    cmp dword [cannon + entity.dstrect + SDL_Rect.x], 0
    je .left_key_end
    dec dword [cannon + entity.dstrect + SDL_Rect.x]
.left_key_end:

    ; handle space key
    mov al, [rax + SDL_SCANCODE_SPACE]
    cmp al, [space_key_state]
    je .space_key_end
    mov [space_key_state], al
    test al, al
    je .space_key_end
    cmp byte [laser + entity.alive], 1
    je .space_key_end
    play_sound laser_sound
    mov eax, [cannon + entity.dstrect + SDL_Rect.x]
    add eax, cannon_width / 2
    mov [laser + entity.dstrect + SDL_Rect.x], eax
    mov dword [laser + entity.dstrect + SDL_Rect.y], cannon_y - laser_height + laser_speed
    mov byte [laser + entity.alive], 1
.space_key_end:

    cmp byte [laser + entity.alive], 0
    je .check_laser_collision_end

    ; update laser
    sub dword [laser + entity.dstrect + SDL_Rect.y], laser_speed
    cmp dword [laser + entity.dstrect + SDL_Rect.y], -laser_height
    jg .update_laser_end
    mov byte [laser + entity.alive], 0
    jmp .check_laser_collision_end
.update_laser_end:

    ; check for collision
    check_laser_collision shelters, shelters_count
    check_laser_collision aliens, aliens_count
    test rax, rax
    je .check_laser_collision_end
    mov byte [rax + entity.alive], 0
    play_sound alien_explosion_sound
.check_laser_collision_end:

    ; update aliens
    ; todo

    render_texture space_texture, 0, 0
    render_entity cannon
    render_entity laser

    ; render aliens
    mov rsi, aliens
    mov bl, aliens_count
.render_alien:
    render_entity rsi
    add rsi, entity_size
    dec bl
    jnz .render_alien

    ; render shelters
    mov rsi, shelters
    mov bl, shelters_count
.render_shelter:
    render_entity rsi
    add rsi, entity_size
    dec bl
    jnz .render_shelter

    ; update screen
    mov rcx, [renderer]
    call SDL_RenderPresent

    ; limit framerate to ~60fps
    call SDL_GetTicks
    mov ecx, eax
    sub eax, [ticks]
    mov [ticks], ecx
    mov ecx, 16
    sub ecx, eax
    jna .delay_end
    call SDL_Delay
.delay_end:

    jmp .game_loop
.game_loop_end:

    ; cleanup
    free_texture space_texture
    free_texture cannon_texture
    free_texture laser_texture
    free_texture large_alien_texture
    free_texture medium_alien_texture
    free_texture small_alien_texture
    free_texture shelter_texture
    free_texture saucer_texture
    free_sound laser_sound
    free_sound alien_explosion_sound
    call Mix_CloseAudio
.free_sdl_image:
    call IMG_Quit
.free_renderer:
    mov rcx, [renderer]
    call SDL_DestroyRenderer
.free_window:
    mov rcx, [window]
    call SDL_DestroyWindow
.free_sdl:
    call SDL_Quit

.main_end:
    xor eax, eax
    add rsp, 56
    pop rbx
    pop rsi
    ret

; inputs:
;   rcx = entities
;   dl = count
; output:
;   rax = collided entity
check_laser_collision_func:
.loop:
    cmp byte [rcx + entity.alive], 0
    je .next
    mov eax, dword [rcx + entity.dstrect + SDL_Rect.x]
    cmp eax, dword [laser + entity.dstrect + SDL_Rect.x]
    ja .next
    add eax, dword [rcx + entity.dstrect + SDL_Rect.w]
    cmp eax, dword [laser + entity.dstrect + SDL_Rect.x]
    jbe .next
    mov eax, dword [rcx + entity.dstrect + SDL_Rect.y]
    add eax, dword [rcx + entity.dstrect + SDL_Rect.h]
    cmp eax, dword [laser + entity.dstrect + SDL_Rect.y]
    jbe .next
    mov byte [laser + entity.alive], 0
    mov rax, rcx
    ret
.next:
    add rcx, entity_size
    dec dl
    jnz .loop
    xor rax, rax
    ret

; inputs:
;   rcx = texture
;   edx = width
;   r8d = row index
create_aliens_row_func:
    sub rsp, 40
    mov r9d, edx ; save width
    
    ; compute alien offset
    mov rax, entity_size * aliens_column_count
    mul r8d
    lea r10, [aliens + rax]

    ; compute y offset
    mov eax, aliens_row_count - 1
    sub eax, r8d
    mov r8d, eax
    mov eax, 16
    mul r8d
    lea r8d, [eax + 56]
    
    mov edx, r9d ; restore width
    mov r9d, 16
    mov r11b, aliens_column_count
.loop:
    set_entity_texture r10, rcx
    set_entity_srcrect r10, 0, 0, edx, alien_height
    set_entity_dstrect r10, r9d, r8d, edx, alien_height
    mov byte [r10 + entity.alive], 1
    add r10, entity_size
    add r9d, 16
    dec r11b
    jnz .loop
    add rsp, 40
    ret

; input: rcx = entity
render_entity_func:
    sub rsp, 40
    cmp byte [rcx + entity.alive], 0
    je .end
    mov rax, rcx
    render_texture rax + entity.texture, rax + entity.srcrect, rax + entity.dstrect
.end:
    add rsp, 40
    ret

; input: rcx = file
; output: rax = texture
load_texture_func:
    sub rsp, 56
    mov [rsp + 48], rcx
    call IMG_Load
    mov [rsp + 40], rax
    test rax, rax
    jne .load_img_success
    mov rcx, load_texture_msg_fail ; format
    jmp .end
.load_img_success:
    mov rcx, [renderer]
    mov rdx, rax ; surface
    call SDL_CreateTextureFromSurface
    mov rcx, [rsp + 40]
    mov [rsp + 40], rax
    call SDL_FreeSurface
    cmp qword [rsp + 40], 0
    jne .create_texture_success
    mov rcx, load_texture_msg_fail ; format
    jmp .end
.create_texture_success:
    mov rcx, load_texture_msg_success ; format
.end:
    mov rdx, [rsp + 48]
    call printf
    mov rax, [rsp + 40]
    add rsp, 56
    ret

; input: rcx = file
; output: rax = sound
load_sound_func:
    sub rsp, 40
    mov [rsp + 32], rcx
    call Mix_LoadWAV
    mov rdx, [rsp + 32]
    test rax, rax
    jne .success
    mov rcx, load_sound_msg_fail ; format
    jmp .end
.success:
    mov rcx, load_sound_msg_success ; format
.end:
    mov [rsp + 32], rax
    call printf
    mov rax, [rsp + 32]
    add rsp, 40
    ret

section .data
init_sdl_msg_success:
    db "OK > SDL_Init() success", 0
init_sdl_msg_fail:
    db "ERR > SDL_Init() fail", 0
create_window_msg_success:
    db "OK > SDL_CreateWindow() success", 0
create_window_msg_fail:
    db "ERR > SDL_CreateWindow() fail", 0
create_renderer_msg_success:
    db "OK > SDL_CreateRenderer() success", 0
create_renderer_msg_fail:
    db "ERR > SDL_CreateRenderer() fail", 0
set_renderer_size_msg_success:
    db "OK > SDL_RenderSetLogicalSize() success", 0
set_renderer_size_msg_fail:
    db "ERR > SDL_RenderSetLogicalSize() fail", 0
init_sdl_image_msg_success:
    db "OK > IMG_Init() success", 0
init_sdl_image_msg_fail:
    db "ERR > IMG_Init() fail", 0
init_sdl_mixer_msg_success:
    db "OK > Mix_OpenAudio() success", 0
init_sdl_mixer_msg_fail:
    db "ERR > Mix_OpenAudio() fail", 0
load_texture_msg_success:
    db "OK > Texture successfully loaded (%s)", 10, 0
load_texture_msg_fail:
    db "ERR > Failed to load texture (%s)", 10, 0
load_sound_msg_success:
    db "OK > Sound successfully loaded (%s)", 10, 0
load_sound_msg_fail:
    db "ERR > Failed to load sound (%s)", 10, 0
title:
    db "Space Invaders", 0
space_texture_file:
    db "res/space.png", 0
cannon_texture_file:
    db "res/cannon.png", 0
laser_texture_file:
    db "res/laser.png", 0
large_alien_texture_file:
    db "res/large_alien.png", 0
medium_alien_texture_file:
    db "res/medium_alien.png", 0
small_alien_texture_file:
    db "res/small_alien.png", 0
shelter_texture_file:
    db "res/shelter.png", 0
saucer_texture_file:
    db "res/saucer.png", 0
laser_sound_file:
    db "res/laser.wav", 0
alien_explosion_sound_file:
    db "res/alien_explosion.wav", 0
space_key_state:
    db 0

section .bss
window:
    resq 1
renderer:
    resq 1
space_texture:
    resq 1
cannon_texture:
    resq 1
laser_texture:
    resq 1
large_alien_texture:
    resq 1
medium_alien_texture:
    resq 1
small_alien_texture:
    resq 1
shelter_texture:
    resq 1
saucer_texture:
    resq 1
laser_sound:
    resq 1
alien_explosion_sound:
    resq 1
cannon:
    resb entity_size
laser:
    resb entity_size
aliens:
    resq entity_size * aliens_count
shelters:
    resq entity_size * shelters_count
event:
    resb SDL_Event_size
keyboard_state:
    resq 1
ticks:
    resd 1
