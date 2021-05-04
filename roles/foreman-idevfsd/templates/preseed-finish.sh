set -e -x

# Add missing lines for swap partitions to /etc/fstab
for device in $(blkid -o device); do
    (
        eval "$(blkid -o export $device)"
        if [ "$TYPE" != "swap" ]; then exit 0; fi
        if [ -z "$UUID" ]; then exit 0; fi
        if grep -qw "$DEVNAME" /etc/fstab; then exit 0; fi
        if grep -qw "$UUID" /etc/fstab; then exit 0; fi
        case "$device" in
            /dev/mapper/*)
                echo -e "$device\tswap\tswap\tdefaults\t0\t0" >> /etc/fstab ;;
            *)
                echo -e "UUID=$UUID\tswap\tswap\tdefaults\t0\t0" >> /etc/fstab ;;
        esac
    )
done

<% if !( host_param('epfl_root_authorized_keys').blank? ||
         host_param('epfl_root_authorized_keys').strip.empty? ) %>
# Add ssh keys from Foreman's 'epfl_root_authorized_keys' host / hostgroup parameter
mkdir -p ~root/.ssh
cat << EOF > ~root/.ssh/authorized_keys
<%= host_param('epfl_root_authorized_keys') %>
EOF

chmod 0700 ~root/.ssh
chmod 0600 ~root/.ssh/authorized_keys
chown -R root: ~root/.ssh

# Apply SELinux context with restorecon, if available:
command -v restorecon && restorecon -RvF ~root/.ssh || true
<% end %>

# Install open-vm-tools (https://docs.vmware.com/en/VMware-Tools/11.2.0/com.vmware.vsphere.vmwaretools.doc/GUID-C48E1F14-240D-4DD1-8D4C-25B6EBE4BB0F.html)
apt-get -qy update
apt-get -qy install open-vm-tools

# Make it possible to reinstall from Foreman using an ssh command
apt-get -qy install jq kexec-tools
cat >> /usr/local/sbin/foreman-reinstall <<'FOREMAN_REINSTALL'
#!/bin/bash

set -e -x

[ -n "$1" ] || {
  echo >&2 "I'm sorry Dave, but I cannot let you do that."
  exit 2
}

tmpdir=/run/reboot

rm -rf "$tmpdir" || true
mkdir "$tmpdir"

wget -O "$tmpdir"/params.json "<%= foreman_url('kexec').gsub(/token=.*/, '') %>token=$1"

eval $(jq -r '. | to_entries | .[] | select(.value | type == "string")
                | "kexec_" + .key + "=\"" + .value + "\""' < "$tmpdir"/params.json)

wget -O "$tmpdir"/kernel "$kexec_kernel"
wget -O "$tmpdir"/initram "$kexec_initram"

kexec --force --debug --initrd="$tmpdir"/initram \
      --append="$kexec_append" \
      $(jq -r '.extra | .[] ' "$tmpdir"/params.json) "$tmpdir"/kernel

FOREMAN_REINSTALL
chmod 755 /usr/local/sbin/foreman-reinstall

# Kubespray-specific comfort settings
cat > /etc/profile.d/etcd-env.sh << 'ETCD_ENV'
if [ -r /etc/etcd.env ]; then
  eval "$(perl -ne 'print if s/^ETCDCTL_/export ETCDCTL_/' /etc/etcd.env)"
fi
ETCD_ENV

<%= snippet_if_exists(@host.hostgroup.to_s + " finish snippet") %>
