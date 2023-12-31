%include "sdl.asm"

extern puts, printf

; ---------------------------------------------------------------------
;   CONSTANTS
; ---------------------------------------------------------------------

screen_width: equ 224
screen_height: equ 256
scale: equ 2

cannon_y: equ 216
cannon_width: equ 13
cannon_height: equ 8

cannon_shot_height: equ 4
cannon_shot_speed: equ 4

cannon_shot_explosion_width: equ 8
cannon_shot_explosion_height: equ 8

small_alien_width: equ 8
medium_alien_width: equ 11
large_alien_width: equ 12
alien_height: equ 8
alien_speed: equ 2
aliens_row_count: equ 5
aliens_column_count: equ 11
aliens_count: equ aliens_row_count * aliens_column_count
aliens_end: equ aliens + entity_size * aliens_count

alien_explosion_width: equ 13
alien_explosion_height: equ 7

alien_shot_width: equ 3
alien_shot_height: equ 7
alien_shot_spawn_timer_reset_value: equ 0x90
alien_shot_animation_timer_reset_value: equ 30

alien_shot_explosion_width: equ 6
alien_shot_explosion_height: equ 8

shelter_width: equ 22
shelter_height: equ 16
shelters_count: equ 4
shelters_end: equ shelters + entity_size * shelters_count

saucer_y: equ 41
saucer_width: equ 16
saucer_height: equ 7
saucer_spawn_timer_reset_value: equ 0x600
saucer_moving_timer_reset_value: equ 2

saucer_explosion_width: equ 21
saucer_explosion_height: equ 8

true: equ 1
false: equ 0

infinite: equ -1
singleshot: equ 0

right: equ 1
left: equ 0

explosion_lifetime: equ 30

; ---------------------------------------------------------------------
;   STRUCTURES
; ---------------------------------------------------------------------

struc entity
    .texture: resq 1
    .srcrect: resb SDL_Rect_size
    .dstrect: resb SDL_Rect_size
    .alive: resb 1
    .lifetime: resb 1 ; remaining frames
endstruc

; ---------------------------------------------------------------------
;   MACROS
; ---------------------------------------------------------------------

%macro check_cannon_shot_collision 2
    mov rcx, %1 ; entities
    mov rdx, %2 ; end
    call check_cannon_shot_collision_func
%endmacro

%macro move_animate_alien_shot 4
    mov rcx, %1 ; alien shot
    mov rdx, %2 ; animation timer
    mov r8, %3 ; spawn timer
    mov r9, %4 ; explosion
    call move_animate_alien_shot_func
%endmacro

%macro spawn_random_alien_shot 2
    mov rcx, %1 ; alien shot
    mov rdx, %2 ; animation timer
    call spawn_random_alien_shot_func
%endmacro

%macro create_alien_shot_explosion 1
    set_entity_texture %1, alien_shot_explosion_texture
    set_entity_srcrect %1, 0, 0, alien_shot_explosion_width, alien_shot_explosion_height
    set_entity_dstrect %1, 0, screen_height - alien_shot_explosion_height, alien_shot_explosion_width, alien_shot_explosion_height
    mov byte [%1 + entity.alive], false
    mov byte [%1 + entity.lifetime], 0
%endmacro

%macro create_alien_shot 2
    set_entity_texture %1, %2
    set_entity_srcrect %1, 0, 0, alien_shot_width, alien_shot_height
    set_entity_dstrect %1, 0, 0, alien_shot_width, alien_shot_height
    mov byte [%1 + entity.alive], false
    mov byte [%1 + entity.lifetime], infinite
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

%macro play_sound 2
    mov ecx, -1 ; channel
    mov rdx, [%1] ; sound
    mov r8d, %2 ; loops
    call Mix_PlayChannel
%endmacro

%macro stop_sound 1
    mov ecx, [%1] ; channel
    call Mix_HaltChannel
%endmacro

%macro free_sound 1
    mov rcx, [%1] ; sound
    call Mix_FreeChunk
%endmacro

; ---------------------------------------------------------------------
;   MAIN START
; ---------------------------------------------------------------------

section .text
global main
main:
    push rsi
    sub rsp, 48

