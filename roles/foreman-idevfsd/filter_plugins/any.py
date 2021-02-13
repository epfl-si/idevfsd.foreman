"""`| any(test)` helper.

e.g.

  {{ _my_registered_cmd.results | any("changed") }}
"""

class FilterModule(object):
    def filters(self):
        return dict(any=any)

def any(l, slot):
    for item in l:
        if item.get(slot, False):
            return True

    return False

