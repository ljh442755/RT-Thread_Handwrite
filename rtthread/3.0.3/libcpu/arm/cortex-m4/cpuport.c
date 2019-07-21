#include <rtthread.h>

/*
*************************************************************************
*                                 ��������
*************************************************************************
*/
struct exception_stack_frame
{
    /* �쳣����ʱ�Զ�����ļĴ��� */
	rt_uint32_t r0;
    rt_uint32_t r1;
    rt_uint32_t r2;
    rt_uint32_t r3;
    rt_uint32_t r12;
    rt_uint32_t lr;
    rt_uint32_t pc;
    rt_uint32_t psr;
};

struct stack_frame
{
    /* r4 ~ r11 register 
	  �쳣����ʱ���ֶ�����ļĴ��� */
    rt_uint32_t r4;
    rt_uint32_t r5;
    rt_uint32_t r6;
    rt_uint32_t r7;
    rt_uint32_t r8;
    rt_uint32_t r9;
    rt_uint32_t r10;
    rt_uint32_t r11;

    struct exception_stack_frame exception_stack_frame;
};
/*
*************************************************************************
*                                 ȫ�ֱ���
*************************************************************************
*/

/* ���ڴ洢��һ���̵߳�ջ��sp��ָ�� */
rt_uint32_t rt_interrupt_from_thread;

/* ���ڴ洢��һ����Ҫ���е��̵߳�ջ��sp��ָ�� */
rt_uint32_t rt_interrupt_to_thread;

/* PendSV�жϷ�����ִ�б�־ */
rt_uint32_t rt_thread_switch_interrupt_flag;


/*
*************************************************************************
*                                 ����ʵ��
*************************************************************************
*/
/* �߳�ջ��ʼ�� */
rt_uint8_t *rt_hw_stack_init(void       *tentry,
                             void       *parameter,
                             rt_uint8_t *stack_addr)
{
	struct stack_frame *stack_frame;
	rt_uint8_t         *stk;
	unsigned long       i;

    // 1.��ȡջ��ָ��
    stk = stack_addr + sizeof(rt_uint32_t);

    // 2.ջ����8�ֽڶ���
    stk = (rt_uint8_t *)RT_ALIGN_DOWN((rt_uint32_t)stk, 8);

    // 3.��ջ����ƫ�� stack_frame 
    // ....��ʼ���ڴ����ڴ洢CPU�Ĵ��������Ϣ
    stk -= sizeof(struct stack_frame);
    stack_frame = (struct stack_frame *)stk;

    // 4.��ʼ����Ҫ�ֶ����ص� CPU �ļĴ�����Ϣ
    // .....R4~R11
    for (i=0; i<sizeof(stack_frame)/sizeof(rt_uint32_t); i++)
    {
        ((rt_uint32_t *)stack_frame)[i] = 0xdeadbeef;
    }
    
    // 5. ��ʼ������Ҫ�ֶ����ص� CPU �ļĴ���
    // ....R0~R3,R12,LR,PC,PSR
    stack_frame->exception_stack_frame.r0 = 0;
    stack_frame->exception_stack_frame.r1 = 0;
    stack_frame->exception_stack_frame.r2 = 0;
    stack_frame->exception_stack_frame.r3 = 0;
    stack_frame->exception_stack_frame.r12 = 0x0;
    stack_frame->exception_stack_frame.lr = 0x0;
    stack_frame->exception_stack_frame.pc = (rt_uint32_t)tentry;
    stack_frame->exception_stack_frame.psr = 0x01000000L;
    
	/* �����߳�ջָ�� */
	return stk;
}

