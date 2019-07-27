;*************************************************************************
;                                 全局变量
;*************************************************************************
    IMPORT rt_thread_switch_interrupt_flag
    IMPORT rt_interrupt_from_thread
    IMPORT rt_interrupt_to_thread
		
;*************************************************************************
;                                 常量
;*************************************************************************
;-------------------------------------------------------------------------
;有关内核外设寄存器定义可参考官方文档：STM32F10xxx Cortex-M3 programming manual
;系统控制块外设SCB地址范围：0xE000ED00-0xE000ED3F
;-------------------------------------------------------------------------
SCB_VTOR        EQU     0xE000ED08     ; 向量表偏移寄存器
NVIC_INT_CTRL   EQU     0xE000ED04     ; 中断控制状态寄存器
NVIC_SYSPRI2    EQU     0xE000ED20     ; 系统优先级寄存器(2)
NVIC_PENDSV_PRI EQU     0x00FF0000     ; PendSV 优先级值 (lowest)
NVIC_PENDSVSET  EQU     0x10000000     ; 触发PendSV exception的值
	
;*************************************************************************
;                              代码产生指令
;*************************************************************************

    AREA |.text|, CODE, READONLY, ALIGN=2
    THUMB
    REQUIRE8
    PRESERVE8
		

;/*
; * rt_base_t rt_hw_interrupt_disable();
; */
rt_hw_interrupt_disable    PROC
    export rt_hw_interrupt_disable
    ; 保存原来的值
    MRS	r0, PRIMASK
    CPSID   I
    BX  lr
    ENDP

;/*
; * void rt_hw_interrupt_enable(rt_base_t level);
; */
rt_hw_interrupt_enable    PROC
    export rt_hw_interrupt_enable
    MSR PRIMASK, r0
    BX  lr
    ENDP
    


;/*
; *-----------------------------------------------------------------------
; * 函数原型：void rt_hw_context_switch_to(rt_uint32 to);
; * r0 --> to
; * 该函数用于开启第一次线程切换
; *-----------------------------------------------------------------------
; */
		
