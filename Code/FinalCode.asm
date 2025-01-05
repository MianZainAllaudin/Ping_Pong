[org 0x100]
jmp start
; Constants
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
PADDLE_WIDTH    equ 20
PADDLE_COL_START equ 30
BLACK_ATTR      equ 0x07
WHITE_ATTR      equ 0x70
TIMER_INT       equ 1Ch
GAME_SPEED      equ 2
MAX_SCORE       equ 5
; Game state variables
ballRow         dw 23
ballCol         dw 40
ballDirUp       db 1
ballDirRight    db 1
paddleAPos      dw PADDLE_COL_START
paddleBPos      dw PADDLE_COL_START
scoreA          db '0'
scoreB          db '0'
playerTurn      db 1        ; 1 for Player A, 2 for Player B
tickCount       db 0
oldTimerISR     dd 0
gameActive      db 1
; String data
msgGameOver     db 'Game Over!Program terminated', 0
msgScoreA       db 'Player A ', 0
msgScoreB       db 'Player B ', 0
msgWinnerA      db 'Player A Wins!', 0
msgWinnerB      db 'Player B Wins!', 0
start
    ; Save old timer interrupt vector
    mov ax, 0
    mov es, ax
    mov ax, [esTIMER_INT4]
    mov [oldTimerISR], ax
    mov ax, [esTIMER_INT4+2]
    mov [oldTimerISR+2], ax
    ; Install new timer interrupt
    cli
    mov word [esTIMER_INT4], timer_handler
    mov [esTIMER_INT4+2], cs
    sti
    ; Initialize video mode
    mov ax, 0x0003
    int 0x10
    call init_game
game_loop
    call check_game_over
    cmp byte [gameActive], 0
    je exit_game
    call handle_input
    call draw_game_state
    ; Small delay
    mov cx, 0x1FFF
delay_loop
    loop delay_loop
    jmp game_loop
exit_game
    ; Clear screen first
    mov ax, 0x0003    
    int 0x10
    ; Set up video memory for messages
    mov ax, 0xB800
    mov es, ax
    ; Position for Game Over message (center screen)
    mov di, 12  160 + 30   ; Row 12, slightly left of center
    mov si, msgGameOver
    call write_string
    ; Move down two rows for winner message
    add di, 320             ; Move down 2 rows (2  160)
    sub di, 60              ; Recenter for shorter message
    ; Check who won
    mov al, [scoreA]
    sub al, '0'            ; Convert from ASCII
    cmp al, MAX_SCORE
    je show_winner_a
    mov si, msgWinnerB     ; If not A, then B won
    jmp show_final_winner
show_winner_a
    mov si, msgWinnerA
show_final_winner
    call write_string
    ; Now restore original timer interrupt
    mov ax, 0
    mov es, ax
    cli
    mov ax, [oldTimerISR]
    mov [esTIMER_INT4], ax
    mov ax, [oldTimerISR+2]
    mov [esTIMER_INT4+2], ax
    sti
    mov ax, 0x4C00
    int 0x21
timer_handler
    pusha
    push ds
    push es
    mov ax, cs
    mov ds, ax
    ; Only update ball position every GAME_SPEED ticks
    inc byte [tickCount]
    cmp byte [tickCount], GAME_SPEED
    jne timer_done
    mov byte [tickCount], 0
    call update_ball
    call check_collisions
timer_done
    pop es
    pop ds
    popa
    iret
handle_input
    ; Check for keyboard input
    mov ah, 1
    int 0x16
    jz input_done
    ; Get key
    mov ah, 0
    int 0x16
    ; ESC = exit game
    cmp al, 27 ; Scan Codes
    je set_game_inactive
    ; Check player turn and handle only arrow keys
    mov bl, [playerTurn]
    ; Left arrow
    cmp ah, 4Bh 
    je check_left_move
    ; Right arrow
    cmp ah, 4Dh
    je check_right_move
    jmp input_done
