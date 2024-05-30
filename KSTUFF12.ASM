cseg    segment para public 'code'

                        assume cs:cseg

                        include kstuff12.def

                        org     100h

start:
                        jmp     init

root            db      "\", 0
tsr_active      db      0
hotkey_pressed  db      0
just_toggled    db      0
pause           db      0
VideoBase       dw      (?)
msg_header      db      CR, LF, "KSTUFF Version 1.2a, (c) Colin Wilcox - March 1994", CR, LF, "$"
msg_installed   db      CR, LF, "KSTUFF has been installed.", CR, LF, "$"
msg_running     db      CR, LF, "KSTUFF is already running.", CR, LF, "$"
msg_syntax      db      CR, LF, "Usage : KSTUFF [/?] | [/U] | [<filename>]", CR, LF
                db      CR, LF, "        /?         - Display this help page.", CR, LF
                db              "        /U         - Remove KSTUFF from memory.", CR, LF
                db              "        <filename> - Key sequence file.", CR, LF, "$"
msg_err_get_dir db      CR, LF, "** Unable to get current directory.", CR, LF, "$"
msg_err_set_dir db      CR, LF, "** Unable to restore current directory.", CR, LF, "$"
msg_bad_params  db      CR, LF, "** Unknown parameters.", CR, LF, "$"
msg_too_many    db      CR, LF, "** Too many parameters.", CR, LF, "$"
msg_open_error  db      CR, LF, "** File open error.", CR, LF, "$"
msg_close_error db      CR, LF, "** File close error.", CR, LF, "$"
msg_read_error  db      CR, LF, "** File read error.", CR, LF, "$"
msg_too_big     db      CR, LF, "** File too big.", CR, LF, "$"
msg_removed     db      CR, LF, "KSTUFF has been removed.", CR, LF, "$"
msg_tsr_locked  db      CR, LF, "Unable to remove KSTUFF.", CR, LF, "$"
msg_no_filename db      CR, LF, "KSTUFF not installed - no file specified.", CR, LF, "$"

res_key_seg     dw      ?
res_clk_seg     dw      ?

temp_buffer     db      MAX_BUFFER_SIZE dup (?)
buffer          db      MAX_BUFFER_SIZE dup (?)
buffer_ptr      dw      0
buffer_size     dw      0
handle          dw      ?
fname           db      64 dup ('X')
directory       db      255 dup (?)
filesize        dw      ?
stack_marker    db      0
stack_msg       db      "Data", "$"

old_clock       label   dword
old_clk_offset  dw      ?
old_clk_segment dw      ?

old_keyboard    label   dword
old_key_offset  dw      ?
old_key_segment dw      ?

get_dir         proc    near

                push    ax
                push    dx
                push    si
                push    ds

                push    cs
                pop     ds
                mov     ah, DOS_GET_DIR
                mov     dl, 0
                mov     si, offset directory
                DOSINT

                jnc     got_dir_ok

                PRINT_STRING    msg_err_get_dir
                call    jump_to_dos

got_dir_ok:
                pop     ds
                pop     si
                pop     dx
                pop     ax

                ret

get_dir         endp

chdir           proc

                push    ax
                push    ds
                push    dx

                mov     ah, DOS_SET_DIR
                push    cs
                pop     ds
                mov     dx, offset root
                DOSINT
                mov     ah, DOS_SET_DIR
                mov     dx, offset directory
                DOSINT

                jnc     set_dir_ok

                PRINT_STRING msg_err_set_dir
                call    jump_to_dos

set_dir_ok:

                pop     dx
                pop     ds
                pop     ax

                ret

chdir           endp


save_buffer     proc    near

                push    es
                push    si
                push    ds
                push    di
                push    cx
                push    ax

                push    cs
                pop     ax

                mov     es, ax
                mov     si, offset cs:buffer
                mov     ds, ax
                mov     di, offset cs:temp_buffer
                mov     cx, cs:buffer_size

next_byte_to_save:

                lodsb
                stosb
                loop next_byte_to_save

                pop     ax
                pop     cx
                pop     di
                pop     ds
                pop     si
                pop     es

                ret

