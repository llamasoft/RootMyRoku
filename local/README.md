This is the source code for the "local" component of the jailbreak.  
When zipped and uploaded as a channel, this connects to the "remote" component of the jailbreak over NFS.

Key files:
- [`manifest`](./manifest) is the channel manifest that file enables the NFS mounting of the remote component.  
- [`source/Main.brs`](./source/Main.brs) is the BrightScript file that will execute if the NFS mount fails or is patched.