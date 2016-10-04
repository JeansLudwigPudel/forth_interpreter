%define link 0		; 0 means end of dictionary


; Macro				: native;
; Parameters		: nothing;
; Action			: place previous link and redefine link to current;
%macro ln_create 0
  %%link: dq link
  %define link %%link
%endmacro


; Overrided implementation of macro native with 0-flag
%macro native 2
  native %1, %2, 0
%endmacro

; Macro				: native
; Parameters		: word_name - name of command, that will be parsed;
;					: id_name   - identification name, that is used to 
;								  indificate different parts of command 
;								  implementation: word's header, word's
;								  implementation;
;					: flags		- some system flags;
; Action			: create word's header
;
; example:
; "native '+', plus, 0" will be processed to:
; section .data
;  w_plus:  
;		dq prev_native_word 
;		db '+', 0 
;		db 0
;  xt_plus: dq plus_impl
;
; section .text
;	plus_impl:
%macro native 3 
  section .data
    w_  %+ %2:		
	  ln_create
	  db %1, 0
	  db %3
	xt_ %+ %2: dq %2 %+ _impl

  section .text		
	%2 %+ _impl:   ;label of word implementation
%endmacro



; Macro				: colon;(non-native commands)
; Parameters		: colon_word_name;
;					: colon_id_name;
;					: flags
; Action			: create colon-word's header
%macro colon 3
  section .data
	w_ %+ %2:
	  ln_create
	  db %1, 0
	  db %3
	xt_ %+ %2:
	  dq docol
%endmacro

; Overrided implementation of macro colon with 0-flag
%macro colon 2
  colon %1, %2, 0
%endmacro
