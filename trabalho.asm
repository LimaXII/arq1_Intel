	.model		small
	.stack

CR		equ		0dh
LF		equ		0ah 

	.data
FileName			db		8 dup (?)		; Nome do arquivo a ser lido.
Random				db		4 dup (?)		; Essa variável vai ser alocada dps.
FileType			db		".res", 0		; Tipo do arquivo.
Count_file			dw		0				; Variável que vai guardar o fim do nome do arquivo.
FileBuffer			db		10 dup (?)		; Buffer de leitura do arquivo.
FileHandle			dw		0				; Handler do arquivo.
FileHandleDst		dw		0				; Handler do arquivo de saída.
FileNameBuffer		db		150 dup (?)		; Buffer do nome do arquivo.

MsgPedeArquivo		db		"Nome do arquivo: ", 0
MsgErroOpenFile		db		"Erro na abertura do arquivo.", CR, LF, 0
MsgErroReadFile		db		"Erro na leitura do arquivo.", CR, LF, 0
MsgErroCreateFile	db		"Erro na criação do arquivo.", CR, LF, 0
MsgErroWriteFile	db		"Erro na escrita do arquivo.", CR, LF, 0
MsgCRLF				db		CR, LF, 0

backup				db		0				; Variável para realizar alguns backups.
flag				db		0				; Variável para testar algumas flags de jump.
integer				db		0				; Variável para testar se é um inteiro válido.
frac				db		0				; Variável para testar se é um fracionário válido.
one_integer_number	db		3 dup (?)		; Variável para guardar um número inteiro.
one_frac_number		db		2 dup (?)		; Variável para guardar um número fracionário.
int_sig				db		0				; Número significativo de inteiros.
real_int_addres		dw		0				; Endereço do atual digito inteiro
integer_flag		db		0				; Flag para a parte inteira.
frac_sig			db		0				; Número significativo de fracionários.
real_frac_addres	dw		0				; Endereço do atual digito fracionário.
frac_flag			db		0				; Flag para a parte fracionária.

final_int_number	dw		100 dup (?)		; Variável que irá guardar todos os possíveis números inteiros.
final_int_count		dw		0				; Variável para contar a posição do vetor de inteiros.
final_frac_number	dw		100 dup (?)		; Variável que irá guardar todos os possíveis números fracionários.
final_frac_count	dw		0				; Variável para contar a posição do vetor de fracionários.

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
	int		21h				;fopen FileName
	jnc		Continua1
	
	; Printa um erro na tela.
	lea		bx,MsgErroOpenFile
	call	printf_s
	mov		al,1
	jmp		End_program
	
	; Finaliza o programa.
	.exit	1

Continua1:
	;FileHandle = ax
	mov		FileHandle,ax	; Salva handle do arquivo

	; Backup na pilha.
	push	cx
	push	bx

	mov 	cx, 100
	mov 	bx, 0
	; Seta o vetor de inteiros como FFFFh.
Set_int_vetloop:
	mov 	final_int_number[bx], 0FFFFh
	inc 	bx
	loop 	Set_int_vetloop

	mov 	cx, 100
	mov 	bx, 0
	; Seta o vetor de fracionários como FFFFh.
Set_frac_vetloop:
	mov 	final_frac_number[bx], 0FFFFh
	inc 	bx
	loop 	Set_int_vetloop
	
	; Retira o backup da pilha.
	pop		bx
	pop     cx

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
	; Caso não ocorra erro na leitura, continua.
	jnc		Continua2
	
	; Caso ocorra erro na leitura.
	lea		bx,MsgErroReadFile
	call	printf_s	
	mov		al,1
	; Fecha tudo.
	jmp		CloseAndFinal

Continua2:
	;if (ax==0)	fclose(bx=FileHandle);
	; Se ax == 0, significa que nenhum byte foi lido.
	cmp		ax,0
	; Caso ax != 0, continua.
	jne		Test_side
	; Caso ax == 0, fecha tudo.
	mov		al,0
	jmp		CloseAndFinal

