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
apt-get -qy install ipxe
perl -i -pe 's|GRUB_DEFAULT=.*|GRUB_DEFAULT=saved|' /etc/default/grub
cat > /boot/ipxe.ipxe <<IPXE_SCRIPT
#!ipxe

<% iface  = @host.interfaces.first %>
ifopen net0
set net0/ip <%= iface.ip %>
set net0/netmask <%= iface.subnet.mask %>
set net0/gateway <%= iface.subnet.gateway %>
set dns <%= iface.subnet.dns_primary %>

chain {{ foreman_frontend_url | replace("https://", "http://") }}unattended/iPXE

IPXE_SCRIPT
update-grub

cat >> /root/.bash_aliases <<ALIAS
alias foreman-reinstall-on-next-reboot='grub-reboot "Network boot (iPXE)"'
ALIAS

<%= snippet_if_exists(@host.hostgroup.to_s + " finish snippet") %>
