# Root My Roku

A persistent root jailbreak for RokuOS v9.4.0 build 4200 devices using a Realtek WiFi chip.  
A big thank you to ammar2 and popeax from the [Exploitee.rs](https://exploitee.rs/) Discord for helping discover and develop this.

## Features

- Spawns a telnet server running as root on port 8023.
- Enables the low-level hardware developer mode.
- Adds many new secret screens and debug features to the main menu.
- *Blocks channel updates, firmware updates, and all communication with Roku servers.*

## Usage

1. Download any new channels you might want to use after the jailbreak.  
   Once you jailbreak your device, all communication with Roku's servers will be blocked.  
   Any channels you currently have installed should continue to work.  
   Please see the F.A.Q. below for details.
1. Enable [Developer Settings](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md#step-1-set-up-your-roku-device-to-enable-developer-settings) on your Roku device.
1. Download the latest `dev-channel.zip` from the [releases page](https://github.com/llamasoft/RootMyRoku/releases/latest).
1. Upload `dev-channel.zip` using the guide from the previous step.
1. Follow the prompts on screen, then reboot to jailbreak!


## F.A.Q.

### Which devices does this affect?

Affected devices include _almost all_ Roku TVs and some Roku set-top boxes.  
In theory, any Roku device running RokuOS v9.4.0 build 4200 or earlier that uses a Realtek WiFi chip is vulnerable.  
You can check your current software version from Settings -> System -> About.  
While it is not possible to manually check your WiFi chip manufacturer, the channel
provided for this exploit will tell you if your device is vulnerable or not.

### Can this brick my device?

No!  It makes no changes to the underlying firmware that the device runs.  
If anything bad happens, a [factory reset](https://support.roku.com/article/208757008) will always recover your device.

### How do I un-jailbreak my device?

You have two options:
- Factory reset your device.  This will clear NVRAM and remove the jailbreak.
- Using the telnet server on port 8023, delete `/nvram/udhcpd-p2p.conf` and reboot.

### Is Roku aware of this exploit?

Some of the critical components required for the exploit chain no longer work in RokuOS v10.  
The NFS mount option that is used for arbitrary file modification gets disabled,
and the service used for persistence and privilege escalation is no longer used.

While RokuOS v10 has started rolling out, many devices have not received the update yet.

### Why does the jailbreak block communication with Roku servers?

This is a precautionary measure to prevent the jailbreak from being disabled or removed.  
In the past, Roku has taken some _creative_ measures to forcefully patch jailbroken devices.
One such example was an update to the screensaver channel that would check for a telnet service,
connect to it, and command it to un-root and update the device.

Unfortunately, the servers used for channel and firmware updates the same ones used
to communicate with Roku in general.  Blocking updates means that no new channels can
be installed and that certain features like "My Feed" and "Search" will no longer work.  
Applications that communicate with other services (e.g. YouTube, Netflix, HBO) will still work.

### How can I prevent my non-jailbroken Roku from updating?

Edit your modem/router's DNS settings to use the IP address of `dns.rootmyroku.com`.  
You can find the current IP address using `nslookup`, `dig`, or [online DNS lookup tools](https://dnstools.ws/lookup/dns.rootmyroku.com/A/).

### Why should I trust the code you execute on my device?

You don't have to!

All of the files required to reproduce this exploit are available in this repo:
- The local channel used to load the remote payload is available under `local`.
- The remote payload loaded over NFS is available under `remote`.
- The script used to create the NFS and DNS servers are available under `server`.


## Exploit Details

There's two main vulnerabilities that make this exploit possible: arbitrary file modification and privilege escalation.

RokuOS actually does a decently good job at sandboxing channels to prevent them from accessing the underlying filesystem.
In addition to running as a restricted user, a software sandbox, and a chroot jail, Roku's Linux kernel has
[grsecurity patches](https://grsecurity.net/) applied.  These patches mitigate common exploit techniques used in 
jailbreaks and privilege escalation.  Furthermore, the entire root filesystem is read-only and baked into the firmware.
Only persistent storage (NVRAM) and temp directories are writable.

### Arbitrary File Modification

Two things conspired to allow arbitrary file modification.  The first was that an undocumented `pkg_nfs_mount`
[channel manifest](https://developer.roku.com/en-gb/docs/developer-program/getting-started/architecture/channel-manifest.md) option.
This option was meant to reduce the software development lifecycle when creating a channel by allowing the channel's source code
to be hosted on a different machine using [NFS](https://en.wikipedia.org/wiki/Network_File_System).
This removes the need to re-package and re-upload channels after every code change.  
The second was a shortcoming of the grsecurity patches and the Linux kernel in general: symlinks over NFS act weird.
While grsecurity was configured specifically to not allow symlinking to directories owned by other users,
the ownership and permission checks no longer work properly when the symlink resides on an NFS mount.
This allows us to create a symlink in the remote channel's package that points to the root of the main filesystem.
(See [`remote/source/Main.brs`](/remote/source/Main.brs) for details.)  
This provided us with the ability to modify persistent storage and temp files, but only as the app user.

### Privilege Escalation

From there, we discovered that the process that configures udhcpd (a DHCP service used for pairing speakers and remotes)
for Realtek chipsets could be made to read a config file from NVRAM, a location that the app user has access to.
If we could leverage it properly, it would let us manipulate a service running as the root user and also give us a means
of persisting across reboots.  Thankfully, udhcpd has an option for executing a script (`notify_file`) with a single parameter (`lease_file`)
whenever a DHCP lease is created.  It wasn't perfect though: the udhcpd service would only run the script if it has the "execute" bit set.
While we could create arbitrary files using our previous exploit, we didn't have control over the file's permissions and
as a result, none of the payload scripts we create are marked as executable.  To make matters more difficult, we couldn't pass the
payload script as `lease_file` to the built-in shell executables because udhcpd would overwrite the script contents first.  
Ultimately, the solution involved creating a `lease_file` value polyglot that is both an AWK script and a legal file name.
(See [`remote/bootstrap.conf`](/remote/bootstrap.conf) for details.)

## Footnote

If anyone at Roku is reading this: you desperately need a _real_ bug bounty program.

Without one, there's little incentive to research and report vulnerabilities
when you're not sure if you'll be rewarded for your efforts or not.
While we took this project on for fun as a hobby, almost no professional
security researchers are going to dedicate as much effort as we did for a "maybe".