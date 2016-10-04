;------------------------------------------------------------------------------;
;..............................................................................;
;..............................FORTH Interpreter...............................;
;.................................DICTIONARY...................................;
;..............................................................................;
;------------------------------------------------------------------------------;

;------------------------------------------------------------------------------;
;...LIST:......................................................................;
;....Dictonary Utils...........................................................;
;......1 find_word..........................................................59.;
;......2 cfa................................................................85.;
section .text

;..............................................................................;
;.............................UTIL FUNCTIONS...................................;

; Function		: find_word
; Parameters    : rdi -- pointer to parsing command
; Side effects  : unsaved: rax, rcx, rdx, rdi, rsi
; Returns		: rax -- address of found command's header
find_word:
	xor eax, eax
	mov rsi, [last_word] 
	
	.loop:
	  push rsi
	  push rdi
	  add  rsi, word_size 
	  call string_equals ; rax -- true/false
	  pop  rdi
	  pop  rsi	  
	  
	  test rax, rax
	  jnz  .finally
	  mov  rsi, [rsi]
	  test rsi, rsi
	  jnz  .loop

	xor eax, eax
    ret
  .finally:
	mov  rax, rsi
  ret

; Function		: cfa -- code from address
; Parameters	: rdi -- pointer to command's header
; Side effects  : unsaved: rax, rdi
; Returns		: rax -- pointer to command's implementation
cfa:
	xor eax, eax 
	add rdi, word_size 
	.skip:
	  mov al, byte[rdi]
	  test al, al
	  jz .finally
	  inc rdi 
	  jmp .skip
   .finally:
	add rdi, 2
	mov rax, rdi
  ret

;..............................................................................;
;...............................Forth commands.................................;
native '+', plus
	fpop rdi
	fpop
	add rax, rdi
	fpush rax
  jmp next

native '-', minus
	fpop rdi
	fpop
	sub rax, rdi
	fpush rax
  jmp next

native '*', multiply
	fpop rdi
	fpop
	imul rdi
	fpush rax
  jmp next

native '/', divide
	fpop rdi
	fpop
	xor edx, edx
	idiv rdi
	fpush rax
  jmp next

native '=', equals
	fpop rdi
	fpop 
	cmp rax, rdi
	sete al
	movzx eax, al
	fpush rax
  jmp next

native '<', less
	fpop rdi
	fpop
	cmp  rax, rdi
	setl al
	movzx eax, al
	fpush rax
  jmp next

colon '>', greater
	dq xt_swap
	dq xt_less
	dq xt_exit
 

native 'not', fnot
	fpop
	test  eax, eax
	setz  al
	movzx eax, al
	fpush rax
  jmp next

native 'and', fand
	fpop rdi
	fpop
	test  rax, rax
	setnz al
	jz	  .skip
	test  rdi, rdi
	setnz al
   .skip:
	movzx rax, al
	fpush rax
  jmp next

colon 'or', for
	dq xt_fnot
	dq xt_swap
	dq xt_fnot
	dq xt_fand
	dq xt_fnot
	dq xt_exit

native 'rot', rot
	call f_stack_size
	cmp  rax, 3*word_size
	jl   f_underflow
	mov  rax, qword[r15]
	mov  rdx, qword[r15 + word_size*2]
	mov  rcx, qword[r15 + word_size]
	mov  qword[r15], rdx
	mov  qword[r15 + word_size], rax
	mov  qword[r15 + word_size*2], rcx
  jmp next

native 'swap', swap
	call f_stack_size
	cmp  rax, 2*word_size
	jl   f_underflow
	mov  rax, qword[r15]
	mov  rdx, qword[r15 + word_size]
	mov  qword[r15], rdx
	add  r15, word_size
	mov  qword[r15], rax
	sub  r15, word_size
  jmp next

native 'dup', dup
	call f_stack_size
	cmp  rax, s_cap
	jge  f_overflow
	sub  r15, word_size
	mov  rdx, qword[r15 + word_size]
	mov  qword[r15], rdx
  jmp next

native 'drop', drop ; 0000-00-0000-000-----000-010101-0000
	call f_stack_size
	test rax, rax
	jz   f_overflow
	add  r15, word_size
  jmp next

native '.', s_print
	fpop rdi
	call print_int
	call print_newline
  jmp next

native '.S', sa_print
	push r14
	mov r14, [stc_e]
	.loop:
	  cmp  r15, r14
	  jg   .finally
	  mov  rdi, qword[r14]
	  call print_int
	  mov  rdi, ' '
	  call print_char
	  sub  r14, word_size
	jmp .loop
   .finally:
	call print_newline
	pop r14
  jmp next	

native 'emit', emit
	fpop rdi
	call print_char
  jmp next

native 'key', key
	xor   eax, eax
	call  read_char
	fpush rax
  jmp next

native 'number', number
	call read_word
	mov  rdi, rax
	call parse_int
	fpush rax
  jmp next

native 'mem', mem
	fpush ptr_forth_mem
  jmp next

native '!', m_write
	fpop  rdi
	cmp   rdi, forth_mem_s
	jl    f_memory_underflow
	cmp   rdi, forth_mem_e
	jge   f_memory_overflow

	fpop
	mov   qword[rdi], rax
  jmp next

native '@', m_read
	fpop  rdi
	cmp   rdi, forth_mem_s
	jl    f_memory_underflow
	cmp   rdi, forth_mem_e
	jge   f_memory_overflow

	fpush qword[rdi]
  jmp next

docol:
	mov byte[state], 2
	sub rstack, 8
	mov [rstack], pc
	add w, 8
	mov pc, w
	jmp next

exit_colon:
	mov byte[state], 0
	mov pc, [rstack]
	add rstack, 8
	jmp next

native '%', module
	fpop rdi
	fpop
	xor edx, edx
	idiv rdi
	fpush rdx
  jmp next

native ':', col, 1 
	mov  byte[state], 1
	call read_word

	;Create colon command header
	mov  rdi, [last_word]
	mov  qword[here], rdi		; last_word address
	mov  qword[last_word], here
	add  here, word_size
	
	mov  rsi, here				; colon command name
	mov  rdi, rax
	call string_copy
	mov  here, rdi
	inc  here
	
	mov  qword[here], docol		; colon impl. start
	add  here, word_size
	jmp  next
	
native ';', semicol, 1
	mov byte[state], 0
	mov qword[here], xt_exit
	add here, word_size
	jmp next
	
native 'lit', lit
	fpush qword[pc]
	add   pc, word_size
	jmp   next

native 'branch', branch, 2
	cmp  byte[state], 2
	je   .isColon
	mov  rdi, s_n_col_br
	call print_string
	call print_newline
	jmp  next

  .isColon:
	mov rax, qword[pc]
	inc rax
	mov rcx, word_size
	mul rcx
	add pc, rax
	jmp next

native 'branch0', branch0, 2
	cmp byte[state], 2
	je  .isColon
	mov  rdi, s_n_col_br
	call print_string
	call print_newline
	jmp  next
   
  .isColon:
	fpop
	test rax, rax
	jnz .finally
	jmp branch_impl

  .finally:
	add pc, word_size
	jmp next

native 'quit', quit
	jmp exit

native 'return', return
	jmp exit_colon

section .data
	last_word: dq link
	xt_docol : dq docol
	xt_exit  : dq exit_colon
