global  _start

%define pc r14
%define w  r13

%include 'src/io_library.asm'
%include 'src/macroses.asm'
%include 'src/data.asm'
%include 'src/dictionary.asm'

section .data
	program_stub  : dq 0
	xt_interpreter: dq .interpreter
	.interpreter  : dq interpreter_loop

; Compiler flag
	was_branch	  : db 0
; Interpreter Strings
	i_unknow_word : db 'Error: unknow word', 0
section .text


_start:
	call f_ini
	mov pc, xt_interpreter
	jmp next	

next:
	mov w, pc
	add pc, word_size
	mov w, [w]
	jmp [w]


interpreter_loop:
	cmp byte[state], 1
	je  compiler_loop	

	call read_word
	test dx, dx
	jz   interpreter_loop
	
	mov  rdi, rax
	call find_word
	test rax, rax
	jz   .skip
	  mov  rdi, rax
	  call cfa
	  mov [program_stub], rax
	  mov pc, program_stub
	  jmp next
	.skip:
	  call parse_int
	  test rdx, rdx
	  jz   unknow
	    fpush rax
	    jmp interpreter_loop
	jmp interpreter_loop 
	
	

compiler_loop:
	cmp  byte[state], 1
	jne  interpreter_loop
	
	call read_word
	test dx, dx
	jz   compiler_loop
	
	mov  rdi, rax
	call find_word
	test rax, rax
	jz   .isNumber	
	  mov  rdi, rax
	  call cfa

	  ; Check command's flag. Immediate commands must be interpreted.
	  cmp  byte[rax - 1], 1
	  jne  .notImmediate
		mov  w, rax
		mov  [program_stub], rax
		mov  pc, program_stub
		jmp  next
	  .notImmediate:
		mov  qword[here], rax
		add  here,   word_size
		
		; Check xt_word's flag. Set 'last command was branch' flag.
		cmp  byte[rax - 1], 2
		sete byte[was_branch]
	
		jmp  compiler_loop
	.isNumber:
	  call parse_int
	  test rdx, rdx
	  jz   unknow
	  
	  cmp byte[was_branch], 1
	  jne .let
		mov [here], rax
		mov byte[was_branch], 0
		add here, word_size
	    jmp compiler_loop
	  .let:
		mov qword[here], xt_lit
		add here, word_size
		mov [here], rax
		add here, word_size
	jmp compiler_loop		


unknow:
	mov  rdi, i_unknow_word
	call print_string
	call print_newline
	mov  pc,  xt_interpreter
	jmp next

exit:
	xor edi, edi
	mov rax, 60
	syscall
