set -e -x

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

<%= snippet_if_exists(@host.hostgroup.to_s + " finish snippet") %>
