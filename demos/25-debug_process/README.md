# Debugging a stuck process

This illustrates:
* How to emulate connection issues with some host using iptables
* How to exercise a Remote downloader directly
* How to use some basic process inspection tools (`py-spy` and `strace`)

Original Issue: https://github.com/pulp/pulpcore/issues/5439

## Setup

1. Get a pulp developmen instance running
2. Copy this content to somewhere you can access from inside the container
3. From host, run `sudo ./iptables-save.sh` to create your iptables rules backup.
    * This is just for convenience, the defaults are restored on reboot
4. From container, run `./run.sh`.
    * This runs `./reproducer.py`, which downloads a big rpm from fedora using a remote downloader.
    * For convenience, it saves the reproducer process pid to `/tmp/pid`
5. From host, before the download finishes, run `./block-domain.sh`

Nice, now you should have a hanging process with pid equal `$(cat /tmp/pid)`!

## Debug

This is just some basic py-spy and strace usage. If you know more tricks, please share!

> [!IMPORTANT]
> I tried using gdb with python-gdb but couldnt get it to work...
> See: https://wiki.python.org/moin/DebuggingWithGdb

```bash
> PID="$(cat /tmp/pid)"
>
> # shows the C call where it is hanging
> strace -p $PID
>
> # shows the stack trace of all process threads
> py-spy dump -p $PID
>
> # shows the stack trace of all process threads + local variables
> py-spy dump -lp $PID
```