save_buffer     endp

reload_buffer   proc    near

                push    es
                push    si
                push    ds
                push    di
                push    ax

                push    cs
                pop     ax

                mov     es, ax
                mov     si, offset cs:temp_buffer
                mov     ds, ax
                mov     di, offset cs:buffer
                mov     cx, cs:buffer_size

next_byte_to_load:

                lodsb
                stosb
                loop    next_byte_to_load

                pop     ax
                pop     di
                pop     ds
                pop     si
                pop     ax

                ret

reload_buffer     endp


flush_kbuff    proc    near

               push    ax

buffer_loop:

                mov     ah, KEY_GET_STATUS
                KEYINT
                jz      buffer_empty

                mov     ah, KEY_READ_CHAR
                KEYINT
                jmp     buffer_loop

buffer_empty:

                pop     ax
                ret

flush_kbuff     endp

push_space      proc    near

                push    ax
                push    cx

wait_loop:

                mov     ah, KEY_PUSH_CHAR
                mov     ch, 0
                mov     cl, ' '
                KEYINT

                jc      wait_loop

                pop     cx
                pop     ax
                ret

push_space      endp

open_file       proc near

                push    ax
                push    dx

                mov     ah, DOS_OPEN_FILE
                mov     al, 0
                mov     dx, offset fname
                DOSINT
                jnc     open_ok

                PRINT_STRING    msg_open_error
                call    jump_to_dos

open_ok:
                mov     handle, ax
                pop     dx
                pop     ax
                ret

open_file       endp


close_file      proc near

                push    ax
                push    bx

                mov     ah, DOS_CLOSE_FILE
                mov     bx, handle
                DOSINT
                jnc     close_ok

                PRINT_STRING msg_close_error
                call    jump_to_dos

close_ok:
                pop     bx
                pop     ax
                ret

close_file      endp

read_file       proc near

                push    ax
                push    bx
                push    cx
                push    dx

                mov     ah, DOS_READ_FILE
                mov     bx, handle
                mov     cx, MAX_BUFFER_SIZE
                mov     dx, offset buffer
                DOSINT
                mov     buffer_size, ax

eof:
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                ret

read_file       endp

get_filename    proc    near

                push    cx
                push    es
                push    si
                push    di

                mov     cx, WORD PTR cs:[80h]
                xor     ch, ch
                push    cs
                pop     es
                mov     si, 82h
                mov     di, offset fname
nb2:
                lodsb
                stosb
                loop    nb2

end_of_line:
                mov     BYTE PTR ds:[di-1], 0
                pop     di
                pop     si
                pop     es
                pop     cx
                ret

get_filename    endp

remove          proc    near

                push    ax
                push    bx
                push    cx
                push    dx
                push    es

                xor     ax, ax
                mov     bx, KEY
                mov     cl, 2
                shl     bx, cl
                mov     es, ax
                mov     ax, es:[bx]

                push    ax
                mov     ax, es:[bx+2]
                mov     res_key_seg, ax
                push    ax
                pop     es
                pop     bx
                cmp     es:[bx-2], "WC"
                jnz     problem

                xor     ax, ax
                mov     bx, TIMER
                mov     cl, 2
                shl     bx, cl
                mov     es, ax
                mov     ax, es:[bx+2]
                mov     res_clk_seg, ax

                pop     es
                pop     dx
                pop     cx
                pop     bx
                pop     ax

                push    ax
                push    dx
                push    ds
                push    cs
                pop     ds
                push    es

                mov     ax, DOS_SET_VECTOR + KEY
                mov     es, res_key_seg
                mov     ds, es:old_key_segment
                mov     dx, es:old_key_offset
                DOSINT

                mov     ax, DOS_SET_VECTOR + TIMER
                mov     es, res_clk_seg
                mov     ds, es:old_clk_segment
                mov     dx, es:old_clk_offset
                DOSINT

                pop     es
                pop     ds
                pop     dx
                pop     ax

                PRINT_STRING msg_removed
                call    jump_to_dos

