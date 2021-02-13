# docker-traefik

Run Træfik in Docker, for Docker.


## Platform Requirements

- Python 3. Do yourself a favor and kick Python 2 out of your life today; it really is as simple as `ansible_python_interpreter: python3` in your inventory
- yum or apt package manager
- Properly configured to live in the 21st century — i.e. `yum install python-pip3` is expected to work with no `subscription-manager`-this or EPEL-that nonsense.

# Usage

Minimum configuration:

```
- name: Træfik
  hosts: all
  roles:
    - role: roles/docker-traefik
  vars:
    traefik_root_location: /srv/traefik
```

See `defaults/main.yml` for all the variables you can tweak.
