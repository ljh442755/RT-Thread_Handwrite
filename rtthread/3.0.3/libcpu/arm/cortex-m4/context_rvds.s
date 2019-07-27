;*************************************************************************
;                                 ȫ�ֱ���
;*************************************************************************
    IMPORT rt_thread_switch_interrupt_flag
    IMPORT rt_interrupt_from_thread
    IMPORT rt_interrupt_to_thread
		
;*************************************************************************
;                                 ����
;*************************************************************************
;-------------------------------------------------------------------------
;�й��ں�����Ĵ�������ɲο��ٷ��ĵ���STM32F10xxx Cortex-M3 programming manual
;ϵͳ���ƿ�����SCB��ַ��Χ��0xE000ED00-0xE000ED3F
;-------------------------------------------------------------------------
SCB_VTOR        EQU     0xE000ED08     ; ������ƫ�ƼĴ���
NVIC_INT_CTRL   EQU     0xE000ED04     ; �жϿ���״̬�Ĵ���
NVIC_SYSPRI2    EQU     0xE000ED20     ; ϵͳ���ȼ��Ĵ���(2)
NVIC_PENDSV_PRI EQU     0x00FF0000     ; PendSV ���ȼ�ֵ (lowest)
NVIC_PENDSVSET  EQU     0x10000000     ; ����PendSV exception��ֵ
	
;*************************************************************************
;                              �������ָ��
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
    ; ����ԭ����ֵ
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
; * ����ԭ�ͣ�void rt_hw_context_switch_to(rt_uint32 to);
; * r0 --> to
; * �ú������ڿ�����һ���߳��л�
; *-----------------------------------------------------------------------
; */
		
rt_hw_context_switch_to    PROC
    ; 1.���������Թ��ⲿ����
    EXPORT rt_hw_context_switch_to

    ; 2.���� rt_interrupt_to_thread Ϊ�߳�ջָ��
    LDR r1, =rt_interrupt_to_thread 
    STR r0, [r1]
    
    ; 3.���� rt_interrupt_from_thread Ϊ 0 ��ʾ��һ���߳��л�
    LDR r1, =rt_interrupt_from_thread 
    MOV r0, #0x00
    STR r0, [r1]

    ; 4.�����жϱ�־λ rt_thread_switch_interrupt_flag ֵΪ1
    ; ....����ָʾ�ѽ������������л���׼������
    LDR r1, =rt_thread_switch_interrupt_flag
    MOV r0, #0x01
    STR r0, [r1]

    ; 5.���� PendSV �жϵ����ȼ�Ϊ���
    LDR r0, =NVIC_SYSPRI2
    LDR r1, =NVIC_PENDSV_PRI
    LDR.W r2, [r0, #0x00] ; ����Ŀ��Ĵ���ԭ����ֵ
    ORR r1, r1, r2     ; �޸����ȼ�
    STR r1, [r0]       ; д����Ч

    ; 6.���� PendSV �ж�
    LDR r0, =NVIC_INT_CTRL
    LDR r1, =NVIC_PENDSVSET
    STR r1, [r0]

    ; 7.���ж�
    CPSIE F ; enable interrupts and all fault handler
    CPSIE I ; enable interrupts and configurable fault handler

    ; ��Զ���ᵽ������
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

    ; 1.�ж��жϱ�־λ rt_thread_switch_interrupt_flag ֵ�Ƿ�Ϊ1
    ; ....���ǣ�˵���ϴ���λ��δ���й��������л�����ô�Ƚ����������л�
    ; ....������ô���� rt_interrupt_from_thread��׼������һ���������л�
    LDR r2, =rt_thread_switch_interrupt_flag
    LDR r3, [r2]
    CMP r3, #0x01
    BEQ _reswitch
    MOV r3, #0x01
    STR r3, [r2]

    ; 2.���� rt_interrupt_from_thread Ϊ��һ���̵߳��߳�ջָ��
    LDR r2, =rt_interrupt_from_thread 
    STR r0, [r2]

_reswitch    
    ; 3.���� rt_interrupt_to_thread Ϊ��һ���̵߳��߳�ջָ��
    LDR r2, =rt_interrupt_to_thread 
    STR r1, [r2]
    
    ; 4.���� PendSV �ж�
    LDR r0, =NVIC_INT_CTRL
    LDR r1, =NVIC_PENDSVSET
    STR r1, [r0]

    ; 5.�ӳ��򷵻�
    BX lr
    
	; �ӳ������
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

    ; 0.�ر��жϣ��Ա����������л����ᱻ���
    MRS r2, PRIMASK
    CPSID I

    ; 1.�ж� rt_thread_switch_interrupt_flag ��ֵ�Ƿ�Ϊ 1
    ; ....��Ϊ1����ô����һ���������л�
    ; ....������ת�� pendsv_exit�����¿����жϺ�����쳣����
    LDR r0, =rt_thread_switch_interrupt_flag
    LDR r1, [r0]
    CBZ r1, pendsv_exit

    ; 2.�������л���������� rt_thread_switch_interrupt_flag ��ֵ
    MOV r1, #0x0
    STR r1, [r0]

    ; 3.�ж��Ƿ��ǵ�һ�ν����������л������ǣ���ô�������ı���Ļ���
    ; ....ֱ�ӽ��������л�
    LDR r0, =rt_interrupt_from_thread
    LDR r1, [r0]
    CBZ r1, switch_to_thread

    ; *************���ı���***************
    ; 4.1 ��ȡCPUջָ��PSP���洢����ǰ�̵߳��߳�ջ��
    MRS r1, psp

    ; 4.2 ��CPU�Ĵ��� r4~r11 ��ֵ���ѹ���߳�ջ�б���
    STMFD r1!, {r4-r11}

    ; 4.3 �޸� rt_interrupt_from_thread ��ֵΪ��ǰ�̵߳��߳�ջ��ַ
    LDR r0, [r0]
    STR r1, [r0]

switch_to_thread
    ; *************�����л�***************    
    ; 5.1 ���̵߳��߳�ջ�л�ȡ�õ�ջָ��
    LDR r1, =rt_interrupt_to_thread
    LDR r1, [r1]
    LDR r1, [r1]
    
    ; 5.2 ���߳�ջ�� r4~r11 д��CPU�Ĵ���
    LDMFD r1!, {r4-r11}

    ; 5.3 ���߳�ջָ����µ�CPUջָ��PSP��
    MSR PSP, r1

pendsv_exit
    ; 6.��β����
    ; ....���»ָ��ж�
    ; ....���� LR ��[2]Ϊ1����֤�쳣����ʱʹ�õ�PSPջָ�룬����MSPջָ��
    ; ....�쳣���أ���ʱ�߳�ջ��ʣ�µ����ݻ��Զ����ص�CPU�Ĵ���
    ; ....R0~R3, R12, R14, PC, XPSR
    MSR PRIMASK, r2
    ORR lr, lr, #0x04
    BX lr

    ; PendSV_Handler �ӳ������
	ENDP	
	
	
	ALIGN   4

    END
		
