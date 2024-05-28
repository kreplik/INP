; Autor reseni: Adam Nieslanik xniesl00

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64
; regs: r1-r19-r24-r25-r0-r4
;	r1 = login[i]
;       r19 = i	 
; DATA SEGMENT
                .data
login:          .asciiz "xniesl00"  ; sem doplnte vas login
cipher:         .space  17  ; misto pro zapis sifrovaneho loginu

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text
start:
		daddi r19, r0, 0

main:		
		
		lb r1, login(r19) 		
		slti r24, r1, 97 ; neni znak a-z
		daddi r25, r0, 1
		beq r24,r25, end
		slti r24, r1, 123 ; neni znak a-z
		beq r24,r0, end
		nop
		daddi r24, r19, 0	
		nop
		sll r24, r24, 31 ; modulo pro vyber operace
		srl r24, r24, 31 ; add/sub
		bne r24, r0, sub
       		 b add

add:
		daddi r25, r1, 14
		nop
		slti r24, r25, 123
		bne r24,r0, store
		nop
		daddi r25, r25, -122 ; po prekroceni 'z' pokracuje od 'a'
		daddi r25, r25, 96
		b store

sub:
		daddi r25, r1, -9
		nop
		slti r24, r25, 97
		beq r24,r0, store
		nop
		daddi r25, r25, 122 ; po prekroceni 'a' pokracuje od 'z'
		daddi r25, r25, -96
		b store

store:
		sb r25, cipher(r19) ; ulozeni sifrovaneho znaku do cipher
		daddi r19, r19, 1 ; i++
		jal main 
		nop
		b end

end:
		sb r0, cipher(r19)
		daddi r4, r0, cipher
		jal print_string
		syscall 0   ; halt
print_string:   ; adresa retezce se ocekava v r4

                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
				
