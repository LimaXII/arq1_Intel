	.model		small
	.stack

CR		equ		0dh
LF		equ		0ah 

	.data
FileName			db		8 dup (?)		; Nome do arquivo a ser lido.
FileBuffer			db		10 dup (?)		; Buffer de leitura do arquivo.
FileHandle			dw		0				; Handler do arquivo.
FileNameBuffer		db		150 dup (?)		; Buffer do nome do arquivo.

MsgPedeArquivo		db		"Nome do arquivo: ", 0
MsgErroOpenFile		db		"Erro na abertura do arquivo.", CR, LF, 0
MsgErroReadFile		db		"Erro na leitura do arquivo.", CR, LF, 0
MsgCRLF				db		CR, LF, 0

backup				db		0				; Variável para realizar alguns backups.
flag				db		0				; Variável para testar algumas flags de jump.
integer				db		0				; Variável para testar se é um inteiro válido.
frac				db		0				; Variável para testar se é um fracionário válido.
one_integer_number	db		3 dup (?)		; Variável para guardar um número inteiro.
one_frac_number		db		2 dup (?)		; Variável para guardar um número fracionário.

BufferWRWORD		db		10 dup (?)			;Variável interna usada na rotina printf_w

;Variaveis para uso interno na função sprintf_w
sw_n				dw		0
sw_f				db		0
sw_m				dw		0
	
	.code
	.startup    