; ---------------------------------------------------------------------
;   INITIALIZATION
; ---------------------------------------------------------------------

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
    xor r8d, r8d ; flags
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
    load_texture cannon_shot_texture_file, cannon_shot_texture
    load_texture cannon_shot_explosion_texture_file, cannon_shot_explosion_texture
    load_texture large_alien_texture_file, large_alien_texture
    load_texture medium_alien_texture_file, medium_alien_texture
    load_texture small_alien_texture_file, small_alien_texture
    load_texture alien_explosion_texture_file, alien_explosion_texture
    load_texture alien_shot1_texture_file, alien_shot1_texture
    load_texture alien_shot2_texture_file, alien_shot2_texture
    load_texture alien_shot3_texture_file, alien_shot3_texture
    load_texture alien_shot_explosion_texture_file, alien_shot_explosion_texture
    load_texture shelter_texture_file, shelter_texture
    load_texture saucer_texture_file, saucer_texture
    load_texture saucer_explosion_texture_file, saucer_explosion_texture

    ; load sounds
    load_sound cannon_shot_sound_file, cannon_shot_sound
    load_sound alien_explosion_sound_file, alien_explosion_sound
    load_sound saucer_sound_file, saucer_sound
    load_sound saucer_explosion_sound_file, saucer_explosion_sound

    ; create cannon
    set_entity_texture cannon, cannon_texture
    set_entity_srcrect cannon, 0, 0, cannon_width, cannon_height
    set_entity_dstrect cannon, 0, cannon_y, cannon_width, cannon_height
    mov byte [cannon + entity.alive], true
    mov byte [cannon + entity.lifetime], infinite

    ; create cannon shot
    set_entity_texture cannon_shot, cannon_shot_texture
    set_entity_srcrect cannon_shot, 0, 0, 1, cannon_shot_height
    set_entity_dstrect cannon_shot, 0, 0, 1, cannon_shot_height
    mov byte [cannon_shot + entity.alive], false
    mov byte [cannon_shot + entity.lifetime], infinite

    ; create cannon shot explosion
    set_entity_texture cannon_shot_explosion, cannon_shot_explosion_texture
    set_entity_srcrect cannon_shot_explosion, 0, 0, cannon_shot_explosion_width, cannon_shot_explosion_height
    set_entity_dstrect cannon_shot_explosion, 0, 0, cannon_shot_explosion_width, cannon_shot_explosion_height
    mov byte [cannon_shot_explosion + entity.alive], false
    mov byte [cannon_shot_explosion + entity.lifetime], 0

    ; create aliens
    create_aliens_row large_alien_texture, large_alien_width, 0
    create_aliens_row large_alien_texture, large_alien_width, 1
    create_aliens_row medium_alien_texture, medium_alien_width, 2
    create_aliens_row medium_alien_texture, medium_alien_width, 3
    create_aliens_row small_alien_texture, small_alien_width, 4

    ; create alien explosion
    set_entity_texture alien_explosion, alien_explosion_texture
    set_entity_srcrect alien_explosion, 0, 0, alien_explosion_width, alien_explosion_height
    set_entity_dstrect alien_explosion, 0, 0, alien_explosion_width, alien_explosion_height
    mov byte [alien_explosion + entity.alive], false
    mov byte [alien_explosion + entity.lifetime], 0

    ; create alien shots
    create_alien_shot alien_shot1, alien_shot1_texture
    create_alien_shot alien_shot2, alien_shot2_texture
    create_alien_shot alien_shot3, alien_shot3_texture

    ; create alien shot explosions
    create_alien_shot_explosion alien_shot1_explosion
    create_alien_shot_explosion alien_shot2_explosion
    create_alien_shot_explosion alien_shot3_explosion

    ; create shelters
    mov rcx, shelters
    mov edx, 32
.create_shelter:
    set_entity_texture rcx, shelter_texture
    set_entity_srcrect rcx, 0, 0, shelter_width, shelter_height
    set_entity_dstrect rcx, edx, 192, shelter_width, shelter_height
    mov byte [rcx + entity.alive], true
    mov byte [rcx + entity.lifetime], infinite
    add rcx, entity_size
    add edx, shelter_width + 23
    cmp rcx, shelters_end
    jne .create_shelter

    ; create saucer
    set_entity_texture saucer, saucer_texture
    set_entity_srcrect saucer, 0, 0, saucer_width, saucer_height
    set_entity_dstrect saucer, 0, saucer_y, saucer_width, saucer_height
    mov byte [saucer + entity.alive], false
    mov byte [saucer + entity.lifetime], infinite

    ; create saucer explosion
    set_entity_texture saucer_explosion, saucer_explosion_texture
    set_entity_srcrect saucer_explosion, 0, 0, saucer_explosion_width, saucer_explosion_height
    set_entity_dstrect saucer_explosion, 0, saucer_y - (saucer_explosion_height - saucer_height) / 2, saucer_explosion_width, saucer_explosion_height
    mov byte [saucer_explosion + entity.alive], false
    mov byte [saucer_explosion + entity.lifetime], 0

    ; get keyboard state
    xor rcx, rcx ; numkeys
    call SDL_GetKeyboardState
    mov [keyboard_state], rax

    ; init tick count
    call SDL_GetTicks
    mov [ticks], eax