Test_side:
	;Testa se a flag vale 1.
	mov		backup, ah
	mov		ah, flag
	cmp		ah, 1h
	je		Continua3_frac
	jmp		Continua3_int

Again_mid_jump:
	jmp		Again

Continua3_int:
	mov		ah, backup
	;bl = FileBuffer[0]
	mov		bl,FileBuffer
	cmp		bl, CR
	je		New_line
	cmp		bl, LF
	je		New_line
	cmp		bl, 2Eh
	je		Deal_with_separator
	cmp		bl, 2Ch
	je		Deal_with_separator
	cmp		bl, 0h
	jb		Again
	cmp		bl, 9h
	ja		Again
	cmp		bl, 9h
	jb		Found_a_Integer_Number_mid_jump
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
	cmp		bl, 0h
	jb		Again_mid_jump
	cmp		bl, 9h
	ja		Again_mid_jump
	cmp		bl, 9h
	jb		Found_a_Frac_Number
	jmp		Again

Deal_with_separator:
	;Coloca 1 para a flag.
	mov		backup, ah
	mov		ah, 1h
	mov		flag, ah
	mov		ah, backup
	jmp		Again

Found_a_Integer_Number_mid_jump:
	jmp		Found_a_Integer_Number

New_line:
	lea		bx, one_integer_number
	call 	atoi
	call	check_integer_number
	lea		bx, one_frac_number
	call	atoi
	call	check_frac_number

	cmp		integer_flag, 1h
	je		Next_step
	jmp		End_line

Next_step:
	cmp		frac_flag, 1h
	je      Numbers_OK
	jmp		End_line

End_line:
	jmp		Reset_numbers

Numbers_OK:
	push	bx
	mov		bx, final_int_count
	mov		final_int_count[bx], ax
	mov		bx, final_frac_count
	mov		final_frac_count[bx], cx
	pop		bx
	jmp		Reset_numbers

Found_a_Integer_Number:
	push	bx
	mov		bx, 0
	mov		al, bl
	mov		bl,int_sig	
	mov		one_integer_number[bx],al
	inc		int_sig 
	pop		bx
	jmp		Again

Found_a_Frac_Number:
	push	bx
	mov		bx, 0
	mov		al, bl
	mov		bl,frac_sig	
	mov		one_frac_number[bx],al
	inc		int_sig 
	inc		frac_sig 
	pop		bx
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

	mov		int_sig, 0h
	mov		frac_sig, 0h

	jmp		Again
	
CloseAndFinal:
	;fclose(FileHandle->bx)
	mov		bx,FileHandle		; Fecha o arquivo
	mov		ah,3eh
	int		21h

Create_file:
	call	GetFileDestName
	lea		bx, FileName
	call	printf_s
	lea		dx,FileName
	call	fcreate
	mov		FileHandleDst,bx
	jnc		Second_part
	lea		bx, MsgErroCreateFile
	call	printf_s

Second_part:
	mov		bx,FileHandleDst
	call	setChar	
	jnc		Second_part

	;printf ("Erro na escrita....;)")
	;fclose(FileHandleSrc)
	;fclose(FileHandleDst)
	;exit(1)
	lea		bx, MsgErroWriteFile
	call	printf_s	
	mov		bx,FileHandleDst		;Fecha arquivo destino
	call	fclose

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
	mov		Count_file, di
	mov		byte ptr es:[di],0
	ret

GetFileName	endp

;--------------------------------------------------------------------
;   Cria o nome do arquivo destino.
;	O nome do arquivo destino segue o mesmo do arquivo de entrada.
;	Adiciona .res ao final, como extensão.
;--------------------------------------------------------------------
GetFileDestName proc	near

; Procura um '.' na string do arquivo de entrada.
Put_extension:
	mov		cx, 9
	mov		bx, 0
Loop_ext:
	cmp		FileName[bx], 2eh
	je		Put_extension2
	inc		bx
	loop	Loop_ext
	jmp		Put_extension3

