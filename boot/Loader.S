%include "include\boot.inc"

section Loader vstart=LOADER_BASE_ADDR
        LOADER_STACK_TOP EQU LOADER_BASE_ADDR
        jmp loader_start;跳转

gdt_addr:
        GDT_BASE   dd 0x00000000
                   dd 0x00000000
        CODE_DESC  dd 0x0000FFFF
                   dd DESC_CODE_HIGH4
        DATA_DESC  dd 0x0000FFFF
                   dd DESC_DATA_HIGH4
        VIDEO_DESC dd 0x0000FFFF
                   dd DESC_VIDEO_HIGH4
        GDT_SIZE EQU $-GDT_BASE
        GDT_LIMIT EQU GDT_SIZE-1
        ;选择子结构
        SELECTOR_CODE EQU (0X0001<<3)+TI_GDT+RPL0
        SELECTOR_DATA EQU (0X0002<<3)+TI_GDT+RPL0
        SELECTOR_VIDEO EQU (0X0003<<3)+TI_GDT+RPL0

        gdt_ptr : dw GDT_LIMIT
                  dd gdt_addr
        
        loadermsg db '2 loader in real.'
  ;开始代码
  loader_start:
        ;在mbr中已经定gs=0xb800
        mov  byte [gs:0x00],'m'
        mov  byte [gs:0x01],0xA4
        mov  byte [gs:0x02],'1'
        mov  byte [gs:0x03],0xA4

        ;BIOS中断
        mov	 sp, LOADER_BASE_ADDR
        mov	 bp, loadermsg           ; ES:BP = 字符串地址
        mov	 cx, 17			 ; CX = 字符串长度
        mov	 ax, 0x1301		 ; AH = 13,  AL = 01h
        mov	 bx, 0x001f		 ; 页号为0(BH = 0) 蓝底粉红字(BL = 1fh)
        mov	 dx, 0x1800		 ;
        int	 0x10 
        
        ;打开A20
        in al,0x92
        or al,0000_0010B
        out 0x92,al
        ;-------------------加载GDT
        lgdt [gdt_ptr]   ;gdtr

        ;-------------------cr0第0位置1
        mov eax,cr0
        or eax,0x00000001
        mov cr0,eax
        
        



        jmp SELECTOR_CODE:p_mode_start


[bits 32]
p_mode_start:
   mov ax, SELECTOR_DATA
   mov ds, ax
   mov es, ax
   mov ss, ax
   mov esp,LOADER_STACK_TOP
   mov ax, SELECTOR_VIDEO
   mov gs, ax

   mov byte [gs:160], 'P'

   jmp $