; ---------------------------------------------------------------------
;   GAME LOOP START
; ---------------------------------------------------------------------

.game_loop:

; ---------------------------------------------------------------------
;   EVENT HANDLING
; ---------------------------------------------------------------------

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
    je .handle_right_key_end
    cmp dword [cannon + entity.dstrect + SDL_Rect.x], screen_width - cannon_width
    je .handle_right_key_end
    inc dword [cannon + entity.dstrect + SDL_Rect.x]
.handle_right_key_end:

    ; handle left key
    cmp byte [rax + SDL_SCANCODE_LEFT], 0
    je .handle_left_key_end
    cmp dword [cannon + entity.dstrect + SDL_Rect.x], 0
    je .handle_left_key_end
    dec dword [cannon + entity.dstrect + SDL_Rect.x]
.handle_left_key_end:

    ; handle space key
    mov al, [rax + SDL_SCANCODE_SPACE]
    cmp al, [space_key_state]
    je .handle_space_key_end
    mov [space_key_state], al
    test al, al
    je .handle_space_key_end
    cmp byte [cannon_shot + entity.alive], true
    je .handle_space_key_end
    mov eax, [cannon + entity.dstrect + SDL_Rect.x]
    add eax, cannon_width / 2
    mov [cannon_shot + entity.dstrect + SDL_Rect.x], eax
    mov dword [cannon_shot + entity.dstrect + SDL_Rect.y], cannon_y - cannon_shot_height + cannon_shot_speed
    mov byte [cannon_shot + entity.alive], true
    play_sound cannon_shot_sound, singleshot
    inc byte [cannon_shot_number]
    cmp byte [cannon_shot_number], 16
    jne .handle_space_key_end
    mov byte [cannon_shot_number], 0
.handle_space_key_end:

; ---------------------------------------------------------------------
;   ALIEN UPDATE
; ---------------------------------------------------------------------

    ; get current alien
.get_current_alien:
    mov rax, [current_alien]
.get_current_alien_loop:
    add rax, entity_size
    cmp rax, aliens_end
    jne .get_current_alien_loop_check
    mov qword [current_alien], aliens - entity_size
    mov rax, aliens
    cmp byte [aliens_moving_direction], right
    je .check_aliens_right
.check_aliens_left:
    cmp byte [rax + entity.alive], false
    je .check_aliens_left_next
    cmp dword [rax + entity.dstrect + SDL_Rect.x], alien_speed
    jae .check_aliens_left_next
    mov byte [aliens_moving_direction], right
    call move_aliens_down
    jmp .get_current_alien
.check_aliens_left_next:
    add rax, entity_size
    cmp rax, aliens_end
    jne .check_aliens_left
    jmp .get_current_alien
.check_aliens_right:
    cmp byte [rax + entity.alive], false
    je .check_aliens_right_next
    mov edx, [rax + entity.dstrect + SDL_Rect.x]
    add edx, [rax + entity.dstrect + SDL_Rect.w]
    cmp edx, screen_width - alien_speed
    jbe .check_aliens_right_next
    mov byte [aliens_moving_direction], left
    call move_aliens_down
    jmp .get_current_alien
.check_aliens_right_next:
    add rax, entity_size
    cmp rax, aliens_end
    jne .check_aliens_right
    jmp .get_current_alien
.get_current_alien_loop_check:
    cmp byte [rax + entity.alive], false
    je .get_current_alien_loop
    mov [current_alien], rax

    ; move current alien
    cmp byte [aliens_moving_direction], right
    je .move_current_alien_right
    sub dword [rax + entity.dstrect + SDL_Rect.x], alien_speed
    jmp .move_current_alien_end
.move_current_alien_right:
    add dword [rax + entity.dstrect + SDL_Rect.x], alien_speed
.move_current_alien_end:

    ; animate current alien
    mov ecx, [rax + entity.srcrect + SDL_Rect.w]
    cmp ecx, [rax + entity.srcrect + SDL_Rect.x]
    je .animate_current_alien_reset
    mov [rax + entity.srcrect + SDL_Rect.x], ecx
    jmp .animate_current_alien_end
.animate_current_alien_reset:
    mov dword [rax + entity.srcrect + SDL_Rect.x], 0
.animate_current_alien_end:

; ---------------------------------------------------------------------
;   SAUCER UPDATE
; ---------------------------------------------------------------------

    cmp byte [saucer + entity.alive], true
    je .move_saucer
    dec word [saucer_spawn_timer]
    jnz .move_saucer_end

    ; spawn saucer
    mov byte [saucer + entity.alive], true
    play_sound saucer_sound, infinite
    mov [saucer_sound_channel], eax
    bt word [cannon_shot_number], 0
    jc .spawn_saucer_left
    mov dword [saucer + entity.dstrect + SDL_Rect.x], screen_width - saucer_width
    mov byte [saucer_moving_direction], left
    jmp .move_saucer_end
