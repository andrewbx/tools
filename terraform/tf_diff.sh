#!/usr/bin/env bash
#--------------------------------------------------------------------------
# Program     : tf_diff
# Version     : v1.0
# Description : Compare differences between two terraform files.
# Syntax      : tf_diff.sh <tf_file_1> <tf_file_2>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

# set -x

function tf_trim()
{
    sed -n '/Terraform used the selected providers to generate the following execution/,$p' < "${1}"
}

function tf_diff()
{
    if [[ -f "${1}" && -f "${2}" ]]; then
        echo -e "\n${1}\n" | sed 's/-output.txt//g'

        tf_trim "${1}" > "${1}.tmp"
        tf_trim "${2}" > "${2}.tmp"

        if [[ ! -s "${1}.tmp" && ! -s "${2}.tmp" ]]; then
            echo -e "No Changes"
        else
            diff --color -u "${1}.tmp" "${2}.tmp"
            grep -Rm 1 "Plan" "${1}.tmp"
            grep -Rm 1 "Plan" "${2}.tmp"
        fi
        rm "${1}.tmp"
        rm "${2}.tmp"
    else
        echo "Error: files not found"
    fi
}

function main()
{
    if [[ -z "${1}" || -z "${2}" ]]; then
        echo "Error: files not specified"
        exit
    else
        tf_diff "${1}" "${2}"
    fi
}

main "$@"