check_left_move
    cmp bl, 1          ; Player A's turn
    je move_paddle_a_left
    cmp bl, 2          ; Player B's turn
    je move_paddle_b_left
    jmp input_done
check_right_move
    cmp bl, 1          ; Player A's turn
    je move_paddle_a_right
    cmp bl, 2          ; Player B's turn
    je move_paddle_b_right
    jmp input_done
input_done
    ret
set_game_inactive
    mov byte [gameActive], 0
    ret
move_paddle_a_left
    cmp word [paddleAPos], 0
    jle input_done
    dec word [paddleAPos]
    ret
move_paddle_a_right
    mov ax, SCREEN_WIDTH
    sub ax, PADDLE_WIDTH
    cmp word [paddleAPos], ax
    jae input_done
    inc word [paddleAPos]
    ret
move_paddle_b_left
    cmp word [paddleBPos], 0
    jle input_done
    dec word [paddleBPos]
    ret
move_paddle_b_right
    mov ax, SCREEN_WIDTH
    sub ax, PADDLE_WIDTH
    cmp word [paddleBPos], ax
    jae input_done
    inc word [paddleBPos]
    ret
update_ball
    ; Update ball position based on current direction
    mov ax, [ballRow]
    mov bx, [ballCol]
    ; Vertical movement
    cmp byte [ballDirUp], 1
    jne move_down
    dec ax              ; Move up
    jmp check_horizontal
move_down
    inc ax              ; Move down
check_horizontal
    cmp byte [ballDirRight], 1
    jne move_left
    inc bx              ; Move right
    jmp finish_move
move_left
    dec bx              ; Move left    
finish_move
    mov [ballRow], ax
    mov [ballCol], bx
    ret