.spawn_saucer_left:
    mov dword [saucer + entity.dstrect + SDL_Rect.x], 0
    mov byte [saucer_moving_direction], right
    jmp .move_saucer_end

    ; move saucer
.move_saucer:
    dec byte [saucer_moving_timer]
    jnz .move_saucer_end
    mov byte [saucer_moving_timer], saucer_moving_timer_reset_value
    cmp byte [saucer_moving_direction], right
    je .move_saucer_right
    dec dword [saucer + entity.dstrect + SDL_Rect.x]
    cmp dword [saucer + entity.dstrect + SDL_Rect.x], -saucer_width
    jg .move_saucer_end
    jmp .restart_saucer_spawn_timer
.move_saucer_right:
    inc dword [saucer + entity.dstrect + SDL_Rect.x]
    cmp dword [saucer + entity.dstrect + SDL_Rect.x], screen_width
    jl .move_saucer_end
.restart_saucer_spawn_timer:
    mov byte [saucer + entity.alive], false
    stop_sound saucer_sound_channel
    mov word [saucer_spawn_timer], saucer_spawn_timer_reset_value
.move_saucer_end:

; ---------------------------------------------------------------------
;   CANNON SHOT UPDATE
; ---------------------------------------------------------------------

    ; move cannon shot
    cmp byte [cannon_shot + entity.alive], false
    je .move_cannon_shot_end
    sub dword [cannon_shot + entity.dstrect + SDL_Rect.y], cannon_shot_speed
    cmp dword [cannon_shot + entity.dstrect + SDL_Rect.y], 0
    jge .move_cannon_shot_end
    mov byte [cannon_shot + entity.alive], false
    mov eax, [cannon_shot + entity.dstrect + SDL_Rect.x]
    sub eax, cannon_shot_explosion_width / 2
    mov [cannon_shot_explosion + entity.dstrect + SDL_Rect.x], eax
    mov byte [cannon_shot_explosion + entity.alive], true
    mov byte [cannon_shot_explosion + entity.lifetime], explosion_lifetime
.move_cannon_shot_end:

; ---------------------------------------------------------------------
;   ALIEN SHOT 1 UPDATE
; ---------------------------------------------------------------------

    cmp byte [alien_shot1 + entity.alive], true
    je .move_animate_alien_shot1
    dec word [alien_shot1_spawn_timer]
    jnz .move_animate_alien_shot1_end

    ; get above alien
    xor r8, r8 ; r8 = above alien
    xor r9b, r9b ; r9b = its column
    mov r10, aliens ; r10 = current alien
    xor r11b, r11b ; r11b = its column
.get_above_alien:
    cmp byte [r10 + entity.alive], false
    je .get_above_alien_next
    test r8, r8
    je .get_above_alien_update
    cmp r9b, r11b
    je .get_above_alien_next
    mov eax, [cannon + entity.dstrect + SDL_Rect.x]
    sub eax, [r8 + entity.dstrect + SDL_Rect.x]
    mul eax
    mov ecx, eax ; ecx = horizontal squared distance between cannon and above alien
    mov eax, [cannon + entity.dstrect + SDL_Rect.x]
    sub eax, [r10 + entity.dstrect + SDL_Rect.x]
    mul eax ; eax = horizontal squared distance between cannon and current alien
    cmp ecx, eax
    jbe .get_above_alien_next
.get_above_alien_update:
    mov r8, r10
    mov r9b, r11b
.get_above_alien_next:
    add r10, entity_size
    inc r11b
    cmp r11b, aliens_column_count
    jne .get_above_alien_next_end
    xor r11b, r11b
.get_above_alien_next_end:
    cmp r10, aliens_end
    jne .get_above_alien

    ; spawn alien shot
    mov rcx, alien_shot1
    mov rdx, alien_shot1_animation_timer
    call spawn_alien_shot
    jmp .move_animate_alien_shot1_end

    ; move alien shot
.move_animate_alien_shot1:
    move_animate_alien_shot alien_shot1, alien_shot1_animation_timer, alien_shot1_spawn_timer, alien_shot1_explosion
.move_animate_alien_shot1_end:

; ---------------------------------------------------------------------
;   ALIEN SHOT 2 UPDATE
; ---------------------------------------------------------------------

    cmp byte [alien_shot2 + entity.alive], true
    je .move_animate_alien_shot2
    dec word [alien_shot2_spawn_timer]
    jnz .move_animate_alien_shot2_end

    ; spawn alien shot
    spawn_random_alien_shot alien_shot2, alien_shot2_animation_timer
    jmp .move_animate_alien_shot2_end

    ; move alien shot
