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
depurate			db		"Ate aqui, ok.", CR, LF, 0					; String usada para depurar o código.
MsgCRLF				db		CR, LF, 0

backup				db		0				; Variável para realizar alguns backups.
flag				db		0				; Variável para testar algumas flags de jump.
integer				db		0				; Variável para testar se é um inteiro válido.
frac				db		0				; Variável para testar se é um fracionário válido.
one_integer_number	db		3 dup (0h)		; Variável para guardar um número inteiro.
one_frac_number		db		2 dup (0h)		; Variável para guardar um número fracionário.
int_sig				dw		0				; Número significativo de inteiros.
integer_flag		db		0				; Flag para a parte inteira.
frac_sig			dw		0				; Número significativo de fracionários.
frac_flag			db		0				; Flag para a parte fracionária.

final_int_number	dw		100 dup (?)		; Variável que irá guardar todos os possíveis números inteiros.
final_int_count		dw		0				; Variável para contar a posição do vetor de inteiros.
count_write_int		dw		0	
final_frac_number	dw		100 dup (?)		; Variável que irá guardar todos os possíveis números fracionários.
final_frac_count	dw		0				; Variável para contar a posição do vetor de fracionários.
count_write_frac	dw		0

Nothing				db		100 dup (?)		; Algo ta consumindo essa variável...
write_count			dw		1 				; Variável utilizada para contar no programa de saída.
write_count2		dw		0 				; Variável utilizada para contar no programa de saída.
write_count3		dw		0 				; Variável utilizada para contar no programa de saída.
string_convet		db		0 				; String convertida.

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

	;Cria o arquivo de saída
	call	GetFileDestName				; Chama a função para colocar .res no nome do arquivo.	
	lea		dx,FileName					; dx = FileName.res
	call	fcreate						; Chama a função que cria o arquivo.
	mov		FileHandleDst,bx			; Salva o FileHandle.
	jnc		Again						; Vai para a segunda parte do programa.
	lea		bx, MsgErroCreateFile		; Caso o arquivo não tenha conseguido ser criado.
	call	printf_s					; Informa o erro na tela.
	jmp		End_program					; Finaliza o programa.

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


	; Verifica se chegou no final do arquivo.
Continua2:
	;if (ax==0)	fclose(bx=FileHandle);
	; Se ax == 0, significa que nenhum byte foi lido.
	cmp		ax,0
	; Caso ax != 0, continua.
	jne		Test_side
	; Caso ax == 0, já leu tudo.
	mov		al,0
	jmp		Continue_write2

	; Testa a flag para saber se estou lidando com a parte inteira ou fracionária.
Test_side:
	; Testa se a flag vale 1.
	cmp		flag, 1h
	; Caso seja 1, lida com a parte fracionária
	je		Continua3_frac
	; Caso seja diferente de 1, lida com a parte inteira.
	jmp		Continua3_int

	; Just a mid-jump. Usado pra pular para distâncias maiores no código.
Again_mid_jump:
	jmp		Again

	; Lida com a parte inteira.
Continua3_int:
	;bl = FileBuffer[x]
	mov		bh, 0h
	mov		bl,FileBuffer		; Pega o caractere lido do arquivo. 
	cmp		bl, CR				; Testa se o caractere é um Carriage Return.
	je		New_line			; Se for, a linha terminou.
	cmp		bl, LF				; Testa se o caractere é um Line Feed.
	je		New_line			; Se for, a linha terminou.
	cmp		bl, 2Eh				; Testa se o caractere é um '.'.
	je		Deal_with_separator	; Se for, lida com ele.
	cmp		bl, 2Ch				; Testa se o caractere é um ','.
	je		Deal_with_separator	; Se for, lida com ele.
	cmp		bl, 30h				; Testa se é algo menor que 9h.
	jb		Again				; Busca o próximo caractere.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	ja		Again				; Busca o próximo caractere.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	jb		Found_a_Integer_Number_mid_jump		; Se for, lida com o número lido.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	je		Found_a_Integer_Number_mid_jump		; Se for, lida com o número lido.
	jmp		Again				; Senão, busca o próximo caractere.

	; Lida com a parte fracionária.
Continua3_frac:
	;bl = FileBuffer[0]
	mov		bh, 0h
	mov		bl,FileBuffer		; Pega o caractere lido do arquivo. 
	cmp		bl, CR				; Testa se o caractere é um Carriage Return.
	je		New_line			; Se for, a linha terminou.
	cmp		bl, LF				; Testa se o caractere é um Line Feed.
	je		New_line			; Se for, a linha terminou.	
	cmp		bl, 30h				; Testa se é algo menor que 9h.
	jb		Again				; Busca o próximo caractere.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	ja		Again				; Busca o próximo caractere.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	jb		Found_a_Frac_Number	; Se for, lida com o número lido.
	cmp		bl, 39h				; Testa se é algo menor que 9h.
	je		Found_a_Frac_Number	; Se for, lida com o número lido.
	jmp		Again_mid_jump		; Senão, busca o próximo caractere.

