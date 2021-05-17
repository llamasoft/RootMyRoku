#!/bin/sh

status() { echo "[$(date)]" "$@"; }
warning() { status "$@" 1>&2; }
fail() { warning "$@"; exit 1; }

exec >>"/tmp/payload.log" 2>&1


enable_developer_mode() {
    # Overlay /proc/cmdline to enable developer mode.
    # This unlocks all of the busybox commands like wget and telnetd.
    # If this takes place before Application starts, it also:
    #   - Unlocks debug and secret screens in the main menu.
    #   - Unlocks developer commands in the port 8080 debug terminal.
    if ! grep -qF "dev=1" "/proc/cmdline"; then
        status "Enabling developer mode"
        cmdline=$(cat "/proc/cmdline")
        printf "dev=1 %s" "${cmdline}" > "/tmp/cmdline"
        chmod 644 "/tmp/cmdline"
        mount -o bind,ro "/tmp/cmdline" "/proc/cmdline"

        # Given that we only enable developer mode once at boot,
        # take this opportunity to purge the current developer channel.
        # If we don't, it'll trigger an NFS mount every boot.
        # If the NFS mount fails, it can cause a boot loop.
        rm "/nvram/incoming/dev.zip"* 2>/dev/null
    fi
}

enable_telnetd() {
    if pgrep -f telnetd >/dev/null 2>&1; then
        return
    fi

    # Try different busybox binaries until we find one that works.
    # The system one should work if the developer overlay was successful,
    # but it never hurts to be careful.
    telnetd_started=0
    for busybox in "/bin/busybox" "/nvram/busybox" "/nvram/busybox-$(uname -m)"; do
        if [[ ! -e "${busybox}" ]]; then
            continue
        fi

        status "Starting telnetd from ${busybox}"
        chmod +x "${busybox}" >/dev/null 2>&1
        if "${busybox}" telnetd -l /sbin/loginsh -p 8023; then
            telnetd_started=1
            break
        fi
    done

    if [[ "${telnetd_started}" -ne 1 ]]; then
        warning "Failed to start telnetd :("
    fi
}

enable_custom_dns() {
    if pgrep -f "resolv.sh" >/dev/null 2>&1; then
        return
    fi

    # This custom DNS blocks communication with Roku's servers.
    # This disables logging, channel updates, and firmware updates.
    # See `resolv.sh` for details.
    status "Enabling custom DNS nameserver"
    chmod +x "/nvram/resolv.sh"
    nohup "/nvram/resolv.sh" >/dev/null 2>&1 &
}

enable_persistence() {
    # Check if we're using the bootstrapping config file.
    # If we are, we need to replace it with a fully functional one.
    # This restores actual udhcpd functionality for pairing speakers,
    # remotes, and other devices.
    restart_udhcpd=0
    script_path=$(readlink -f "$0")
    if ! grep -qF "${script_path}" "/nvram/udhcpd-p2p.conf"; then
        status "Replacing bootstrap udhcpd config"
        {
            # Base the new config file off the system default one,
            # but remove and replace the `notify_file` and `auto_time` values.
            grep -vF -e "notify_file" -e "auto_time" "/lib/wlan/realtek/udhcpd-p2p.conf"

            # Add the current script as the `notify_file` target.
            echo
            echo "notify_file ${script_path}"

            # Cause the `notify_file` target to be called early during boot.
            # This makes sure that our payload is run before the main Application starts.
            # See `bootstrap.conf` for details.
            echo "auto_time 1"

            # Make absolutely sure that the config file ends with an empty line.
            # See `bootstrap.conf` for details.
            echo
        } > "/nvram/udhcpd-p2p.conf"

        # udhcpd is currently running with the bootstrap config file.
        # We need to recreate the active config file by simulating
        # the changes made by `/lib/wlan/network-functions`.
        {
            cat "/nvram/udhcpd-p2p.conf"
            interface_name=$(cat "/tmp/p2p-interface-name" 2>/dev/null)
            if [[ -n "${interface_name}" ]]; then
                echo "interface ${interface_name}"
            fi
        } > "/tmp/udhcpd-p2p.conf"

        restart_udhcpd=1
    fi

    # Now that the initial payload has already run, we don't need to run as often.
    # If the active config still contains an `auto_time` value, remove it.
    # The default value for `auto_time` is 2 hours which is good enough.
    if grep -qF "auto_time" "/tmp/udhcpd-p2p.conf"; then
        status "Removing auto_time config value"
        sed -i "/auto_time/d" "/tmp/udhcpd-p2p.conf"
        restart_udhcpd=1
    fi

    if [[ "${restart_udhcpd}" -ne 0 ]]; then
        # We can't `pkill udhcpd` or we'll end up killing ourselves too.
        # We need to kill all instances of udhcpd except the brand new one.
        current_pids=$(pgrep udhcpd)
        status "Spawning replacement udhcpd"
        udhcpd "/tmp/udhcpd-p2p.conf"

        if [[ -n "${current_pids}" ]]; then
            status "Killing previous udhcpd instances"
            kill ${current_pids}
        fi
    fi
}

# Do our magic, then call the default udhcpd notify script.
enable_developer_mode
enable_telnetd
enable_custom_dns

# The persistence method must run last as it may restart udhcpd.
# This payload is launched by the current udhcpd, so it may kill us too.
enable_persistence

if [[ $# -gt 0 ]]; then
    status "Calling default notify handler"
    /lib/wlan/realtek/udhcpd-notify.sh "$@" >/dev/null 2>&1
fi