.move_animate_alien_shot2:
    move_animate_alien_shot alien_shot2, alien_shot2_animation_timer, alien_shot2_spawn_timer, alien_shot2_explosion
.move_animate_alien_shot2_end:

; ---------------------------------------------------------------------
;   ALIEN SHOT 3 UPDATE
; ---------------------------------------------------------------------

    cmp byte [alien_shot3 + entity.alive], true
    je .move_animate_alien_shot3
    dec word [alien_shot3_spawn_timer]
    jnz .move_animate_alien_shot3_end

    ; spawn alien shot
    spawn_random_alien_shot alien_shot3, alien_shot3_animation_timer
    jmp .move_animate_alien_shot3_end

    ; move alien shot
.move_animate_alien_shot3:
    move_animate_alien_shot alien_shot3, alien_shot3_animation_timer, alien_shot3_spawn_timer, alien_shot3_explosion
.move_animate_alien_shot3_end:

; ---------------------------------------------------------------------
;   CHECK COLLISIONS
; ---------------------------------------------------------------------

    cmp byte [cannon_shot + entity.alive], false
    je .cannon_shot_collision_end

    ; cannon shot <> shelters
    check_cannon_shot_collision shelters, shelters_end
    cmp rax, shelters_end
    jne .cannon_shot_collision_end

    ; cannon shot <> aliens
    check_cannon_shot_collision aliens, aliens_end
    cmp rax, aliens_end
    je .cannon_shot_collision_aliens_end
    dec byte [aliens_alive_count]
    mov byte [rax + entity.alive], false
    mov ecx, [rax + entity.dstrect + SDL_Rect.w]
    sub ecx, alien_explosion_width
    sar ecx, 1
    add ecx, [rax + entity.dstrect + SDL_Rect.x]
    mov [alien_explosion + entity.dstrect + SDL_Rect.x], ecx
    mov ecx, [rax + entity.dstrect + SDL_Rect.h]
    sub ecx, alien_explosion_height
    sar ecx, 1
    add ecx, [rax + entity.dstrect + SDL_Rect.y]
    mov [alien_explosion + entity.dstrect + SDL_Rect.y], ecx
    mov byte [alien_explosion + entity.alive], true
    mov byte [alien_explosion + entity.lifetime], explosion_lifetime
    play_sound alien_explosion_sound, singleshot
    jmp .cannon_shot_collision_end
.cannon_shot_collision_aliens_end:

    ; cannon shot <> saucer
    check_cannon_shot_collision saucer, saucer + entity_size
    cmp rax, saucer + entity_size
    je .cannon_shot_collision_saucer_end
    mov byte [saucer + entity.alive], false
    stop_sound saucer_sound_channel
    mov word [saucer_spawn_timer], saucer_spawn_timer_reset_value
    mov ecx, [saucer + entity.dstrect + SDL_Rect.x]
    sub ecx, (saucer_explosion_width - saucer_width) / 2
    mov [saucer_explosion + entity.dstrect + SDL_Rect.x], ecx
    mov byte [saucer_explosion + entity.alive], true
    mov byte [saucer_explosion + entity.lifetime], explosion_lifetime
    play_sound saucer_explosion_sound, singleshot
    jmp .cannon_shot_collision_end
.cannon_shot_collision_saucer_end:

    ; cannon shot <> alien shots
    check_cannon_shot_collision alien_shot1, alien_shot1 + entity_size
    cmp rax, alien_shot1 + entity_size
    je .cannon_shot_collision_alien_shot1_end
    mov byte [alien_shot1 + entity.alive], false
    mov eax, [alien_shot1 + entity.dstrect + SDL_Rect.x]
    sub eax, (alien_shot_explosion_width - alien_shot_width) / 2
    mov [alien_shot1_explosion + entity.dstrect + SDL_Rect.x], eax
    mov eax, [alien_shot1 + entity.dstrect + SDL_Rect.y]
    sub eax, (alien_shot_explosion_height - alien_shot_height) / 2
    mov [alien_shot1_explosion + entity.dstrect + SDL_Rect.y], eax
    mov byte [alien_shot1_explosion + entity.alive], true
    mov byte [alien_shot1_explosion + entity.lifetime], explosion_lifetime
    mov word [alien_shot1_spawn_timer], alien_shot_spawn_timer_reset_value
    jmp .cannon_shot_collision_end
