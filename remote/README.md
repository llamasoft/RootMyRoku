This is the source code for the "remote" component of the jailbreak.  ***This is where the magic happens.***  
The contents of this directory will be loaded over NFS by the "local" component.

Key files:
- [`source/Main.brs`](./source/Main.brs) is the BrightScript file that uses a symlink exploit to install the jailbreak files.  
- `root` a symlink used to access the device's internal storage.  
  This symlink can't be checked in or uploaded properly.  
  If you wish to reproduce this exploit yourself, you'll need to create it manually.  
  (Hint: `cd remote && ln -s / root`)
- [`bootstrap.conf`](./bootstrap.conf) is the udhcpd config used to bootstrap the jailbreak process.  
  This file is used only once, and only to execute the jailbreak payload after the first reboot.
- [`payload.sh`](./payload.sh) is the primary jailbreak payload.  
  It replaces the bootstrap udhcpd config with one that allows udhcpd to continue functioning normally.  
  It's also responsible for enabling developer mode, the telnet server, and the Roku-blocking DNS.
- [`resolv.sh`](./resolv.sh) blocks communication with Roku servers by updating the device's DNS settings.