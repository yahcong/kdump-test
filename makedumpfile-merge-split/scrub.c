string scrub_opt()
{
    return "\n";
}

string scrub_usage()
{
    return "\n";
}

static void scrub_showusage()
{
    printf("usage : scrub %s", smod_usage());
}

string scrub_help()
{
    return "Help";
}

int scrub()
{
    struct list_head *first = &(init_task.tasks);
    struct list_head *node = first;
    struct task_struct *task;
    unsigned long offset = (unsigned long)first - (unsigned long)&init_task;

    do {
        task = (struct task_struct *)((unsigned long)node - offset);
        memset((char *)&(task->utime), 'X', sizeof(init_task.utime));
        node = node->next;
    } while (node != first);


    memset((char *)&jiffies, 'X', sizeof(jiffies));

    return 1;
}
