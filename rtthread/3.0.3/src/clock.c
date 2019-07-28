#include <rtthread.h>
#include <rthw.h>

static rt_tick_t rt_tick = 0;
extern rt_list_t rt_thread_priority_table[RT_THREAD_PRIORITY_MAX];


void rt_tick_increase(void)
{
    rt_ubase_t i = 0;
    struct rt_thread *thread;
    rt_tick ++;
    
    /* 1.�����߳̾��������е�ÿһ���߳� 
     * ....����̵߳� remaining_tick>0����ô������еݼ�
     */
    for (i=0; i<RT_THREAD_PRIORITY_MAX; i++)
    {
        thread = rt_list_entry(rt_thread_priority_table[i].next, 
                                struct rt_thread,
                                tlist);
        if (thread->remaining_tick > 0)
        {
            thread->remaining_tick --;
        }
    }

    /* 2.����ϵͳ���� */
    rt_schedule();
}