rt_hw_context_switch_to    PROC
    ; 1.导出函数以供外部调用
    EXPORT rt_hw_context_switch_to

    ; 2.设置 rt_interrupt_to_thread 为线程栈指针
    LDR r1, =rt_interrupt_to_thread 
    STR r0, [r1]
    
    ; 3.设置 rt_interrupt_from_thread 为 0 表示第一次线程切换
    LDR r1, =rt_interrupt_from_thread 
    MOV r0, #0x00
    STR r0, [r1]

    ; 4.设置中断标志位 rt_thread_switch_interrupt_flag 值为1
    ; ....用于指示已进行了上下文切换的准备工作
    LDR r1, =rt_thread_switch_interrupt_flag
    MOV r0, #0x01
    STR r0, [r1]

    ; 5.设置 PendSV 中断的优先级为最低
    LDR r0, =NVIC_SYSPRI2
    LDR r1, =NVIC_PENDSV_PRI
    LDR.W r2, [r0, #0x00] ; 读出目标寄存器原来的值
    ORR r1, r1, r2     ; 修改优先级
    STR r1, [r0]       ; 写入生效

    ; 6.触发 PendSV 中断
    LDR r0, =NVIC_INT_CTRL
    LDR r1, =NVIC_PENDSVSET
    STR r1, [r0]

    ; 7.开中断
    CPSIE F ; enable interrupts and all fault handler
    CPSIE I ; enable interrupts and configurable fault handler

    ; 永远不会到达这里
    ENDP



;/*
; *-----------------------------------------------------------------------
; * void rt_hw_context_switch(rt_uint32 from, rt_uint32 to);
; * r0 --> from
; * r1 --> to
; *-----------------------------------------------------------------------
; */
;rt_hw_context_switch_interrupt
    ;EXPORT rt_hw_context_switch_interrupt
		
rt_hw_context_switch    PROC
    EXPORT rt_hw_context_switch

    ; 1.判断中断标志位 rt_thread_switch_interrupt_flag 值是否为1
    ; ....若是，说明上次置位后还未进行过上下文切换，那么先进行上下文切换
    ; ....若否，那么更新 rt_interrupt_from_thread，准备触发一次上下文切换
    LDR r2, =rt_thread_switch_interrupt_flag
    LDR r3, [r2]
    CMP r3, #0x01
    BEQ _reswitch
    MOV r3, #0x01
    STR r3, [r2]

    ; 2.设置 rt_interrupt_from_thread 为上一个线程的线程栈指针
    LDR r2, =rt_interrupt_from_thread 
    STR r0, [r2]

_reswitch    
    ; 3.设置 rt_interrupt_to_thread 为下一个线程的线程栈指针
    LDR r2, =rt_interrupt_to_thread 
    STR r1, [r2]
    
    ; 4.触发 PendSV 中断
    LDR r0, =NVIC_INT_CTRL
    LDR r1, =NVIC_PENDSVSET
    STR r1, [r0]

    ; 5.子程序返回
    BX lr
    
	; 子程序结束
    ENDP


;/*
; *-----------------------------------------------------------------------
; * void PendSV_Handler(void);
; * r0 --> switch from thread stack
; * r1 --> switch to thread stack
; * psr, pc, lr, r12, r3, r2, r1, r0 are pushed into [from] stack
; *-----------------------------------------------------------------------
; */

PendSV_Handler   PROC
    EXPORT PendSV_Handler

    ; 0.关闭中断，以保护上下文切换不会被打断
    MRS r2, PRIMASK
    CPSID I

    ; 1.判断 rt_thread_switch_interrupt_flag 的值是否为 1
    ; ....若为1，那么进行一次上下文切换
    ; ....否则，跳转到 pendsv_exit，重新开启中断后进行异常返回
    LDR r0, =rt_thread_switch_interrupt_flag
    LDR r1, [r0]
    CBZ r1, pendsv_exit

    ; 2.上下文切换，首先清除 rt_thread_switch_interrupt_flag 的值
    MOV r1, #0x0
    STR r1, [r0]

    ; 3.判断是否是第一次进行上下文切换，若是，那么跳过上文保存的环节
    ; ....直接进行下文切换
    LDR r0, =rt_interrupt_from_thread
    LDR r1, [r0]
    CBZ r1, switch_to_thread

    ; *************上文保存***************
    ; 4.1 获取CPU栈指针PSP，存储到当前线程的线程栈中
    MRS r1, psp

    ; 4.2 将CPU寄存器 r4~r11 的值逐个压入线程栈中保存
    STMFD r1!, {r4-r11}

    ; 4.3 修改 rt_interrupt_from_thread 的值为当前线程的线程栈地址
    LDR r0, [r0]
    STR r1, [r0]

switch_to_thread
    ; *************下文切换***************    
    ; 5.1 从线程的线程栈中获取得到栈指针
    LDR r1, =rt_interrupt_to_thread
    LDR r1, [r1]
    LDR r1, [r1]
    
    ; 5.2 将线程栈中 r4~r11 写入CPU寄存器
    LDMFD r1!, {r4-r11}

    ; 5.3 将线程栈指针更新到CPU栈指针PSP中
    MSR PSP, r1

pendsv_exit
    ; 6.收尾工作
    ; ....重新恢复中断
    ; ....设置 LR 的[2]为1，保证异常返回时使用的PSP栈指针，而非MSP栈指针
    ; ....异常返回，此时线程栈中剩下的内容会自动加载到CPU寄存器
    ; ....R0~R3, R12, R14, PC, XPSR
    MSR PRIMASK, r2
    ORR lr, lr, #0x04
    BX lr

    ; PendSV_Handler 子程序结束
	ENDP	
	
	
	ALIGN   4

    END
		
