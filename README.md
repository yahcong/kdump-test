# Kdump test suite

This test suite covers part of kdump testing. It works on RHEL/CentOS/Fedora and possible their derivations.
The primary aim is to test kexec-tools package.
The source of kexec-tools rpm is [here](http://pkgs.fedoraproject.org/cgit/rpms/kexec-tools.git)

## Kdump test brief introduction
Most of test case will install the required package and change corresponding config itself. User only need to execute runtest.sh in each test case directory with root privilege, either manually or by [restraint](http://restraint.readthedocs.io).

You need to  Make sure dump target has enough space to save vmcore. Usually it is the size of physical memory.

Following are the general workflow in each test case.

1. Install these additional packages, like:
    * kexec-tools
    * crash
    * kernel-debuginfo

2. Modify configuration file /etc/kdump.conf.

3. Test the corresponding crash or kdump function.

## Contributing
### Bug report
If you find some bugs of the test suite, feel free to report it in [issue page](https://github.com/kdump-test/kdump-test/issues).

If you find some bugs of kdump on Fedora, please file the report in [Bugzilla with product "Fedora"](https://bugzilla.redhat.com/enter_bug.cgi?product=Fedora).

If you find some bugs of kdump on Red Hat Enterprise Linux, please file the report in [Red Hat Bugzilla](https://bugzilla.redhat.com/enter_bug.cgi?classification=Red%20Hat).

### Coding
If you want to contribute in code, feel free to send your pull request.
