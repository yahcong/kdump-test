/*
 * Copyright (c) 2016 Red Hat, Inc. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

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
