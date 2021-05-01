"""IP / CIDR calculation helpers."""

import re
import hashlib

class FilterModule(object):
    def filters(self):
        return dict(
            subnets_24=subnets_24,
            subnets_16=subnets_16,
            ipv6_ula=ipv6_ula)

def subnets_24(ips):
    subnets = set()
    for ip in ips:
        matched = re.search(r"^(\d+\.\d+\.\d+)\.\d+$", ip)
        if matched:
            subnets.add(matched[1])
    return list(subnets)

def subnets_16(ips):
    subnets = set()
    for ip in ips:
        matched = re.search(r"^(\d+\.\d+)\.\d+\.\d+$", ip)
        if matched:
            subnets.add(matched[1])
    return list(subnets)

def ipv6_ula(seed):
    """Returns an RFC4193-compliant /48 subnet that is unique w.r.t. `seed`."""
    hasher = hashlib.sha256()
    hasher.update("EPFL".encode("utf-8"))
    hasher.update(seed.encode("utf-8"))
    seed_hex = hasher.hexdigest()
    prefix = re.sub("(....)", "\\1:", "fc%s" % seed_hex)[2:14]
    return "fc%s::/48" % prefix
