#!/bin/bash

IP=/sbin/ip
PING=/bin/ping

### LINK SECTION

# EXTIFn - Interface name
# EXTIPn - Egress IP
# EXTMn  - Netmask
# EXTGWn - Egress Gateway

# Link 1

EXTIF2=eth0
EXTIP2=192.168.1.1
EXTM2=24
EXTGW2=192.168.1.254

# Link 2

EXTIF1=eth1
EXTIP1=10.10.1.1
EXTM1=24
EXTGW1=10.10.1.254

### ROUTING SECTION

# Removing old rules and routes

echo "Removing old rules"
${IP} rule del prio 50 table main
${IP} rule del prio 201 from ${EXTIP1}/${EXTM1} table 201
${IP} rule del prio 202 from ${EXTIP2}/${EXTM2} table 202
${IP} rule del prio 221 table 221

echo "Flushing tables"
${IP} route flush table 201
${IP} route flush table 202
${IP} route flush table 221

echo "Removing tables"
${IP} route del table 201
${IP} route del table 202
${IP} route del table 221

# Setting new rules

echo "Setting new routing rules"

# Main table

${IP} rule add prio 50 table main
${IP} route del default table main

# Identified routes

${IP} rule add prio 201 from ${EXTIP1}/${EXTM1} table 201
${IP} rule add prio 202 from ${EXTIP2}/${EXTM2} table 202

${IP} route add default via ${EXTGW1} dev ${EXTIF1} src ${EXTIP1} proto static table 201
${IP} route append prohibit default table 201 metric 1 proto static

${IP} route add default via ${EXTGW2} dev ${EXTIF2} src ${EXTIP2} proto static table 202
${IP} route append prohibit default table 202 metric 1 proto static

# Multipath

${IP} rule add prio 221 table 221

${IP} route add default table 221 proto static \
            nexthop via ${EXTGW1} dev ${EXTIF1} weight 10\
            nexthop via ${EXTGW2} dev ${EXTIF2} weight 1

${IP} route flush cache