;--------------------------------------------------------------------
;Função main
;--------------------------------------------------------------------	
	;GetFileName();
	call	GetFileName

	;printf ("\r\n");
	lea		bx,MsgCRLF
	call	printf_s

    ;if ( (ax=fopen(ah=0x3d, dx->FileName) ) ) {
	;	printf("Erro na abertura do arquivo.\r\n");
	;	exit(1);
	;}
	mov		al,0
	lea		dx,FileName
	mov		ah,3dh
	int		21h								;fopen FileName
	jnc		Continua1
	
	lea		bx,MsgErroOpenFile
	call	printf_s
	mov		al,1
	jmp		End_program
	
	.exit	1

    Continua1:

	;FileHandle = ax
	mov		FileHandle,ax		; Salva handle do arquivo

	;while(1) {
Again:
	;Lê um caractere do arquivo
	;if ( (ax=fread(ah=0x3f, bx=FileHandle, cx=1, dx=FileBuffer)) ) {
	;	printf ("Erro na leitura do arquivo.\r\n");
	;	fclose(bx=FileHandle)
	;	exit(1);
	;}
	mov		bx,FileHandle
	mov		ah,3fh
	mov		cx,1
	lea		dx,FileBuffer
	int		21h
	jnc		Continua2
	
	lea		bx,MsgErroReadFile
	call	printf_s	
	mov		al,1
	jmp		CloseAndFinal

Continua2:
	;if (ax==0)	fclose(bx=FileHandle);
	cmp		ax,0
	jne		Test_side
	mov		al,0
	jmp		CloseAndFinal

Test_side:
	;Testa se a flag vale 1.
	mov		backup, ah
	mov		ah, flag
	cmp		ah, 1h
	je		Continua3_frac
	jmp		Continua3_int

Continua3_int:
	mov		ah, backup
	;bl = FileBuffer[0]
	mov		bl,FileBuffer
	cmp		bl, CR
	je		New_line
	cmp		bl, LF
	je		New_line
	cmp		bl, '.'
	je		Deal_with_separator
	cmp		bl, ','
	je		Deal_with_separator
	cmp		bl, '0'
	jb		Again
	cmp		bl, '9'
	ja		Again
	cmp		bl, '9'
	jb		Found_a_Integer_Number
	jmp		Again

Continua3_frac:
	mov		ah, backup
	;Coloca 0 para a flag novamente.
	mov		backup, ah
	mov		ah, 0h
	mov		flag, ah
	mov		ah, backup

	;bl = FileBuffer[0]
	mov		bl,FileBuffer
	cmp		bl, CR
	je		New_line
	cmp		bl, LF
	je		New_line
	cmp		bl, '0'
	jb		Again
	cmp		bl, '9'
	ja		Again
	cmp		bl, '9'
	jb		Found_a_Frac_Number
	jmp		Again

Deal_with_separator:
	;Coloca 1 para a flag.
	mov		backup, ah
	mov		ah, 1h
	mov		flag, ah
	mov		ah, backup
	jmp		Again

New_line:
	jmp		Reset_numbers

Found_a_Integer_Number:
	jmp		Again

Found_a_Frac_Number:
	jmp		Again

Reset_numbers:
	;for (i=0; i<3; ++i)
	;	one_integer_number[i] = 0
	lea		di,one_integer_number
	mov		cx,3
	mov		ax,0
	rep 	stosw

	;for (i=0; i<2; ++i)
	;	one_frac_number[i] = 0
	lea		di,one_frac_number
	mov		cx,2
	mov		ax,0
	rep 	stosw

	jmp		Again

	
CloseAndFinal:
	;fclose(FileHandle->bx)
	mov		bx,FileHandle		; Fecha o arquivo
	mov		ah,3eh
	int		21h

End_program:
	.exit


;--------------------------------------------------------------------
;Função que pega um nome de arquivo digitado pelo usuário.
;       printf_s(char *s -> BX)
;--------------------------------------------------------------------
GetFileName	proc	near
    lea		bx,MsgPedeArquivo
	call	printf_s

    ;Lê uma linha do teclado
	;	FileNameBuffer[0]=100;
	;	gets(ah=0x0A, dx=&FileNameBuffer)
	mov		ah,0ah
	lea		dx,FileNameBuffer
	mov		byte ptr FileNameBuffer,100
	int		21h

	;Copia do buffer de teclado para o FileName
	;for (char *s=FileNameBuffer+2, char *d=FileName, cx=FileNameBuffer[1]; cx!=0; s++,d++,cx--)
	;	*d = *s;		
	lea		si,FileNameBuffer+2
	lea		di,FileName
	mov		cl,FileNameBuffer+1
	mov		ch,0
	mov		ax,ds						; Ajusta ES=DS para poder usar o MOVSB
	mov		es,ax
	rep 	movsb

	;	// Coloca o '\0' no final do string
	;	*d = '\0';
	mov		byte ptr es:[di],0
	ret

GetFileName	endp

;--------------------------------------------------------------------
;	Função que escreve uma string na tela.
;       printf_s(char *s -> BX)
;--------------------------------------------------------------------
printf_s	proc	near
	mov		dl,[bx]
	cmp		dl,0
	je		ps_1

	push	bx
	mov		ah,2
	int		21H
	pop		bx

	inc		bx		
	jmp		printf_s
		
ps_1:
	ret

printf_s	endp

;--------------------------------------------------------------------
;Função: Escreve o valor de AX na tela
;		printf("%
;--------------------------------------------------------------------
printf_w	proc	near
	; sprintf_w(AX, BufferWRWORD)
	lea		bx,BufferWRWORD
	call	sprintf_w
	
	; printf_s(BufferWRWORD)
	lea		bx,BufferWRWORD
	call	printf_s
	
	ret
printf_w	endp

;--------------------------------------------------------------------
;Função: Converte um inteiro (n) para (string)
;		 sprintf(string->BX, "%d", n->AX)
;--------------------------------------------------------------------
sprintf_w	proc	near
	mov		sw_n,ax
	mov		cx,5
	mov		sw_m,10000
	mov		sw_f,0
	
sw_do:
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
	mov		sw_n,dx
	
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
	dec		cx
	cmp		cx,0
	jnz		sw_do

	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:

	mov		byte ptr[bx],0
	ret		
sprintf_w	endp
;--------------------------------------------------------------------
;   Fim do programa.
;--------------------------------------------------------------------
		end