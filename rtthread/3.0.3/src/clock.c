#include <rtthread.h>
#include <rthw.h>

static rt_tick_t rt_tick = 0;
extern rt_list_t rt_thread_priority_table[RT_THREAD_PRIORITY_MAX];


void rt_tick_increase(void)
{
    rt_ubase_t i = 0;
    struct rt_thread *thread;
    rt_tick ++;
    
    /* 1.遍历线程就绪数组中的每一个线程 
     * ....如果线程的 remaining_tick>0，那么对齐进行递减
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

    /* 2.进行系统调度 */
    rt_schedule();
}