.cannon_shot_collision_alien_shot1_end:

    check_cannon_shot_collision alien_shot2, alien_shot2 + entity_size
    cmp rax, alien_shot2 + entity_size
    je .cannon_shot_collision_alien_shot2_end
    mov byte [alien_shot2 + entity.alive], false
    mov eax, [alien_shot2 + entity.dstrect + SDL_Rect.x]
    sub eax, (alien_shot_explosion_width - alien_shot_width) / 2
    mov [alien_shot2_explosion + entity.dstrect + SDL_Rect.x], eax
    mov eax, [alien_shot2 + entity.dstrect + SDL_Rect.y]
    sub eax, (alien_shot_explosion_height - alien_shot_height) / 2
    mov [alien_shot2_explosion + entity.dstrect + SDL_Rect.y], eax
    mov byte [alien_shot2_explosion + entity.alive], true
    mov byte [alien_shot2_explosion + entity.lifetime], explosion_lifetime
    mov word [alien_shot2_spawn_timer], alien_shot_spawn_timer_reset_value
    jmp .cannon_shot_collision_end
.cannon_shot_collision_alien_shot2_end:

    check_cannon_shot_collision alien_shot3, alien_shot3 + entity_size
    cmp rax, alien_shot3 + entity_size
    je .cannon_shot_collision_alien_shot3_end
    mov byte [alien_shot3 + entity.alive], false
    mov eax, [alien_shot3 + entity.dstrect + SDL_Rect.x]
    sub eax, (alien_shot_explosion_width - alien_shot_width) / 2
    mov [alien_shot3_explosion + entity.dstrect + SDL_Rect.x], eax
    mov eax, [alien_shot3 + entity.dstrect + SDL_Rect.y]
    sub eax, (alien_shot_explosion_height - alien_shot_height) / 2
    mov [alien_shot3_explosion + entity.dstrect + SDL_Rect.y], eax
    mov byte [alien_shot3_explosion + entity.alive], true
    mov byte [alien_shot3_explosion + entity.lifetime], explosion_lifetime
    mov word [alien_shot3_spawn_timer], alien_shot_spawn_timer_reset_value
    jmp .cannon_shot_collision_end
.cannon_shot_collision_alien_shot3_end:

.cannon_shot_collision_end:

    ; alien shots <> shelters
    ; todo

    ; alien shots <> cannon
    ; todo

; ---------------------------------------------------------------------
;   RENDERING
; ---------------------------------------------------------------------

    render_texture space_texture, 0, 0
    render_entity cannon
    render_entity cannon_shot
    render_entity cannon_shot_explosion
    render_entity alien_explosion
    render_entity alien_shot1
    render_entity alien_shot2
    render_entity alien_shot3
    render_entity alien_shot1_explosion
    render_entity alien_shot2_explosion
    render_entity alien_shot3_explosion
    render_entity saucer
    render_entity saucer_explosion

    ; render aliens
    mov rsi, aliens
.render_alien:
    render_entity rsi
    add rsi, entity_size
    cmp rsi, aliens_end
    jne .render_alien

    ; render shelters
    mov rsi, shelters
.render_shelter:
    render_entity rsi
    add rsi, entity_size
    cmp rsi, shelters_end
    jne .render_shelter

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

; ---------------------------------------------------------------------
;   GAME LOOP END
; ---------------------------------------------------------------------

    jmp .game_loop
.game_loop_end:

; ---------------------------------------------------------------------
;   CLEANUP
; ---------------------------------------------------------------------

    ; graphics
    free_texture space_texture
    free_texture cannon_texture
    free_texture cannon_shot_texture
    free_texture cannon_shot_explosion_texture
    free_texture large_alien_texture
    free_texture medium_alien_texture
    free_texture small_alien_texture
    free_texture alien_explosion_texture
    free_texture alien_shot1_texture
    free_texture alien_shot2_texture
    free_texture alien_shot3_texture
    free_texture alien_shot_explosion_texture
    free_texture shelter_texture
    free_texture saucer_texture
    free_texture saucer_explosion_texture
    
    ; sound
    free_sound cannon_shot_sound
    free_sound alien_explosion_sound
    free_sound saucer_sound
    free_sound saucer_explosion_sound
    call Mix_CloseAudio

    ; misc
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

; ---------------------------------------------------------------------
;   MAIN END
; ---------------------------------------------------------------------

.main_end:
    xor eax, eax
    add rsp, 48
    pop rsi
    ret

; ---------------------------------------------------------------------
;   FUNCTIONS
; ---------------------------------------------------------------------

; inputs:
;   rcx = entities
;   rdx = end
; output:
;   rax = collided entity, rdx otherwise
check_cannon_shot_collision_func:
    mov rax, rcx
