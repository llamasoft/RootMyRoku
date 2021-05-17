#!/usr/bin/env bash

# Once the server setup is complete, you'll still need to do a few things:
#   1. Make sure the DNS and NFS mounts are accessible from the outside world.
#      Check your firewall settings and network routes.
#      If all else fails: `sudo iptables -I INPUT -j ACCEPT`
#   2. Upload the "remote" portion of the channel to "/exports/940E04200"
#   3. Create the magic symlink using the following command:
#      ( cd "/exports/940E04200" && ln -s "/" "./root"; )
#   4. Update the remote channel's `resolv.sh` script to point to this server.
#   5. Update the local channel's `manifest` file to point to this server's IP address.

# Tested and configured for Ubuntu LTS 20.04 Minimal.

status() { echo "[$(date)]" "$@"; }
warning() { status "$@" 1>&2; }
fail() { warning "$@"; exit 1; }

exec &> >(tee -a "/tmp/setup.log")


# Determine the current user's home directory from /etc/passwd.
# This is to work around the fact that some cloud init script
# run without a login shell.
if [[ -z "${HOME}" || -z "${USER}" ]]; then
    export USER=$(id --user --name)
    export HOME=$(getent passwd "${USER}" | cut -d":" -f6)
    status "Setting HOME to '${HOME}'."
fi
status "Script running as ${USER}."


status "Installing some basic utilities"
packages=(
    curl
    dnsmasq
    dnsutils
    fail2ban
    git
    htop
    iftop
    iotop
    jq
    less
    moreutils
    nfs-kernel-server
    rsync
    rsyslog
    screen
    vim
)
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${packages[@]}"


status "Configuring fail2ban"
sudo sed -i "" -e 's/%(sshd_backend)s/systemd/' "/etc/fail2ban/jail.conf"
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban


export NFS_DIR="/exports"
status "Creating NFS export at ${NFS_DIR}"
sudo mkdir --mode=1777 -p "${NFS_DIR}"
echo "${NFS_DIR} *(ro,async,no_subtree_check,insecure)" | sudo tee "/etc/exports" &>"/dev/null"
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server

status "Configuring iptables for NFS"
for port in 111 1110 2049 4045; do
    for protocol in tcp udp; do
        sudo iptables -I INPUT -p "${protocol}" --dport "${port}" -j ACCEPT
    done
done


status "Disabling systemd-resolved"
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
cat <<RESOLV | sudo tee "/etc/resolv.conf" &>"/dev/null"
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
RESOLV


status "Configuring dnsmasq"
cat <<DNSMASQ | sudo tee "/etc/dnsmasq.conf" &>"/dev/null"
# Don't load the host's /etc/hosts or /etc/resolv.conf
no-hosts
no-resolv

# Allow remote connections, not just local ones
interface=*

# Basic security tweaks
bogus-priv
domain-needed

# Upstream DNS servers
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4

# Block Roku and all subdomains under it
server=/roku.com/
server=/ravm.tv/

# Allow domains which are required to test for network connectivity
server=/captive.roku.com/#
server=/cigars.roku.com/#
server=/image.roku.com/#
DNSMASQ
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

status "Configuring iptables for dnsmasq"
for port in 53; do
    for protocol in tcp udp; do
        sudo iptables -I INPUT -p "${protocol}" --dport "${port}" -j ACCEPT
    done
done

status "Done"