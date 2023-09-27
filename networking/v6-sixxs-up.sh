#!/bin/bash

# Default IPv6 Interface.

ifconfig sit0 up
ifconfig sit0 mtu 1480

# SixXs Tunnel Uplink.

ip tunnel add mode sit remote <sixxs-ip> local 10.10.1.220 ttl 64
ifconfig sit1 up
ifconfig sit1 inet6 add 2001:<IPV6-IP>/128
ip route add 2000::/3 dev sit1
ifconfig sit1 mtu 1480

# Home Network Tunnel

ip tunnel add mode sit remote <home-ip> local 10.10.1.220 ttl 64
ifconfig sit2 up
ifconfig sit2 inet6 add 2001:<IPV6-IP>/128
ip route add 2001:<IPV6-IP>/64 dev sit2
ifconfig sit2 mtu 1480
