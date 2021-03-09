"""`| as_foreman_parameters` helper.

Turns a data structure like

     a: b
     c: false

into a data structure like

     - name: a
       value: b
       parameter_type: string
     - name: c
       value: false
       parameter_type: boolean

"""

from ansible.module_utils import six

class FilterModule(object):
    def filters(self):
        return dict(as_foreman_parameters=as_foreman_parameters)

def as_foreman_parameters(struct):
    def typename(v):
        if isinstance(v, six.string_types):
            return "string"
        elif type(v) == bool:
            return "boolean"
        elif type(v) == int:
            return "integer"
        else:
            raise ValueError("Unable to map %s to a Foreman parameter type" %
                             type(v).__name__)

    return [dict(name=k, value=struct[k], parameter_type=typename(struct[k]))
            for k in struct.keys()]