problem:
                PRINT_STRING msg_tsr_locked
                call    jump_to_dos

remove          endp

get_details     proc    near
                call    open_file
                call    read_file
                call    close_file
                call    save_buffer
                call    reload_buffer
                ret
get_details     endp

chk_filesize    proc    near

                push    ax
                push    bx
                push    cx
                push    dx

                mov     ax, 3d00h
                mov     dx, offset fname
                int     21h
                mov     bx, ax
                push    bx
                mov     ax, 4202h
                mov     cx, 0
                mov     dx, 0
                int     21h
                pop     bx
                push    ax
                mov     ah, 3eh
                int     21h
                pop     ax
                cmp     ax, MAX_BUFFER_SIZE
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                jbe     size_ok

                PRINT_STRING msg_too_big
                call    jump_to_dos

size_ok:
                ret
chk_filesize    endp

check_hotkey    proc    near

                push    ax
                mov     cs:hotkey_pressed, 0
                mov     ah, KEY_GET_FLAGS
                int     16h
                cmp     al, 3
                jnz     end_hkcheck
                mov     cs:hotkey_pressed, 1

end_hkcheck:
                pop     ax
                ret

check_hotkey    endp

CompileOver     proc    near

                push    es
                push    bx
                push    di
                push    ax

                mov     es, cs:VideoBase
                mov     bx, 3040
                mov     di, offset cs:stack_msg
                mov     cs:stack_marker, 0

next_char:
                mov     al, BYTE PTR cs:[di]
                cmp     al, BYTE PTR es:[bx]
                jnz     not_over_yet
                inc     cs:stack_marker
                inc     bx
                inc     bx
                inc     di
                cmp     cs:stack_marker, 4
                jnz     next_char

                mov     cs:pause, 0
                call    push_space

not_over_yet:
                pop     ax
                pop     di
                pop     bx
                pop     es

                ret
CompileOver     endp

                db      "CW"

new_keyboard    proc    near
                sti
                cmp     ah, KEY_READ_CHAR
                jz      ah00
                cmp     ah, KEY_GET_STATUS
                jz      ah01
                cmp     ah, KEY_EREAD_CHAR
                jz      ah10
                cmp     ah, KEY_EGET_STATUS
                jz      ah11
pass_key_on:
                cli
                jmp     DWORD PTR cs:old_keyboard

ah00:
ah10:
                cmp     cs:tsr_active, 1
                jnz     pass_key_on
                cmp     cs:pause, 1
                jz      pass_key_on

                push    bx
                mov     bx, cs:buffer_ptr
                cmp     bx, cs:buffer_size
                jz      no_chars

                add     bx, offset cs:buffer
                mov     al, BYTE PTR cs:[bx]
                inc     cs:buffer_ptr
                pop     bx
                cmp     al, PAUSE_CHAR
                jnz     chars_left

                dec     cs:buffer_ptr
                push    bx
                mov     bx, offset cs:buffer
                add     bx, cs:buffer_ptr
                mov     BYTE PTR cs:[bx], ' '
                pop     bx
                mov     cs:pause, 1
                mov     al, 'N'
                
chars_left:
                xor     ah, ah
                iret

no_chars:
                mov     cs:buffer_ptr, 0
                call    flush_kbuff
                call    reload_buffer
                pop     bx
                jmp     pass_key_on

ah01:
ah11:
                cmp     cs:tsr_active, 1
                jnz     pass_key_on

                cmp     cs:pause, 1
                jz      pass_key_on

                push    bx
                mov     bx, cs:buffer_ptr
                cmp     bx, cs:buffer_size
                jz      no_key_waiting

                add     bx, offset cs:buffer
                mov     al, BYTE PTR cs:[bx]
                xor     ah, ah

                pop     bx

                push    bp
                mov     bp, sp
                and BYTE PTR [bp+6], ZFLAG_RESET
                pop     bp
                iret

no_key_waiting:
                mov     cs:buffer_ptr, 0
                mov     cs:tsr_active, 0
                pop     bx
                push    bp
                mov     bp, sp
                or      BYTE PTR [bp+6], ZFLAG_SET
                pop     bp
                iret
