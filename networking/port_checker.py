#!/usr/bin/python
# -*- coding: utf-8 -*-

# Simple Port checker.

from optparse import OptionParser, OptionGroup, OptionValueError
from socket import *

version="1.0"
timeout=5

def conn(targetHost, targetPort):
    try:
        conn = socket(AF_INET, SOCK_STREAM)
        conn.connect((targetHost, targetPort))
        print ('[+] ' + str(targetPort) + ' Success'),

    except (Exception, e):
        print ('[-] ' + str(targetPort) + ' Failed: ' + str(e)),

    finally:
        conn.close()

def main():
    parser = OptionParser(usage='\n  %prog\t-t <target host(s)> -p <target port(s)>', version='%prog ' + version)

    parser.add_option(
	'-t',
	dest='targetHosts',
	type='string',
	help='Specify the target host(s); Separate them by commas',
	metavar='targethosts',
	)

    parser.add_option(
	'-p',
	dest='targetPorts',
	type='string',
	help='Specify the target port(s); Separate them by commas',
	metavar='targetports'
	)

    (options, args) = parser.parse_args()

    if (options.targetHosts is None) | (options.targetPorts is None):
        parser.print_usage()
        parser.exit(1)

    targetHosts = str(options.targetHosts).split(',')
    targetPorts = str(options.targetPorts).split(',')

    setdefaulttimeout(timeout)

    for targetHost in targetHosts:
        print ('\nHost: ' + targetHost + '\n')
        for targetPort in targetPorts:
            conn(targetHost, int(targetPort))

if __name__ == '__main__':
    main()
