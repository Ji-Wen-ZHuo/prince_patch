; 总体思路是原来的程序在sprintf之后会使用call指令调用一个函数进行输出
; 这条指令有5字节长，我把这条call指令修改成远跳指令跳到我自己写的驻留程序中
; 在我的驻留程序里首先先是执行了上面因为被写而没有执行的call
; 输出"WORD...PAGE...LINE..."
; 再重新设置参数（获取正确的答案字母并压入栈，修改框体的位置）
; 再次调用这个call实现输出答案的效果

.386
code segment use16
assume cs:code, ds:code
output db '=', 'A', 0
retaddr dw 02453h, 0
display dw 0, 0
int8h:    ; interrupt service routine
   push ax
   push bx
   push es
   mov ah, 62h
   int 21h; bx=psp
   add bx, 10h; bx=current program's 1st seg
   mov es, bx
   cmp word ptr es:[244Eh], 0449Ah ; 比较要修改的这条指令 call
   jne skip ; 如果不是说明不在游戏程序或者已经改掉了，跳过
   mov ax, word ptr es:[244Fh]
   mov bx, word ptr es:[2451h]
   mov cs:display[0], ax
   mov cs:display[2], bx ; 保存call的函数地址在display中，因为这个函数是动态库，地址只有在程序加载之后才知道，因此需要动态加载
   mov byte ptr es:[244Eh], 0EAh
   mov ax, offset plugin
   mov word ptr es:[244Fh], ax
   mov word ptr es:[2451h], cs ; 修改原来的call display函数为jmp(远跳) plugin
   mov cs:retaddr[2], es
skip:
   pop es
   pop bx
   pop ax
   jmp dword ptr cs:[old8h]
plugin:
   call dword ptr cs:[display] ; 因为原来的call被改掉了，因此先执行原来的call display
   ; F96这个地方是一个结构体，四个数分别代表(x1,y1)和(x2,y2)也就是绘制文字框的位置
   mov word ptr ds:[0F96h], 0C1h ; y1
   mov word ptr ds:[0F98h], 0FAh ; x1
   mov word ptr ds:[0F9Ah], 0CAh ; y2
   mov word ptr ds:[0F9Ch], 10Ah ; x2
   push bp
   mov bp, sp
   mov byte ptr ss:[bp + 4], '='
   mov si, byte ptr ds:[3d16h] ; 正确答案的编号
   add si, 01CAh ; 编号对应的字母地址
   mov ax, byte ptr ds:[si]
   mov byte ptr ss:[bp + 5], ax
   mov byte ptr ss:[bp + 6], 0
   mov ax, bp
   add ax, 4 ; 将答案对应的字符串压栈
   pop bp
   push ax
   call dword ptr cs:[display] ; 调用display函数打印正确答案
   jmp dword ptr cs:[retaddr] ; 调回原来的下一条指令
old8h dw 0, 0
main:
   xor ax, ax
   mov es, ax; ES=0
   mov bx, 8h*4
   mov ax, es:[bx]
   mov dx, es:[bx+2]
   mov cs:old8h[0], ax
   mov cs:old8h[2], dx

   cli; IF=0禁止中断
   mov word ptr es:[bx], offset int8h
   mov es:[bx+2], cs
   sti; IF=1允许中断

   mov ah, 31h
   mov dx, offset main; main到code段的距离即我们
                      ; 希望保留的内存块的长度
   add dx, 100h; psp's len
   add dx, 0Fh; 当内存块有不足10h的零头时
              ; 把零头当作10h字节看待
   shr dx, 4  ; dx = dx / 10h
   int 21h    ; Terminate & Stay Resident结束运行但保留内存块
code ends
end main
