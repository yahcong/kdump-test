#include <linux/module.h>
#include <linux/init.h>
#include <linux/input.h>
#include <linux/version.h>
#include <linux/proc_fs.h>
#include <asm/uaccess.h>

#define PROCNAME "driver/altsysrq"

static struct input_dev *g_dev = NULL;


static int altsysrq_register_device(struct input_dev **pdev)
{
        struct input_dev *dev;
        int ret;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,18)
        dev = (struct input_dev *)input_allocate_device();
        if (!dev) {
                return -ENOMEM;
        }
#else
        dev = kmalloc(sizeof(struct input_dev), GFP_KERNEL);
        if (!dev) {
                return -ENOMEM;
        }
        memset(dev, 0, sizeof(struct input_dev));
        init_input_dev(dev);
#endif
        dev->evbit[0] = BIT(EV_KEY);

        set_bit(KEY_LEFTALT, dev->keybit);
        set_bit(KEY_SYSRQ, dev->keybit);
        set_bit(KEY_C, dev->keybit);

        ret = input_register_device(dev);

        if (ret) {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,18)
                input_free_device(dev);
#else
                kfree(dev);
#endif
                return ret;
        }

        *pdev = dev;

        return 0;
}

static void altsysrq_unregister_device(struct input_dev *dev)
{
        input_unregister_device(dev);
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,18)
        input_free_device(dev);
#else
        kfree(dev);
#endif
}

static void altsysrq_input_altsysrq_event(struct input_dev *dev, int key)
{
        input_event(dev, EV_KEY, KEY_LEFTALT, 1);
        input_event(dev, EV_KEY, KEY_SYSRQ, 1);
        input_event(dev, EV_KEY, key, 1);

        input_sync(dev);

        input_event(dev, EV_KEY, key, 0);
        input_event(dev, EV_KEY, KEY_SYSRQ, 0);
        input_event(dev, EV_KEY, KEY_LEFTALT, 0);
}

static int altsysrq_write_proc(struct file *filep, const char *buf, unsigned long len, void *data)
{
        char c;
        printk("altsysrq_write_proc...\n");

        if (copy_from_user(&c, buf, 1)) return -EFAULT;

        switch (c) {
        case 'c':
                altsysrq_input_altsysrq_event(g_dev, KEY_C);
                break;
        }
        return 1;
}

static const struct file_operations altsysrq_proc_fops = {
        .owner = THIS_MODULE,
        .read = NULL,
        .write = altsysrq_write_proc,
};

static int __init altsysrq_init(void)
{
        int result;
        struct proc_dir_entry *entry;

        printk("altsysrq_init...\n");

        result = altsysrq_register_device(&g_dev);
        if (result < 0) {
                return result;
        }

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,32)
        entry = create_proc_entry(PROCNAME, S_IWUGO, NULL);
        if (!entry) {
                altsysrq_unregister_device(g_dev);
                return -EBUSY;
        }
        entry->write_proc = altsysrq_write_proc;
#else
        if ((entry = proc_create_data(PROCNAME, S_IWUGO, NULL,
                                &altsysrq_proc_fops, NULL)) == NULL) {
                altsysrq_unregister_device(g_dev);
                return -ENOMEM;
        }
#endif

        return 0;
}

static void __exit altsysrq_exit(void)
{
        //printk("altsysrq_exit...\n");

        remove_proc_entry(PROCNAME, NULL);

        altsysrq_unregister_device(g_dev);
        g_dev = NULL;
}

module_init(altsysrq_init);
module_exit(altsysrq_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("altsysrq");
