/*
*************************************************************************
*                             ������ͷ�ļ�
*************************************************************************
*/
#include <rtthread.h>
#include <rthw.h>


/*
*************************************************************************
*                                 ȫ�ֱ���
*************************************************************************
*/
/* �߳̿��ƿ�ָ�룬����ָ��ǰ�߳� */
struct rt_thread *rt_current_thread;

/* �߳̾����б� */
rt_list_t rt_thread_priority_table[RT_THREAD_PRIORITY_MAX];

/* �߳������б� */
rt_list_t rt_thread_defunct;

/* �����߳� */
extern struct rt_thread idle;
extern struct rt_thread rt_flag1_thread;
extern struct rt_thread rt_flag2_thread;

/*
*************************************************************************
*                               ����ʵ��
*************************************************************************
*/

/* ��ʼ��ϵͳ������ */
void rt_system_scheduler_init(void)
{	
	register rt_base_t offset;	

	
	/* �߳̾����б��ʼ�� */
	for (offset = 0; offset < RT_THREAD_PRIORITY_MAX; offset ++)
	{
			rt_list_init(&rt_thread_priority_table[offset]);
	}
	
	/* ��ʼ����ǰ�߳̿��ƿ�ָ�� */
	rt_current_thread = RT_NULL;
	
	/* ��ʼ���߳������б����̴߳�����û������֮ǰ�ᱻ���뵽����б� */
	rt_list_init(&rt_thread_defunct);
}

/* ����ϵͳ������ */
void rt_system_scheduler_start(void)
{
	register struct rt_thread *to_thread;
	

	/* �ֶ�ָ����һ�����е��߳� */
	to_thread = rt_list_entry(rt_thread_priority_table[0].next,
							  struct rt_thread,
							  tlist);
	rt_current_thread = to_thread;
														
	/* �л�����һ���̣߳��ú�����context_rvds.S��ʵ�֣���rthw.h������
       ����ʵ�ֵ�һ�������л�����һ����ຯ����C�ļ��е��õ�ʱ��
       ������βΣ���ִ�е�ʱ��Ὣ�βδ��˵�CPU�Ĵ���r0��*/
	rt_hw_context_switch_to((rt_uint32_t)&to_thread->sp);
}

/* ϵͳ���� */
void rt_schedule(void)
{
    struct rt_thread *to_thread;
    struct rt_thread *from_thread;

    /* 1.�����ǰ�ǿ����̣߳�����ִ�з���ʱ�߳� */
    if (rt_current_thread == &idle)
    {
        if (rt_flag1_thread.remaining_tick == 0)
        {
            from_thread = rt_current_thread;
            to_thread   = &rt_flag1_thread;
            rt_current_thread = to_thread;
        }
        else if (rt_flag2_thread.remaining_tick == 0)
        {
            from_thread = rt_current_thread;
            to_thread   = &rt_flag2_thread;
            rt_current_thread = to_thread;
        }
        else
        {
            return;
        }
    }

    /* 2.�����ǰ�Ƿǿ����̣߳�����ִ�з���ʱ�߳�
     * ....û�з���ʱ�̣߳������ǰ�̷߳���ʱ����ô����ִ�е�ǰ�߳�
     * ....�����ǰ�߳�Ҳ������ʱ����ôִ�п����߳�
     */
    else
    {
        if (rt_current_thread == &rt_flag1_thread)
        {
            if (rt_flag2_thread.remaining_tick == 0)
            {
                from_thread = rt_current_thread;
                to_thread   = &rt_flag2_thread;
                rt_current_thread = to_thread;
            }
            else if (rt_current_thread->remaining_tick != 0)
            {
                from_thread = rt_current_thread;
                to_thread   = &idle;
                rt_current_thread = to_thread;
            }
            else
            {
                return ;
            }
        }
        else if (rt_current_thread== &rt_flag2_thread)
        {
            if (rt_flag1_thread.remaining_tick == 0)
            {
                from_thread = rt_current_thread;
                to_thread   = &rt_flag1_thread;
                rt_current_thread = to_thread;
            }
            else if (rt_current_thread->remaining_tick != 0)
            {
                from_thread = rt_current_thread;
                to_thread   = &idle;
                rt_current_thread = to_thread;
            }
            else
            {
                return ;
            }
        }
    }
    /* �����������л� */
    rt_hw_context_switch((rt_uint32_t)&from_thread->sp,(rt_uint32_t)&to_thread->sp);	

}
