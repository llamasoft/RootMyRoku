This is the shell script used to create and configure the NFS and DNS server used by this jailbreak.  
You can use this script as a starting point if you wish to recreate the exploit yourself,
or to add extra functionality to the DNS server (e.g. ad blocking).

The shell script does _most_ of the work to set up the server, but some manual work will still be required:
- Purchasing and configuring a domain name to point to the server's IP address.
- Uploading the "remote" component to the NFS `/exports` directory.
- Creating the `root` symlink in the remote component.  (Hint: `cd remote && ln -s / root`)
- Updating the local component's `manifest` file to point to the server's IP address and NFS exports path.
- Updating the remote component's `resolv.sh` file to point to the server's DNS name.