.loop:
    cmp byte [rax + entity.alive], false
    je .next
    mov ecx, [rax + entity.dstrect + SDL_Rect.x]
    cmp ecx, [cannon_shot + entity.dstrect + SDL_Rect.x]
    ja .next
    add ecx, [rax + entity.dstrect + SDL_Rect.w]
    cmp ecx, [cannon_shot + entity.dstrect + SDL_Rect.x]
    jbe .next
    mov ecx, [cannon_shot + entity.dstrect + SDL_Rect.y]
    add ecx, cannon_shot_height
    cmp ecx, [rax + entity.dstrect + SDL_Rect.y]
    jbe .next
    mov ecx, [rax + entity.dstrect + SDL_Rect.y]
    add ecx, [rax + entity.dstrect + SDL_Rect.h]
    cmp ecx, [cannon_shot + entity.dstrect + SDL_Rect.y]
    jbe .next
    mov byte [cannon_shot + entity.alive], false
    ret
.next:
    add rax, entity_size
    cmp rax, rdx
    jne .loop
    ret

move_aliens_down:
    mov rax, aliens
.loop:
    add dword [rax + entity.dstrect + SDL_Rect.y], 8
    add rax, entity_size
    cmp rax, aliens_end
    jne .loop
    ret

; inputs:
;   rcx = alien shot
;   rdx = animation timer
;   r8 = spawn timer
;   r9 = explosion
move_animate_alien_shot_func:
    ; move
    inc dword [rcx + entity.dstrect + SDL_Rect.y]
    cmp dword [rcx + entity.dstrect + SDL_Rect.y], screen_height - alien_shot_height
    jbe .move_end
    mov byte [rcx + entity.alive], false
    mov eax, [rcx + entity.dstrect + SDL_Rect.x]
    sub eax, (alien_shot_explosion_width - alien_shot_width) / 2
    mov [r9 + entity.dstrect + SDL_Rect.x], eax
    mov dword [r9 + entity.dstrect + SDL_Rect.y], screen_height - alien_shot_explosion_height
    mov byte [r9 + entity.alive], true
    mov byte [r9 + entity.lifetime], explosion_lifetime
    mov word [r8], alien_shot_spawn_timer_reset_value
    jmp .animate_end
.move_end:

    ; animate
    dec byte [rdx]
    jnz .animate_end
    mov byte [rdx], alien_shot_animation_timer_reset_value
    add dword [rcx + entity.srcrect + SDL_Rect.x], alien_shot_width
    cmp dword [rcx + entity.srcrect + SDL_Rect.x], alien_shot_width * 4
    jne .animate_end
    mov dword [rcx + entity.srcrect + SDL_Rect.x], 0
.animate_end:

    ret

; inputs:
;   rcx = alien shot
;   rdx = animation timer
spawn_random_alien_shot_func:
    mov r8, rdx ; save animation timer
.update_random_column:
    inc byte [random_column_table_cursor]
    cmp byte [random_column_table_cursor], aliens_column_count
    jne .get_random_column
    mov byte [random_column_table_cursor], 0
.get_random_column:
    movzx rax, byte [random_column_table_cursor]
    movzx rax, byte [random_column_table + rax]
    mov rdx, entity_size
    mul rdx
    add rax, aliens
.check_alien:
    cmp byte [rax + entity.alive], true
    je .alien_found
    add rax, aliens_column_count * entity_size
    cmp rax, aliens_end
    jb .check_alien
    jmp .update_random_column
.alien_found:
    mov rdx, r8 ; animation timer
    mov r8, rax ; alien
    call spawn_alien_shot
    ret

; inputs:
;   rcx = alien shot
;   rdx = animation timer
;   r8 = alien
spawn_alien_shot:
    mov eax, [r8 + entity.dstrect + SDL_Rect.w]
    sub eax, alien_shot_width
    sar eax, 1
    add eax, [r8 + entity.dstrect + SDL_Rect.x]
    mov [rcx + entity.dstrect + SDL_Rect.x], eax
    mov eax, [r8 + entity.dstrect + SDL_Rect.y]
    add eax, [r8 + entity.dstrect + SDL_Rect.h]
    mov [rcx + entity.dstrect + SDL_Rect.y], eax
    mov byte [rcx + entity.alive], true
    mov byte [rdx], alien_shot_animation_timer_reset_value
    mov dword [rcx + entity.srcrect + SDL_Rect.x], 0
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
    mov r9d, 24
    mov r11b, aliens_column_count
.loop:
    set_entity_texture r10, rcx
    set_entity_srcrect r10, 0, 0, edx, alien_height
    set_entity_dstrect r10, r9d, r8d, edx, alien_height
    mov byte [r10 + entity.alive], true
    mov byte [r10 + entity.lifetime], infinite
    add r10, entity_size
    add r9d, 16
    dec r11b
    jnz .loop
    add rsp, 40
    ret

