"""IP / CIDR calculation helpers."""

import re

class FilterModule(object):
    def filters(self):
        return dict(subnets_24=subnets_24)

def subnets_24(ips):
    subnets = set()
    for ip in ips:
        matched = re.search(r"^(\d+\.\d+\.\d+)\.\d+$", ip)
        if matched:
            subnets.add(matched[1])
    return list(subnets)
