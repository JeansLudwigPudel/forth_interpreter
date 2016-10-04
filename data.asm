;------------------------------------------------------------------------------;
;..............................................................................;
;..............................FORTH INTERPRETER...............................;
;.................................ARCH SECTION.................................;
;------------------------------------------------------------------------------;

%define stack_capacity  2048
%define memory_capacity 65536
%define rstack			r12
%define here			rbx

%assign word_size 8
%assign s_cap stack_capacity*word_size
%assign m_cap memory_capacity*word_size

section .bss
; Reserved 2048 qw for stack. Stack's head pointer is r15.
	stc_s        : resq stack_capacity ; stack start

; Reserved 65536 qw for retun stack. Stack's head pointer is r12
	r_stc_s		 : resq memory_capacity

; Reserved 65536 qw for forth-machine memory.
	forth_mem_s  : resq memory_capacity
	ptr_forth_mem: resq 1
	forth_mem_e  : resq 1

; Reserved 65536 qw for forth-machine dictionary
	forth_dic	 : resq memory_capacity


section .data
	r_stc_e		 : dq r_stc_s + m_cap - word_size
	stc_e		 : dq stc_s   + s_cap - word_size
	state		 : dq 0	; 0 -- int, 1 -- compile, 2 -- int_colon

; Strings
	s_underflow  : db 'Error: stack underflow', 0
	s_overflow   : db 'Error: stack overflow', 0
	s_mem_err    : db 'Error: wrong memory address', 0
	s_n_col_br	 : db 'Error: branch are only for colon words', 0

section .text

;Forth interpreter's system functions
f_ini:
	lea r15, [stc_s   + s_cap]
	lea r12, [r_stc_s + m_cap]
	mov qword[forth_mem_e], forth_mem_s + m_cap
	mov qword[ptr_forth_mem], forth_mem_s
	mov here, forth_dic
  ret

f_underflow:
	mov  rdi, s_underflow
	call print_string
	call print_newline
  jmp interpreter_loop

f_overflow:
	mov  rdi, s_overflow
	call print_string
	call print_newline
  jmp interpreter_loop

f_memory_underflow:
f_memory_overflow:
	mov  rdi, s_mem_err
	call print_string
	call print_newline
  jmp interpreter_loop

f_stack_size: ; in bytes
	mov rax, [stc_e]
	add rax, word_size
	sub rax, r15
  ret

f_push:
	sub r15, word_size
	cmp r15, stc_s
	jl  f_overflow
	mov qword[r15], rdi
  ret
    
%macro fpush 1
	mov rdi, %1
	call f_push
%endmacro

%macro fpush 0
	call f_push
%endmacro 

f_pop:
	cmp r15, [stc_e]
	jg  f_underflow
	mov rax, qword[r15]
	add r15, word_size
  ret

%macro fpop 1
	call f_pop
	mov %1, rax
%endmacro

%macro fpop 0
	call f_pop
%endmacro

		
