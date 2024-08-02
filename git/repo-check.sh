#!/bin/bash
#--------------------------------------------------------------------------
# Program     : repo-check
# Version     : v1.3
# Description : Batch run git tasks.
# Syntax      : repo-check.sh [-l|-p|-b|-s|-r|-d|-c|-h]
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

# set -x
set -eu -o pipefail

f_root=( github )
workdir="${HOME}/Development"
e_path_list=(\
    '*/opentofu/internal/*' \
    '*/opentofu/testing/*' \
)

# helper
function help()
{
    cat << EOF
Basic script to batch update some git things.

Usage: $0 [-l|-p|-b|-s|-r|-d|-c|-h]
Options:
  -l|--log      Get head of git log on repos.
  -p|--pull     Run git pull on repos.
  -b|--branch   Count all branches in repos.
  -s|--status   Get status on repos.
  -r|--restore  Remove unwanted changes.
  -d|--default  Checkout to default branch.
  -c|--clean    Cleanup trash.
  -h|--help     Display this help.

EOF
}

# cycle repos
function git_b()
{
    for f in "${f_root[@]}"
    do
        (cd "${f}" &&
        for r in $(ls -d ./*)
        do
            echo -e "\nProcessing repository: ${r}\n"
            if (( $# < 2 )); then
               p="$1"
               if [[ ${p} == "checkout" ]]; then
                   p="checkout $(cd "${r}" \
                       && git branch \
                       | head -n 1 \
                       | sed 's/\ //g; s/^\*//g')"
               fi
               (cd "${r}" && git ${p})
            else
               (cd "${r}" && git $1 |$2)
            fi
        done
        ) || exit
    done
}

# cleanup trash
function clean()
{
    echo "Cleaning up leftovers..."

    local e_path_args=()
    for p in "${e_path_list[@]}"; do
          e_path_args+=('!' '-path' "${p}")
    done

    find . -type d -name "__pycache__" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -rf {} \;

    find . -type d -name ".pytest_cache" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -rf {} \;

    find . -type d -name ".mypy_cache" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -rf {} \;

    find . -type d -name ".terragrunt-cache" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -rf {} \;

    find . -type d -name ".terraform" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -rf {} \;

    find . -type f -name ".terraform.lock.hcl" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -f {} \;

    find . -type f -name ".DS_Store" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -f {} \;

    find . -type f -name "Pipfile" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -f {} \;

    find . -type f -name "Pipfile.lock" \
        "${e_path_args[@]}" \
        -prune -exec echo {} \; -exec rm -f {} \;
}

# main caller
main()
{
    if (( $# < 1 )); then
        help
    else
        while [[ $# -ne 0 ]]
        do
            case $1 in
                 -l | --log )     shift;
                     git_b "log" "head -n3"
                     exit
                     ;;
                 -p | --pull )    shift;
                     git_b "pull"
                     exit
                     ;;
                 -b | --branch )  shift;
                     git_b "branch -a" "wc -l"
                     exit
                     ;;
                 -s | --status )  shift;
                     git_b "status" "head -n20"
                     exit
                     ;;
                 -r | --restore ) shift;
                     git_b "restore *"
                     exit
                     ;;
                 -d | --default ) shift;
                     git_b "checkout"
                     exit
                     ;;
                 -c | --clean )   shift;
                     clean
                     exit
                     ;;
                 -h | --help )
                     help
                     exit
                     ;;
                 * ) help
                     exit 1
            esac
        done
    fi
}

cd "${workdir}" || exit
main "$@"