Deal_with_separator:
	; Coloca 1 para a flag.
	mov		flag, 1h
	; Procura o próximo caractere.	
	jmp		Again

	; Just another mid-jump. Usado para conseguir 'jumpar' para posições mais distantes no código.
Found_a_Integer_Number_mid_jump:
	jmp		Found_a_Integer_Number

	; Caso tenha encontrado um CR (Carriage Return) ou LF (Line Feed).
New_line:
	lea		bx, one_integer_number		; Transforma o número lido em HEX
	call 	atoi						; Chama a função atoi para transformar os chars para int.
	call	check_integer_number		; Chega se o número inteiro recebido está dentro do padrão estabelecido.
	lea		bx, one_frac_number			; Transforma o número lido em HEX
	call	atoi						; Chama a função atoi para transformar os chars para int.
	call	check_frac_number			; Chega se o número fracionário recebido está dentro do padrão estabelecido.
	cmp		integer_flag, 1h			; Se o número não for válido. Vai para a próxima linha.
	je		Next_step					; Se for válido. Chega a validade do número fracionário.
	jmp		End_line					; Termina de ler a linha.

Next_step:
	cmp		frac_flag, 1h				; Se o número não for válido. Vai para a próxima linha.
	je      Numbers_OK					; Se for válido, insere eles nos vetores.	
	jmp		End_line					; Termina de ler a linha.

	; Para finalizar a linha, reseta todas as variáveis.
End_line:
	jmp		Reset_numbers

	; Caso os números estejam de acordo com o pedido.
Numbers_OK:
	push	bx							; Salva bx na pilha.
	mov		bx, final_int_count			; bx recebe a última posição registrada no vetor dos inteiros.
	mov		final_int_number[bx], ax	; Coloca o número na determinada posição do vetor.
	inc		final_int_count				; Incrementa a variável da posição do vetor.
	mov		bx, final_frac_count		; bx recebe a última posição registrada no vetor dos fracionários.
	mov		final_frac_number[bx], cx	; Coloca o número na determinada posição do vetor.
	inc		final_frac_count			; Incrementa a variável da posição do vetor.
	pop		bx							; Recupera o backup de bx.
	jmp		Write_in_dest				; Escreve no arquivo de saída, a linha lida.

	; Caso tenha encontrado um número inteiro na linha.
Found_a_Integer_Number:
	mov		ah, 0
	mov		al, bl						; al = o número lido
	mov		bx,int_sig					; bx = Qual é o número significativo dos inteiros.
	mov		one_integer_number[bx],al	; Coloca o número lido na sua determinada posição.
	inc		int_sig 					; Incrementa o número significativo.
	jmp		Again						; Busca o próximo caractere.

	; Caso tenha encontrado um número fracionário na linha.
Found_a_Frac_Number:
	mov		ah, 0
	mov		al, bl						; al = o número lido
	mov		bx,frac_sig					; bl = Qual é o número significativo dos inteiros.
	mov		one_frac_number[bx],al		; Coloca o número lido na sua determinada posição.			
	inc		frac_sig 					; Incrementa o número significativo.
	jmp		Again						; Busca o próximo caractere.	

Write_in_dest:
	; Converte o número de contagem para string	
	; Escreve o índice no arquivo.	
	mov		ax,write_count3
	lea		bx,string_convet
	call	sprintf_w					; Converte int pra char	
	mov		bx, FileHandleDst			; BX = FileHandleDst.
	mov		dl, string_convet			; dl = caractere a ser escrito.
	call	setChar
	mov		ax,write_count2
	lea		bx,string_convet
	call	sprintf_w					; Converte int pra char	
	mov		bx, FileHandleDst			; BX = FileHandleDst.
	mov		dl, string_convet			; dl = caractere a ser escrito.
	call	setChar
	mov		ax,write_count
	lea		bx,string_convet
	call	sprintf_w					; Converte int pra char	
	mov		bx, FileHandleDst			; BX = FileHandleDst.
	mov		dl, string_convet			; dl = caractere a ser escrito.
	call	setChar

	; Incrementa o contador menos significativo.
	cmp		write_count, 9h
	je		First_inc
	inc		write_count					; Incrementa o contador.
	jmp		Continue_write

	; Incrementa o segundo contador significativo.
First_inc:
	mov 	write_count, 0h
	cmp		write_count2, 9h
	je		Second_inc
	inc 	write_count2
	jmp		Continue_write

	; Incrementa o terceiro contador significativo.
Second_inc:
	mov		write_count2, 0h
	inc		write_count3
	jmp		Continue_write

Continue_write:
	; Escreve ' '
	mov		dl, ' '
	call	setChar

	; Escreve '-'
	mov		dl, '-'
	call	setChar

	; Escreve ' '
	mov		dl, ' '
	call	setChar

	; Escreve a parte inteira.
