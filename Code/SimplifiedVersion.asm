[org 0x0100]
jmp start
oldTimer:dd 0
oldKbsir:dd 0
playerAx1: dw 60
playerAx2:dw 100
playerBx1:dw 3900
playerBx2:dw 3940
starX:dw 23
starY:dw 40
starPos:dw 0
startMov:dw 0   ; 0->up_right, 1->up_left, 2->down_right, 3->down_left 
playerTurn:dw 0 ; 0 for player A and 1 for player B
scorePlayerA:dw 0
scorePlayerB:dw 0
startGame:dw 0
tell:dw 0
gameOver:dw 0 

clrscr: 
push es
push ax
push di
mov ax, 0xb800
mov es, ax 
mov di, 0 
nextloc: 
mov word [es:di], 0x0720 
add di, 2 
cmp di, 4000 
    jne nextloc
pop di
pop ax
pop es
ret

printnum: 
push bp
mov bp, sp
push es
push ax
push bx
push cx
push dx
push di
mov ax, 0xb800
mov es, ax 
mov ax, [bp+4] 
mov bx, 10 
mov cx, 0 
nextdigit: 
mov dx, 0 
div bx 
add dl, 0x30 
push dx 
inc cx 
cmp ax, 0 
jnz nextdigit 
mov di, [bp+6] 
nextpos: pop dx 
mov dh, 0x1F 
mov [es:di], dx 
add di, 2 
loop nextpos 
pop di
pop dx
pop cx
pop bx
pop ax
pop es
pop bp
ret 4

printPaddle:
push bp
mov bp,sp
pusha
xor ax,ax
mov ax,0xb800
mov es,ax
mov si,[bp+6]
mov di,[bp+4]
mov ax,0xf020
l1:
mov [es:si],ax
add si,2
cmp si,di
  jne l1
popa
pop bp
ret 4

printStar:
push bp
mov bp,sp
push ax
push si
mov si,[bp+4]
mov ax,0xb800
mov es,ax
mov ax,0x072A
mov [es:si],ax
pop si
pop ax
pop bp
ret 2

kbisr:
push ax
in al,0x60
cmp al,0x1C
    jne leftpress
mov word[startGame],1
leftpress:
cmp word[playerTurn],0
        jne next
    cmp al,0x4B
        jne rightpress
    cmp word[playerAx1],0
        je ext
    sub word[playerAx1],2
    sub word[playerAx2],2
rightpress:
    cmp al,0x4D
        jne ext
    cmp word[playerAx2],160
        je ext
    add word[playerAx1],2
    add word[playerAx2],2

next:
cmp word[playerTurn],1
        jne ext
    cmp al,0x4B
        jne rightpress1
    cmp word[playerBx1],3840
        je ext
    sub word[playerBx1],2
    sub word[playerBx2],2
rightpress1:
    cmp al,0x4D
        jne ext
    cmp word[playerBx2],4000
        je ext
    add word[playerBx1],2
    add word[playerBx2],2

ext:
    mov al,0x20
    out 0x20,al ; EOI signal
    pop ax
    iret

timer:
push ax
push bx
push es
push si
cmp word[startGame],1
    jne near skipall
xor ax,ax
mov es,ax
call clrscr
push word[playerAx1]
push word[playerAx2]
call printPaddle
push word[playerBx1]
push word[playerBx2]
call printPaddle
; calculating starPos

mov ax,word[starX]
mov bx,80
mul bx
add ax,word[starY]
shl ax,1 ; multiply with two
mov word[starPos],ax

; first check whose turn is it?
cmp word[playerTurn],0
    jne chk2
;changing player turn

; first check if ball lies in boundry of paddle 
mov ax,word[starPos]
cmp ax,word[playerAx1]
    jnae scoreB
cmp ax,word[playerAx2]
    ja scoreB
;change turn
xor word[playerTurn],1
mov word[tell],1 
; now changing direction of bounce back
cmp word[startMov],0
    jne two
mov word[startMov],2
    jmp outtt
two:
mov word[startMov],3
    jmp outtt
scoreB:
cmp word[starPos],160
    jnb near outtt
mov word[starX],1
mov word[starY],40
cmp word[tell],1
    jne outtt
inc word[cs:scorePlayerB]
mov word[tell],0
mov word[startGame],0
jmp outtt

chk2:
; first check if ball lies in boundry of paddle

mov ax,word[starPos]
cmp ax,word[playerBx1]
    jnae scoreA
cmp ax,word[playerBx2]
    ja scoreA
;change turn
xor word[playerTurn],1
mov word[tell],1 
; now changing direction of bounce back
cmp word[startMov],2
    jne two1
mov word[startMov],0
    jmp outtt
two1:
mov word[startMov],1
    jmp outtt
scoreA:
cmp word[starPos],3840
    jna outtt
mov word[starX],23
mov word[starY],40
cmp word[tell],1
    jne outtt
inc word[cs:scorePlayerA]
mov word[tell],0
mov word[startGame],0

outtt:
; 0->up_right, 1->up_left, 2->down_right, 3->down_left 
n0:
cmp word[startMov],0
    jne n1
cmp word[starY],80
    jne here
    mov word[startMov],1
    jmp n1
here:
inc word[starY]
dec word[starX]
n1:
cmp word[startMov],1
    jne n2
cmp word[starY],0
    jne here1
    mov word[startMov],0
    jmp n0
here1:
dec word[starY]
dec word[starX]
n2:
cmp word[startMov],2
    jne n3
cmp word[starY],80
    jne here2
    mov word[startMov],3
    jmp n3
here2:
inc word[starY]
inc word[starX]
n3:
cmp word[startMov],3
    jne ending
cmp word[starY],0
    jne here3
    mov word[startMov],2
    jmp n2
here3:
dec word[starY]
inc word[starX]

ending:
; calculating starPos

mov ax,word[starX]
mov bx,80
mul bx
add ax,word[starY]
shl ax,1 ; multiply with two

mov word[starPos],ax
push word[starPos]
call printStar

mov ax,320
push ax
push word[scorePlayerA]
call printnum

mov ax,3680
push ax
push word[scorePlayerB]
call printnum

cmp word[scorePlayerA],5
    jne ckhnext
    mov word[gameOver],1
ckhnext:
cmp word[scorePlayerB],5
    jne skipall
    mov word[gameOver],1
skipall:
mov al,0x20
out 0x20,al ; EOI signal
pop si
pop es
pop bx
pop ax
    iret

start:
xor ax,ax
mov es,ax
mov bx,word[es:9*4]
mov word[cs:oldKbsir],bx
mov bx,word[es:9*4+2]
mov word[cs:oldKbsir+2],bx

mov bx,word[es:8*4]
mov word[cs:oldTimer],bx
mov bx,word[es:8*4+2]
mov word[cs:oldTimer+2],bx
cli 
mov word[es:9*4], kbisr 
mov [es:9*4+2], cs
mov bx,word[es:8*4]
mov word[cs:oldTimer],bx
mov word[es:8*4],timer
mov [es:8*4+2],cs 
sti
l2: 
cmp word[gameOver],1
    jne l2
endOfGame:
call clrscr
mov ax, [cs:oldKbsir]        
mov bx, [cs:oldKbsir+2] 
mov si, [cs:oldTimer]        
mov di, [cs:oldTimer+2]      
cli                   
    mov [es:9*4], ax         
    mov [es:9*4+2], bx
    mov [es:8*4], si         
    mov [es:8*4+2], di      
    sti  
mov ax,0x4c00
int 21h