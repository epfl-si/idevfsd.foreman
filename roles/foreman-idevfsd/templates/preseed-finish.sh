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

<%= snippet_if_exists(@host.hostgroup.to_s + " finish snippet") %>