First_int_number:
	; Primeiro dígito.
	mov		bx, count_write_int
	mov		al, one_integer_number[bx]
	cmp		al, 0h
	je		Second_int_number
	mov		dl, al
	mov		bx, FileHandleDst
	call	setChar
	inc		count_write_int

Second_int_number:	
	; Segundo Dígito.
	mov		bx, count_write_int
	mov		al, one_integer_number[bx]
	cmp		al, 0h
	je		Third_int_number
	mov		dl, al
	mov		bx, FileHandleDst
	call	setChar
	inc		count_write_int

Third_int_number:	
	; Terceiro Dígito.
	mov		bx, count_write_int
	mov		al, one_integer_number[bx]
	cmp		al, 0h
	je		Continue_writing_numbers
	mov		dl, al
	mov		bx, FileHandleDst
	call	setChar

Continue_writing_numbers:
	; Virgula
	mov		bx, FileHandleDst
	mov		dl, ','
	call	setChar

	; Escreve a parte fracionária.
First_frac_number:
	; Primeiro dígito.
	mov		bx, count_write_frac
	mov		al, one_frac_number[bx]
	cmp		al, 0h
	je		Second_frac_number
	mov		dl, al
	mov		bx, FileHandleDst
	call	setChar
	inc		count_write_frac

Second_frac_number:
	; Segundo dígito.
	mov		bx, count_write_frac
	mov		al, one_frac_number[bx]
	cmp		al, 0h
	je		Continue_writing_numbers2
	mov		dl, al
	mov		bx, FileHandleDst
	call	setChar

Continue_writing_numbers2:
	mov		bx, FileHandleDst
	; Escreve ' '
	mov		dl, ' '
	call	setChar

	; Escreve '-'
	mov		dl, '-'
	call	setChar

	; Escreve ' '
	mov		dl, ' '
	call	setChar

	; Escreve 'CR LF'
	mov		dl, CR
	call	setChar
	mov		dl, LF
	call	setChar
	jmp		Reset_numbers				; Reseta os números. Para depois ir para a próxima linha.

	; Reseta as variáveis.
Reset_numbers:	
	mov		one_integer_number[0], 0h	
	mov		one_integer_number[1], 0h
	mov		one_integer_number[2], 0h		
	mov		one_frac_number[0], 0h
	mov		one_frac_number[1], 0h

	; Reseta as flags.
	mov		integer_flag, 0
	mov		frac_flag, 0
	mov		int_sig, 0			
	mov		frac_sig, 0
	mov		count_write_int, 0
	mov		count_write_frac, 0
	mov		flag, 0

	; Procura o próximo caractere.
	jmp		Again
	
Continue_write2:
	mov		bx, FileHandleDst			; BX = FileHandleDst.
	; Escreve 'Soma:'
	mov		dl, 'S'
	call	setChar
	mov		dl, 'O'
	call	setChar
	mov		dl, 'M'
	call	setChar
	mov		dl, 'A'
	call	setChar
	mov		dl, ':'
	call	setChar

	; Escreve 'CR LF'
	mov		dl, CR
	call	setChar
	mov		dl, LF
	call	setChar

	; Escreve 'Media:'
	mov		dl, 'M'
	call	setChar
	mov		dl, 'E'
	call	setChar
	mov		dl, 'D'
	call	setChar
	mov		dl, 'I'
	call	setChar
	mov		dl, 'A'
	call	setChar
	mov		dl, ':'
	call	setChar

	jmp		CloseAndFinal

	; Fecha o arquivo de ENTRADA.
CloseAndFinal:
	;fclose(FileHandle->bx)
	mov		bx,FileHandle		; Fecha o arquivo de entrada.
	call	fclose				; Chama a função que fecha arquivos.
	mov		bx,FileHandleDst	; Fecha o arquivo de saída.
	call	fclose				; Chama a função que fecha arquivos.
	jmp		End_program

	; Finaliza o programa.
End_program:
	.exit   						; HLT.

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

Return_from_check_int:
	ret

invalid_integer:
	mov		integer_flag, 0
	ret

check_integer_number endp

;--------------------------------------------------------------------
;Função:Checa se o número fracionário recebido é válido.
;Entra: (S) -> DS:AX -> Número fracionário
;Sai:	(A) -> DS:CX -> Número fracionário
;Seta a flag de fracionário como válida.
;--------------------------------------------------------------------
check_frac_number	proc near
checking_frac:
	mov		cx, ax
	cmp 	cx, 0h
	jb		invalid_frac
	cmp		cx, 63h
	ja		invalid_frac
	mov		frac_flag, 1h

Return_from_check_frac:
	ret

invalid_frac:
	mov		frac_flag, 0h	
	ret

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
; Escreve no arquivo de saída.;
; ENTRADA: Bx -> FileHandle
;--------------------------------------------------------------------
write_char	proc	near


	ret
write_char endp
;--------------------------------------------------------------------
;   Fim do programa.
;--------------------------------------------------------------------
		end