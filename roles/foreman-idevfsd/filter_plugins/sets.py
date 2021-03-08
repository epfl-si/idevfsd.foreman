"""`| valuesets` helper.

e.g.

  {{ _my_list_of_dicts_with_always_the_same_keys | valuesets }}
"""

class FilterModule(object):
    def filters(self):
        return dict(valuesets=valuesets)

def valuesets(list_of_dicts):
    valuesets = {}
    for d in list_of_dicts:
        for k in d.keys():
            valuesets.setdefault(k, set())
            try:
                valuesets[k].add(d[k])
            except TypeError:
                # No valuesets for dicts etc.
                pass
                
    # "Object of type set is not JSON serializable". Sigh
    for k in valuesets.keys():
        valuesets[k] = list(valuesets[k])
    return valuesets