new_keyboard    endp

new_timer       proc    near
                call    check_hotkey
                cmp     cs:hotkey_pressed, 1
                jnz     not_hotkey

                cmp     cs:just_toggled, 0
                jnz     leave_timer

                xor     cs:tsr_active, 1
                call    GetVideoMode
                inc     cs:just_toggled
                jmp     short leave_timer

not_hotkey:
                mov     cs:just_toggled, 0
leave_timer:
                cmp     cs:pause, 1
                jnz     old_clk
                call    CompileOver
old_clk:
                jmp     DWORD PTR cs:old_clock

new_timer       endp

GetVideoMode    proc    near
                push    ax
                mov     ah, VIDEO_GET_MODE
                VIDEOINT
                cmp     al, 7
                jnz     try_colour
                mov     cs:VideoBase, 0B000h
                jmp     got_mode_ok
try_colour:
                cmp     al, 2
                jz      got_colour
                cmp     al, 3
                jnz     bad_mode
got_colour:
                mov     cs:VideoBase, 0B800h
                jmp     got_mode_ok
bad_mode:
                mov     cs:VideoBase, -1
got_mode_ok:
                pop     ax
                ret

GetVideoMode    endp

UpperCmdLine    proc    near

                push    ax
                push    bx
                push    cx
                push    es
                push    si
                push    ds
                push    di

                push    cs
                pop     ax
                mov     es, ax
                mov     ds, ax
                mov     si, 82h
                mov     di, 82h

next_byte:
                lodsb
                call    UpperCase
                stosb
                cmp     al, CR
                jnz     next_byte

                pop     di
                pop     ds
                pop     si
                pop     es
                pop     cx
                pop     bx
                pop     ax
                ret
UpperCmdLine    endp

UpperCase       proc    near

                cmp     al, 'a'
                jb      try_ah
                cmp     al, 'z'
                ja      try_ah

                sub     al, 'a' - 'A'
try_ah:

                cmp     ah, 'a'
                jb      get_out
                cmp     ah, 'z'
                ja      get_out
                sub     ah, 'a' - 'A'

get_out:
                ret
UpperCase       endp

jump_to_dos     proc    near
                call    chdir
                mov     ax, DOS_TERMINATE
                DOSINT
jump_to_dos     endp

last_byte       db      "$"

init:
                assume ds:cseg

                call    get_dir
                cmp     BYTE PTR cs:[80h], 0
                jz      no_params

                call    UpperCmdLine
                mov     ax, WORD PTR cs:[82h]
                cmp     ax, '?/'
                jz      show_syntax
                cmp     ax, 'U/'
                jz      uninstall
                call    get_filename
                call    chk_filesize
                call    get_details
                jmp short proceed

no_params:
                PRINT_STRING msg_no_filename
                call    jump_to_dos

proceed:
                mov     ax, DOS_GET_VECTOR + KEY
                DOSINT
                cmp     WORD PTR es:[bx-2], "WC"
                jz      already_running

                mov     old_key_segment, es
                mov     old_key_offset, bx

                PRINT_STRING msg_header

                mov     ax, DOS_SET_VECTOR + KEY
                mov     dx, offset new_keyboard
                DOSINT

                mov     ax, DOS_GET_VECTOR + TIMER
                DOSINT
                mov     old_clk_segment, es
                mov     old_clk_offset, bx

                mov     ax, DOS_SET_VECTOR + TIMER
                mov     dx, offset new_timer
                DOSINT

                PRINT_STRING msg_installed

                mov     ax, DOS_KEEP
                mov     dx, (offset last_byte - offset cseg + 17)
                mov     cl, 4
                shr     dx, cl
                DOSINT

uninstall:
                call    remove
                call    jump_to_dos

show_syntax:
                PRINT_STRING msg_header
                PRINT_STRING msg_syntax
                call    jump_to_dos

unknown_param:

                PRINT_STRING msg_bad_params
                call    jump_to_dos

already_running:
                PRINT_STRING msg_running
                call    jump_to_dos

cseg    ends
end start










