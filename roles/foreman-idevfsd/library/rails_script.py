#!/usr/bin/python
# -*- coding: utf-8 -*-

"""Run a script through the Rails console."""

EXAMPLES = """
- name: "Foreman administrator password"
  rails_script:
    interpreter:
      - docker
      - exec
      - "-i"
      - foreman
      - bundle
      - exec
      - rails
      - console
    postcondition: |
      User::try_to_login "admin", "{{ foreman_admin_password }}"
    recheck: yes
    action: |
      admin = User.unscoped.find_by_login "admin"
      admin.upgrade_password "{{ foreman_admin_password }}"
      admin.save
"""

DOCUMENTATION = """
---
module: rails_script
short_description: Run a script through the Rails console
description:
   - Run a Ruby script
options:
  postcondition:
    type: string
    description: |
        If (and only if) this Ruby snippet returns a truthy value,
        the Ansible result is green (i.e. no change). If `postcondition`
        is omitted, simply run `action`.
  action:
    type: string
    description: |
        A Ruby snippet making the desired change. Will be skipped
        if `postcondition` previously returned a truthy value.
        If so desired, the action snippet may call `exit_json`
        to precisely set the Ansible outcome. Otherwise,
        { "changed": True } is assumed if `action` doesn't throw.
  recheck:
    type: boolean
    default: false
    description: |
        If true, run the postcondition again after the
        action; give off a failure (red) if the postcondition
        still doesn't hold
   interpreter:
     type: string | list
     default: ["bundle", "exec", "rails", "console"]
     description: |
        How to invoke the Rails console. Can be either
        a string (which will be passed to a shell),
        or an argv list
"""

from ansible.module_utils import six
from ansible.module_utils.basic import AnsibleModule
try:
    from ansible.errors import AnsibleError
except ImportError:
    AnsibleError = Exception

import re
import subprocess
import json

class RailsScriptTask(object):

    module_spec = dict(
        argument_spec=dict(
            postcondition=dict(type='str'),
            action=dict(type='str'),
            recheck=dict(type='bool'),
            interpreter=dict(type='raw',
                             default = ["bundle", "exec", "rails", "console"])))

    def __init__(self):
        self.module = AnsibleModule(**self.module_spec)

    def run(self):
        script = self._make_script()

        interpreter = self.module.params.get("interpreter")
        result = subprocess.run(interpreter,
                       check=True,
                       shell=isinstance(interpreter, six.string_types),
                       input=script, encoding='utf-8',
                       stdout = subprocess.PIPE)

        # The Rails console is quite chatty.
        # We are looking for one line that is correct
        # JSON and has the marker that `exit_json` set
        # on the Ruby side.
        status = None
        for line in result.stdout.splitlines():
            try:
                parsed = json.loads(line)
                if (isinstance(parsed, dict)
                    and (parsed.get("_from_") == "rails_script")):
                    del parsed["_from_"]
                    status = parsed
                    break
            except json.JSONDecodeError:
                continue

        if status is None:
            status = dict(failed=True,
                          stdout=result.stdout,
                          stderr=result.stderr)
        self.module.exit_json(**status)

    def _indent(self, some_code, indent_with):
        return re.sub(r"^(?=.)", indent_with, some_code, 0, re.MULTILINE)

    def _wrap_in_ruby_function(self, name, body):
        subst = dict(
            name=name,
            unwrapped_name="unwrapped_%s" % name)
        return (
            ("def %(unwrapped_name)s\n" % subst) +
            self._indent(body, "  ") +
            "\nend\n" + """

unless defined? %(unwrapped_name)s
  print "Error in function body for %(unwrapped_name)s\n"
  exit
end
""" % subst + 
# Note that we just `exit` above, because we need
# the entire Ruby interpreter stdout in order to
# troubleshoot compile-time errors. Not so with
# runtime errors below; we want to call `exit_json`
# on these, so as to reduce clutter.
"""
def %(name)s
  begin
    %(unwrapped_name)s
  rescue Exception => e
    exit_json(:failed => true, :in => "%(name)s",
              :ruby_exn_class => e.class.to_s,
              :ruby_exn => e.to_s,
              :ruby_backtrace => e.backtrace.join("\n"))
  end
end

""" % subst)

    def _make_script(self):
        script = """
require 'json'

def exit_json(**args)
  args["_from_"] = "rails_script"
  print "\n"
  print args.to_json
  print "\n"
  exit
end

"""

        postcondition = self.module.params.get("postcondition")
        if postcondition:
            script = script + self._wrap_in_ruby_function(
                "ansible_postcondition_", postcondition) + """

if ansible_postcondition_
  exit_json(:changed => false)
end

"""

        action = self.module.params.get("action")
        if action:
            script = script + self._wrap_in_ruby_function(
                "ansible_action_", self.module.params['action']) + """

ansible_action_

"""
        else:
            # Post-condition didn't check out, there's nothing else we can do.
            return script + """
exit_json(:changed => false, :failed => true)
"""
            

        if (postcondition and self.module.params.get("recheck", True)):
            script = script + """
                
if ! ansible_postcondition_
  exit_json(:changed => true, :failed => true)
end

"""

        script = script + """

exit_json(:changed => true)

"""
        return script


if __name__ == '__main__':
    RailsScriptTask().run()
