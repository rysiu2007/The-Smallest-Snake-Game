.686

.model flat, stdcall
option casemap : none

includelib "C:/masm32/lib/kernel32.lib"
includelib "C:/masm32/lib/user32.lib"

extrn HeapCreate@12:PROC
extrn HeapAlloc@12:PROC
extrn ExitProcess@4:PROC
extrn RegisterClassA@4:PROC
extrn CreateWindowExA@48:PROC
extrn ShowWindow@8:PROC
extrn SetTimer@16:PROC
extrn GetMessageA@16:PROC
extrn DispatchMessageA@4:PROC
extrn DefWindowProcA@16:PROC
extrn BeginPaint@8:PROC
extrn EndPaint@8:PROC
extrn InvalidateRect@12:PROC
extrn FillRect@12:PROC



.data 
     gamePlay BYTE 1
     flag BYTE 0
     score BYTE 0
     counter BYTE 0
     direction BYTE 28h
     
     lpPaintStruct DWORD 0
     hwnd DWORD 0
     tab DWORD 0
     player DWORD 0
     apples DWORD 0
     msg DWORD 0
 


.code
start:
    push 81920
    push 81920
    push 0
    call HeapCreate@12

    push 5600
    push 8
    push eax
    call HeapAlloc@12
    mov tab, eax
      
    ;apple map
    add eax,4096
    mov apples,eax

    ;player init
    add eax,16
    mov player,eax
    mov DWORD PTR [eax+8], 16
    mov DWORD PTR [eax+12], 16

    ;wndclass init
    add eax,16
    mov ebx, WindowProc
    mov DWORD PTR [eax+4], ebx
    mov DWORD PTR [eax+36], 41h
       
    push eax
    add eax,40
    mov lpPaintStruct, eax
    add eax,64
    mov msg,eax
    call RegisterClassA@4

    push 0h
    push 0h
    push 0h
    push 0h
    push 286
    push 262
    push 0
    push 0
    push 0C80000h
    push 0
    push 41h
    push 0
    call CreateWindowExA@48

    push eax
    mov hwnd,eax

    push 10
    push eax
    call ShowWindow@8

    push ebx
    push 200
    push 1
    push eax
    call SetTimer@16

    msgLoop:
        push 0
        push 0
        push 0
        push msg
        call GetMessageA@16

        push msg
        call DispatchMessageA@4

        xor bx,bx
        mov bl,gamePlay
        cmp bx,0
        jg msgLoop
        
    call ExitProcess@4
        
WindowProc:
    ;Stack pointer care
    push ebp
    mov ebp, esp
    
    mov eax, DWORD PTR [ebp+12]
    cmp ax, 000fh
    je PAINT
    cmp ax, 0113h
    je TIMER
    cmp ax, 0100h
    je KEYDOWN
    cmp ax, 0010h
    je CLOSE

    push DWORD PTR [ebp+20]
    push DWORD PTR [ebp+16]
    push DWORD PTR [ebp+12]
    push DWORD PTR [ebp+8]
    call DefWindowProcA@16
    
    jmp end2
    
    PAINT:
        ;PaintStruct
        mov esi, lpPaintStruct
        mov edi, esi
        
        push esi
        push hwnd
        call BeginPaint@8
        
        ;Draw the background
        push 2
        add edi, 8
        push edi
        push DWORD PTR [esi]
        call FillRect@12
        
        ;Draw the apple
        push 14
        push apples
        push DWORD PTR [esi]
        call FillRect@12

        mov ebx, -1
        mov edi, tab
        
        tailDrawLoop:
            ;Draw the tail
            push 1
            push edi
            push DWORD PTR [esi]
            call FillRect@12
            
            add edi, 64
            inc ebx
            
            cmp bl,score
            jl tailDrawLoop
        ;Draw the player
        push 0
        push player
        push [esi]
        call FillRect@12

        push lpPaintStruct
        push hwnd
        call EndPaint@8
        jmp end2
    TIMER:
        ;Sets the flag to 0, so the keydown can be activated only once per timer
        xor eax, eax
        mov flag, al
        mov al, counter
        cmp al, score
        jnl end21
        
        ;grows the snake's tail?        
        mov edi, tab
        shl eax, 6 
        add edi, eax
        shr eax, 6
        mov esi, player
        mov ecx, 4
        rep movsd
        inc al
        cmp al, score
        jne end21
        xor al, al
                
        end21:
            mov counter, al
            mov ebx, apples

            ;check if player touches the apple
            mov edx, player
            mov eax, DWORD PTR [edx]
            sub eax, DWORD PTR [ebx]
            jne end1
            mov eax, [edx+4]
            sub eax, [ebx+4]
            end1:
            
            jne MovePlayer
            mov al, score
            inc eax
            mov score, al

            ;Random apple generator
            ;Get random number in register edx and shift it so it is between 0 and 16 
            ;and then multiplied by 16 so it fits into the grid
            mov ecx, 2
            AppleRandLoop:
                @@:
                db 0Fh, 0C7h, 0FAh ; rdseed edx
                shr edx, 28
                shl edx, 4
                    
                ;Apply this random value to the X axis
                mov DWORD PTR [ebx], edx
                add edx, 16
                mov DWORD PTR [ebx+8], edx
                
                add ebx, 4
                dec ecx
                jne AppleRandLoop
                
            
            MovePlayer:
                ;Optimize
                xor eax, eax
                mov ecx, 2

                mov al, direction
                sub eax, 26h
                push eax
                and eax, 1
                cmp eax, 0
                pop eax
                jz vertical
                horizontal:
                    dec ecx
                    jmp end20
                vertical:
                    dec eax
                end20:
                    sal eax,4
                    mov ebx,player
                    dec ecx
                    jz ht
                vt:
                    add ebx, 4
                ht:
                    add [ebx], eax
                    add [ebx+8], eax
                    mov ecx, 2
                    mov esi, player
                ;Check if the player is in the boundaries
                LeftTopBoundaryCheck:
                    lodsd
                    cmp eax, 0
                    jl GameOver
                    dec ecx
                    jne LeftTopBoundaryCheck
                    mov ecx, 2
                DownRightBoundaryCheck:
                    lodsd
                    cmp eax, 256
                    jg GameOver
                    dec ecx
                    jne DownRightBoundaryCheck
                    jmp end5

            GameOver:
                mov gamePlay,0
            end5:
                push 0
                push 0
                push hwnd
                call InvalidateRect@12
        jmp end2
    KEYDOWN:
        mov al,flag
        cmp al, 0
        jne end2
        mov ebx, DWORD PTR [ebp+16]
        mov cl, direction
        cmp bl, 25h
        jl end2
        cmp bl, 28h
        jg end2
        sub cl, bl
        shl cl, 6
        cmp cl, 80h
        je end2
        mov direction, bl
        inc al
        mov flag,al
        jmp end2
    CLOSE:
        mov gamePlay, 0
    end2:
        pop ebp
        ret
    end start



