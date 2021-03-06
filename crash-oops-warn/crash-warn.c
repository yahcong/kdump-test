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

/*
 * Just an skeleton module.  Useful for debugging.
 *
 * Written by: Prarit Bhargava <prarit@redhat.com>
 *
 * Please don't clutter this file with a bunch of bells-and-whistles.  It
 * is meant to be a simple module.
 *
 * How to use?
 * when loaded the kernel will warn.  then unload the module and do
 * echo 1 > /proc/sys/kernel/panic_on_warn
 * and reload the module.  the kernel will panic.
 *
 * Because panic_on_warn added in rhel7 kernel-3.10.0-206.el7
 * and rhel6 kernel-2.6.32-532.el6.
 * so this case is only applicable to kernel later than that.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

static int dummy_arg = 0;

void dummy_greetings(void)
{
        printk("This module has loaded.\n");
        if (dummy_arg)
                printk("And dummy_arg is %d.\n", dummy_arg);
}

static int init_dummy(void)
{
        dummy_greetings();
        WARN(1, "hello!");
        return 0;
}

static void cleanup_dummy(void)
{
        printk("unloading module\n");
}

module_init(init_dummy);
module_exit(cleanup_dummy);

MODULE_LICENSE("GPL"); // avoid GPL issues

module_param(dummy_arg, int, 0444);
MODULE_PARM_DESC(dummy_arg, "An argument for this module");
