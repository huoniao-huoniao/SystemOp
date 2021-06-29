%include "include/boot.inc"
;实模式到保护模式中
;需要打开20位地址线  基址：0xffff*16=0xffff0    偏移地址0xffff
;这种基址地址+偏移地址表示的最大地址 0xffff0+0xffff=0xfffff+0xfff0
;20位地址线最大地址 0xfffff  
;多出的0xfff0的地址空间是无法达到的
;所以需要打开20位地址线 取模回退  超出部分从0开始
section MBR vstart=0x7c00
        mov ax,cs
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov fs,ax
        mov sp,0x7c00
        mov ax,0xb800
        mov gs,ax
; 清屏 利用0x06号功能，上卷全部行，则可清屏。
; -----------------------------------------------------------
;INT 0x10   功能号:0x06	   功能描述:上卷窗口
;------------------------------------------------------
;输入：
;AH 功能号= 0x06
;AL = 上卷的行数(如果为0,表示全部)
;BH = 上卷行属性
;(CL,CH) = 窗口左上角的(X,Y)位置
;(DL,DH) = 窗口右下角的(X,Y)位置
;无返回值：
        mov ax,0x0600
        mov bx,0x0700
        mov cx,0
        mov dx,0x184f
        int 0x10

        ;获取光标
        mov ah,3   ;输出光标位置 dx中 打印字符中需要
        mov bh,0
        int 0x10

        ;打印字符串
        mov ax,message
        mov bp,ax

        mov cx,0xf  ;串的长度
        mov ax,0x1301
        mov bx,0x2
        int 0x10
        
        
        mov bx,shine
        mov bp,0x00
        mov cx,0x5
color: 
        mov al,[bx]    
        mov byte [gs:bp], al
        inc bx
        inc bp
        mov byte [gs:bp], 0xA4 ; A 表示绿色背景闪烁， 4 表示前景色为红色
        inc bp
        loop color

        ;读取硬盘到内存
        mov eax,LOADER_START_SECTOR;加载的起始扇区
        mov bx,LOADER_BASE_ADDR ;加载的内存地址
        mov cx,1 ;写入的扇区数
        call rd_disk_m_16 ;读取硬盘
        jmp LOADER_BASE_ADDR ;跳转
        
rd_disk_m_16:
        mov esi,eax
        mov di,cx

        mov dx,0x1f2;读取扇区数
        mov al,cl
        out dx,al
        
        ;eax被破环  mov al,cl
        mov eax,esi;恢复
        ;设置lba地址0x1f3-0x1f6 28位
        mov dx,0x1f3
        out dx,al
        
        mov cl,8 ;右移8位
        shr eax,cl
        mov dx,0x1f4
        out dx,al

        shr eax,cl ;右移8位
        mov dx,0x1f5
        out dx,al

        shr eax,cl ;右移8位
        and al,0x0f
        or al,0xe0 ;1110 
        mov dx,0x1f6
        out dx,al
        
       ;第3步：向0x1f7端口写入读命令，0x20 
       mov dx,0x1f7
       mov al,0x20                        
       out dx,al

;第4步：检测硬盘状态
  .not_ready:
      ;同一端口，写时表示写入命令字，读时表示读入硬盘状态
      nop
      in al,dx
      and al,0x88	   ;第4位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
      cmp al,0x08
      jnz .not_ready	   ;若未准备好，继续等。
      
    
      mov ax,di   ;一共512个扇区数  一次读一个字   256
      mov dx,256
      mul dx
      mov cx,ax
      mov dx,0x1f0
 .copy_read_byte:
      in ax,dx
      mov [bx],ax
      add bx,2
      loop .copy_read_byte         


      ret ;返回
       
message db 'Welcome to MBR!'
shine db 'color'
times 510-($-$$) db 0  
;$代表本行地址   $$代表段开始地址  $-$$=偏移量   boot总的字节数512
;下面占2个字节   故这段字节赋值0 510-($-$$)
db 0x55,0xaa

; 硬盘基础     一块主板上有两个插槽   插槽一 第一通道  可以挂两块硬盘 主 次  插槽二 第二通道  可以挂两块硬盘 主 次  
;                                                    读                                         写
;                         IO端口                   端口的作用                                 端口的作用
; 第一通道                 0x1F0                    读取数据                                   读取数据
;                         0x1F1                    读取失败状态信息                            写命令参数
;                         0x1F2                    未读取的扇区数                              待写入扇区数
;                         0x1F3                    LBA 0-7位                                   LBA 0-7位
;                         0x1F4                    8-15                                        8-15
;                         0x1F5                    16-23                                        16-23
;                         0x1F6                    device 寄存器 0-3位  储放LBA的24-27位       同读操作
;                                                  第4位 代表主盘 从盘   
;                                                  第6位代表LBA模式 0：CHS 1:LBA 剩下位都是1 
;                         0x1F7                    它是 8 位宽度的寄存器，用来给出硬盘的状态信息。|  写命令()
; 第 0 位是 ERR 位，如果此位为 1 ，表示命令出错了，具体原因可见 error 寄存器。
; 第 3 位是request 位，如果此位为 1 ，表示硬盘己经把数据准备好了，主机现在可以把数据读出来。
; 第 6 位是 DRDY,表示硬盘就绪，此位是在对硬盘诊断时用的，表示硬盘检测正常，可以继续执行一些命令 。\
; 第 7 位是 BSY位，表示硬盘是否繁忙，如果为 1 表示硬盘正忙着，此寄存器中的其他位都无效。
;
;
;
;第二通道               0x170
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