; input: rcx = entity
render_entity_func:
    sub rsp, 40
    cmp byte [rcx + entity.alive], false
    je .end
    cmp byte [rcx + entity.lifetime], infinite
    je .render
    cmp byte [rcx + entity.lifetime], 0
    je .end
    dec byte [rcx + entity.lifetime]
    cmp byte [rcx + entity.lifetime], 0
    jne .render
    mov byte [rcx + entity.alive], false
    jmp .end
.render:
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

; ---------------------------------------------------------------------
;   DATA
; ---------------------------------------------------------------------

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
    db "Space Invaders ASM", 0
space_texture_file:
    db "res/space.png", 0
cannon_texture_file:
    db "res/cannon.png", 0
cannon_shot_texture_file:
    db "res/cannon_shot.png", 0
cannon_shot_explosion_texture_file:
    db "res/cannon_shot_explosion.png", 0
large_alien_texture_file:
    db "res/large_alien.png", 0
medium_alien_texture_file:
    db "res/medium_alien.png", 0
small_alien_texture_file:
    db "res/small_alien.png", 0
alien_explosion_texture_file:
    db "res/alien_explosion.png", 0
alien_shot1_texture_file:
    db "res/alien_shot1.png", 0
alien_shot2_texture_file:
    db "res/alien_shot2.png", 0
alien_shot3_texture_file:
    db "res/alien_shot3.png", 0
alien_shot_explosion_texture_file:
    db "res/alien_shot_explosion.png", 0
shelter_texture_file:
    db "res/shelter.png", 0
saucer_texture_file:
    db "res/saucer.png", 0
saucer_explosion_texture_file:
    db "res/saucer_explosion.png", 0
cannon_shot_sound_file:
    db "res/cannon_shot.wav", 0
alien_explosion_sound_file:
    db "res/alien_explosion.wav", 0
saucer_sound_file:
    db "res/saucer.wav", 0
saucer_explosion_sound_file:
    db "res/saucer_explosion.wav", 0
space_key_state:
    db 0
aliens_alive_count:
    db aliens_count
current_alien:
    dq aliens - entity_size
aliens_moving_direction:
    db right
saucer_spawn_timer:
    dw saucer_spawn_timer_reset_value
saucer_moving_timer:
    db saucer_moving_timer_reset_value
saucer_moving_direction:
    db right
cannon_shot_number:
    db -1
alien_shot1_spawn_timer:
    dw alien_shot_spawn_timer_reset_value
alien_shot2_spawn_timer:
    dw alien_shot_spawn_timer_reset_value * 2
alien_shot3_spawn_timer:
    dw alien_shot_spawn_timer_reset_value * 3
alien_shot1_animation_timer:
    db alien_shot_animation_timer_reset_value
alien_shot2_animation_timer:
    db alien_shot_animation_timer_reset_value
alien_shot3_animation_timer:
    db alien_shot_animation_timer_reset_value
random_column_table:
    db 0, 4, 6, 1, 5, 2, 7, 10, 9, 3, 8
random_column_table_cursor:
    db -1

section .bss
window:
    resq 1
renderer:
    resq 1
space_texture:
    resq 1
cannon_texture:
    resq 1
cannon_shot_texture:
    resq 1
cannon_shot_explosion_texture:
    resq 1
large_alien_texture:
    resq 1
medium_alien_texture:
    resq 1
small_alien_texture:
    resq 1
alien_explosion_texture:
    resq 1
alien_shot1_texture:
    resq 1
alien_shot2_texture:
    resq 1
alien_shot3_texture:
    resq 1
alien_shot_explosion_texture:
    resq 1
shelter_texture:
    resq 1
saucer_texture:
    resq 1
saucer_explosion_texture:
    resq 1
cannon_shot_sound:
    resq 1
alien_explosion_sound:
    resq 1
saucer_sound:
    resq 1
saucer_explosion_sound:
    resq 1
cannon:
    resb entity_size
cannon_shot:
    resb entity_size
cannon_shot_explosion:
    resb entity_size
aliens:
    resq entity_size * aliens_count
alien_explosion:
    resq entity_size
alien_shot1:
    resq entity_size
alien_shot2:
    resq entity_size
alien_shot3:
    resq entity_size
alien_shot1_explosion:
    resq entity_size
alien_shot2_explosion:
    resq entity_size
alien_shot3_explosion:
    resq entity_size
shelters:
    resq entity_size * shelters_count
saucer:
    resq entity_size
saucer_explosion:
    resq entity_size
event:
    resb SDL_Event_size
keyboard_state:
    resq 1
ticks:
    resd 1
saucer_sound_channel:
    resd 1
