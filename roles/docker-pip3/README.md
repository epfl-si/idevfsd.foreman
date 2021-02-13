# docker-pip3

This is a dead-simple role that makes `docker_image:` etc. tasks work
on the remote host. It installs `pip3` and the required Python
dependencies.

## Platform Requirements

- Python 3. Do yourself a favor and kick Python 2 out of your life today; it really is as simple as `ansible_python_interpreter: python3` in your inventory
- yum or apt package manager
- Properly configured to live in the 21st century — i.e. `yum install python-pip3` is expected to work with no `subscription-manager`-this or EPEL-that nonsense.

## Usage

1. Apply the role from your playbook with `gather_facts` enabled (this is the default)
2. There is no step 3 (nor is there a step 2)