check_collisions
    ; Check wall collisions
    mov ax, [ballRow]
    ; Top wall collision (Player A's side)
    cmp ax, 1          ; It is set 1 to prevent hitting inside paddle
    je check_paddle_a_hit
    ; Bottom wall collision (Player B's side)
    cmp ax, 23
    je check_paddle_b_hit
    ; Side wall collisions
    mov ax, [ballCol]
    cmp ax, 0
    je side_collision
    cmp ax, SCREEN_WIDTH-1
    je side_collision
    ret
side_collision
    xor byte [ballDirRight], 1
    ret
missed_paddle_a
    ; Player B scores
    inc byte [scoreB]
    call reset_ball
    mov byte [playerTurn], 1    ; Activate A's paddle since ball starts from B going up
    ret
missed_paddle_b
    ; Player A scores
    inc byte [scoreA]
    call reset_ball
    mov byte [playerTurn], 1    ; It is set to 1 to activate A's paddle since ball starts from B
    ret
check_paddle_a_hit
    ; Check if ball hits paddle A
    mov bx, [ballCol]
    mov cx, [paddleAPos]
    add cx, PADDLE_WIDTH
    cmp bx, cx
    ja missed_paddle_a
    mov cx, [paddleAPos]
    cmp bx, cx
    jb missed_paddle_a
    ; Ball hit paddle A
    xor byte [ballDirUp], 1
    mov byte [playerTurn], 2    ; Switch to Player B's turn
    ret
check_paddle_b_hit
    ; Check if ball hits paddle B
    mov bx, [ballCol]
    mov cx, [paddleBPos]
    add cx, PADDLE_WIDTH
    cmp bx, cx
    ja missed_paddle_b
    mov cx, [paddleBPos]
    cmp bx, cx
    jb missed_paddle_b
    ; Ball hit paddle B
    xor byte [ballDirUp], 1
    mov byte [playerTurn], 1    ; Switch to Player A's turn
    ret
draw_game_state
    mov ax, 0xB800
    mov es, ax
    call clear_screen
    call draw_paddles
    call draw_ball
    call draw_scores
    ret
clear_screen
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720     ; Space with black background
    mov cx, 2000       ; 80x25 screen
    rep stosw
    ret
draw_scores
    mov ax, 0xB800
    mov es, ax
    ; Draw Player A text
    mov di, 2
    mov si, msgScoreA
    call write_string
    ; Draw Player A score
    mov al, [scoreA]
    mov ah, WHITE_ATTR
    mov [esdi], ax
    ; Draw Player B text
    mov di, 24  160 + 2
    mov si, msgScoreB
    call write_string
    ; Draw Player B score
    mov al, [scoreB]
    mov ah, WHITE_ATTR
    mov [esdi], ax
    ret
write_string ; Helper function to write a null-terminated string
    mov ah, WHITE_ATTR
.loop
    mov al, [si]
    cmp al, 0
    je .done
    mov [esdi], ax
    add di, 2
    inc si
    jmp .loop
.done
    ret
draw_paddles
    ; Draw paddle A (top row - row 0)
    mov ax, 0xB800
    mov es, ax
    xor di, di         ; Start at top row
    add di, [paddleAPos]
    shl di, 1          ; Convert to video memory offset
    mov cx, PADDLE_WIDTH
draw_paddle_a
    mov word [esdi], 0x7020    ; White background, space character
    add di, 2
    loop draw_paddle_a
    ; Draw paddle B (row 24)
    mov di, 160  24    ; Row 24 offset (24  160 bytes per row)
    add di, [paddleBPos]
    add di, [paddleBPos]   ; Add position twice since each character takes 2 bytes
    mov cx, PADDLE_WIDTH
draw_paddle_b
    mov word [esdi], 0x7020    ; White background, space character
    add di, 2
    loop draw_paddle_b
    ret
draw_ball
    mov ax, 0xB800
    mov es, ax
    ; Calculate ball position in video memory
    mov ax, [ballRow]
    mov bx, 160         ; 80 columns  2 bytes per character
    mul bx
    mov di, ax
    mov ax, [ballCol]
    shl ax, 1          ; Multiply by 2 for attribute
    add di, ax
    ; Draw ball as white star on black background
    mov word [esdi], 0x072A    ; Black background (07), star character (2A)
    ret
check_game_over
    ; Check if either player has reached MAX_SCORE points
    mov al, [scoreA]
    sub al, '0'
    cmp al, MAX_SCORE
    je game_over
    mov al, [scoreB]
    sub al, '0'
    cmp al, MAX_SCORE
    je game_over
    ret
game_over
    mov byte [gameActive], 0
    ; Clear the middle of the screen for messages
    mov ax, 0xB800
    mov es, ax
    ; Calculate center screen position (row 12, center of screen)
    mov di, 12  160 + 60    ; (12 rows down  160 bytes per row) + center offset
    ; Display Game Over message
    mov si, msgGameOver
    call write_string
    ; Move down 2 rows for winner message
    add di, 320              ; 2  160 bytes per row
    ; Check scores to determine winner
    mov al, [scoreA]
    sub al, '0'             ; Convert from ASCII
    cmp al, MAX_SCORE
    je player_a_wins
    ; Must be player B if not A
    mov si, msgWinnerB
    jmp show_winner
player_a_wins
    mov si, msgWinnerA
show_winner
    call write_string
    ret
reset_ball
    ; Reset ball to starting position (row 22, col 40)
    mov word [ballRow], 22      ; Just above bottom paddle
    mov word [ballCol], 40      ; Column 40
    mov byte [ballDirUp], 1     ; Always start moving up when reset
    mov byte [ballDirRight], 1  ; Moving right
    ret
init_game
    call clear_screen
    ; Initialize game state
    mov word [ballRow], 22
    mov word [ballCol], 40
    mov byte [ballDirUp], 1
    mov byte [ballDirRight], 1
    mov word [paddleAPos], PADDLE_COL_START
    mov word [paddleBPos], PADDLE_COL_START
    mov byte [scoreA], '0'
    mov byte [scoreB], '0'
    mov byte [playerTurn], 1    ; Start with Player A's turn
    mov byte [gameActive], 1
    call draw_game_state
    ret