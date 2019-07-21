#include <rtthread.h>

/*
*************************************************************************
*                                 数据类型
*************************************************************************
*/
struct exception_stack_frame
{
    /* 异常发生时自动保存的寄存器 */
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
	  异常发生时需手动保存的寄存器 */
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
*                                 全局变量
*************************************************************************
*/

/* 用于存储上一个线程的栈的sp的指针 */
rt_uint32_t rt_interrupt_from_thread;

/* 用于存储下一个将要运行的线程的栈的sp的指针 */
rt_uint32_t rt_interrupt_to_thread;

/* PendSV中断服务函数执行标志 */
rt_uint32_t rt_thread_switch_interrupt_flag;


/*
*************************************************************************
*                                 函数实现
*************************************************************************
*/
/* 线程栈初始化 */
rt_uint8_t *rt_hw_stack_init(void       *tentry,
                             void       *parameter,
                             rt_uint8_t *stack_addr)
{
	struct stack_frame *stack_frame;
	rt_uint8_t         *stk;
	unsigned long       i;

    // 1.获取栈顶指针
    stk = stack_addr + sizeof(rt_uint32_t);

    // 2.栈向下8字节对齐
    stk = (rt_uint8_t *)RT_ALIGN_DOWN((rt_uint32_t)stk, 8);

    // 3.将栈向下偏移 stack_frame 
    // ....初始化内存用于存储CPU寄存器相关信息
    stk -= sizeof(struct stack_frame);
    stack_frame = (struct stack_frame *)stk;

    // 4.初始化需要手动加载到 CPU 的寄存器信息
    // .....R4~R11
    for (i=0; i<sizeof(stack_frame)/sizeof(rt_uint32_t); i++)
    {
        ((rt_uint32_t *)stack_frame)[i] = 0xdeadbeef;
    }
    
    // 5. 初始化不需要手动加载到 CPU 的寄存器
    // ....R0~R3,R12,LR,PC,PSR
    stack_frame->exception_stack_frame.r0 = 0;
    stack_frame->exception_stack_frame.r1 = 0;
    stack_frame->exception_stack_frame.r2 = 0;
    stack_frame->exception_stack_frame.r3 = 0;
    stack_frame->exception_stack_frame.r12 = 0x0;
    stack_frame->exception_stack_frame.lr = 0x0;
    stack_frame->exception_stack_frame.pc = (rt_uint32_t)tentry;
    stack_frame->exception_stack_frame.psr = 0x01000000L;
    
	/* 返回线程栈指针 */
	return stk;
}