; Caso ache um '.', sobrescreve .res na extensão original do arquivo.
Put_extension2:
	inc		bx
	mov		FileName[bx], 72h
	inc		bx
	mov		FileName[bx], 65h
	inc		bx
	mov		FileName[bx], 73h
	jmp		End_GetFileDestName

; Caso não ache '.', adiciona .res no fim do arquivo.
Put_extension3:
	mov     di, Count_file ; Variável que guarda a posição do último elemento do FileName.
    lea     si, FileType
    mov     cx, 5
    rep     movsb  
	jmp		End_GetFileDestName

; Retorna da função.
End_GetFileDestName:
	ret
GetFileDestName  endp

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
;Função:Converte um ASCII-DECIMAL para HEXA
;Entra: (S) -> DS:BX -> Ponteiro para o string de origem
;Sai:	(A) -> AX -> Valor "Hex" resultante
;Algoritmo:
;	A = 0;
;	while (*S!='\0') {
;		A = 10 * A + (*S - '0')
;		++S;
;	}
;	return
;--------------------------------------------------------------------
atoi	proc near
	;A = 0;
	mov		ax,0		
atoi_2:
	;while (*S!='\0') {
	cmp		byte ptr[bx], 0
	jz		atoi_1
	;A = 10 * A
	mov		cx,10
	mul		cx
	;A = A + *S
	mov		ch,0
	mov		cl,[bx]
	add		ax,cx
	;A = A - '0'
	sub		ax,'0'
	;++S
	inc		bx	
	;}
	jmp		atoi_2
atoi_1:
	; return
	ret
atoi	endp
;--------------------------------------------------------------------
;Função:Checa se o número inteiro recebido é válido.
;Entra: (S) -> DS:AX -> Número inteiro
;Sai:	(A) -> DS:AX -> Número inteiro
;Seta a flag de inteiro como válida.
;--------------------------------------------------------------------
check_integer_number	proc near
checking_integer:
	cmp 	ax, 0h
	jb		invalid_integer
	cmp		ax, 1F3h
	ja		invalid_integer
	mov		integer_flag, 1h

invalid_integer:
	mov		integer_flag, 0h

check_integer_number endp

;--------------------------------------------------------------------
;Função:Checa se o número fracionário recebido é válido.
;Entra: (S) -> DS:AX -> Número fracionário
;Sai:	(A) -> DS:CX -> Número fracionário
;Seta a flag de fracionário como válida.
;--------------------------------------------------------------------
check_frac_number	proc near
checking_frac:
	mov		cx,ax
	cmp 	cx, 0h
	jb		invalid_frac
	cmp		cx, 63h
	ja		invalid_frac
	mov		frac_flag, 1h

invalid_frac:
	mov		frac_flag, 0h	

check_frac_number endp

;--------------------------------------------------------------------
;Função Cria o arquivo cujo nome está no string apontado por DX
;		boolean fcreate(char *FileName -> DX)
;Sai:   BX -> handle do arquivo
;       CF -> 0, se OK
;--------------------------------------------------------------------
fcreate	proc	near
	mov		cx,0
	mov		ah,3ch
	int		21h
	mov		bx,ax
	ret

fcreate	endp
;--------------------------------------------------------------------
;Entra:	BX -> file handle
;Sai:	CF -> "0" se OK
;--------------------------------------------------------------------
fclose	proc	near
	mov		ah,3eh
	int		21h
	ret
fclose	endp
;--------------------------------------------------------------------
;Entra: BX -> file handle
;       dl -> caractere
;Sai:   AX -> numero de caracteres escritos
;		CF -> "0" se escrita ok
;--------------------------------------------------------------------
setChar	proc	near
	mov		ah,40h
	mov		cx,1
	mov		FileBuffer,dl
	lea		dx,FileBuffer
	int		21h
	ret
setChar	endp	
;--------------------------------------------------------------------
;   Fim do programa.
;--------------------------------------------------------------------
		end