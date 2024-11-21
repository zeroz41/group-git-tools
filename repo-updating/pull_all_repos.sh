#!/bin/bash
#tj

print_usage() {
    echo "Usage: $0 [-d|--dry-run] [-p|--path <directory_path>] <remote_name>"
    echo "Usage: $0 <remote_name> -----(for real run)"
    echo "Options:"
    echo " -d, --dry-run    Print commands without executing them"
    echo " -h, --help       Show this help message"
    echo " -p, --path       Specify directory path (default: current directory)"
    echo "                  Can use './' or '.' for current directory"
    echo "Arguments:"
    echo " <remote_name>    Name of the Git remote (e.g., origin)"
}

dry_run=false
remote_name=""
directory=""

# args
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -p|--path)
            directory="$2"
            shift 2
            ;;
        *)
            remote_name=$1
            shift
            ;;
    esac
done

# no remote?
if [ -z "$remote_name" ]; then
    echo "Error: No remote name provided"
    print_usage
    exit 1
fi

if [ -n "$directory" ]; then
    echo "Using provided directory: $directory"
    cd "$directory" || exit 1
else
    echo "Using current directory: $(pwd)"
fi

# dry run?
if ! $dry_run; then
    read -p "This will fetch and merge all repositories, but only Fast forward merge. Consider using -d for dry run first. Continue? [y/N] " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
fi

exec_or_print() {
    if $dry_run; then
        echo "[DRY RUN] Would execute: $1"
        return 0
    else
        echo "Executing: $1"
        if ! eval "$1"; then
            return 1
        fi
    fi
    return 0
}

check_remote() {
    local remote=$1
    if ! git remote -v | grep -q "^${remote}\s"; then
       
        echo -e "\e[31mError: Remote '$remote' does not exist in git remote configuration for $(pwd)\e[0m"
        return 1
       
    fi
    return 0
}

echo "Mode: $(if $dry_run; then echo "Dry Run"; else echo "Actual Run"; fi)"
echo "Remote: $remote_name"
echo "------------------------"

# find repos 1 deep
failed_repos=()
while read -r dir; do
    if [ -d "$dir/.git" ]; then
        echo -e "\e[1;34m\e[1mProcessing repository: $(pwd)${dir#.}\e[0m"
        cd "$dir" || continue
        
        # Check if remote exists first
        if ! check_remote "$remote_name"; then
            failed_repos+=("$dir (remote '$remote_name' not found)")
            cd - >/dev/null || exit 1
            echo "------------------------"
            continue
        fi

        # Get current branch
        branch=$(git rev-parse --abbrev-ref HEAD)
        echo "Current branch: $branch"

        
        # fetch
        fetch_command="git fetch $remote_name $branch"
        if ! exec_or_print "$fetch_command"; then
            echo -e "\e[31mFailed to fetch $dir. Continuing to next repository.\e[0m"
            failed_repos+=("$dir (fetch failed)")
            cd - >/dev/null || exit 1
            echo "------------------------"
            continue
        fi
        
        # merge
        ff_command="git merge --ff-only $remote_name/$branch"
        if ! exec_or_print "$ff_command"; then
            echo -e "\e[31mFailed to fast-forward merge $dir. A merge might be required. Continuing to next repository.\e[0m"
            failed_repos+=("$dir (merge failed)")
            cd - >/dev/null || exit 1
            echo "------------------------"
            continue
        fi
        
        echo -e "\e[32mSuccessfully updated $dir\e[0m"
        cd - >/dev/null || exit 1
        echo "------------------------"
    fi
done < <(find . -maxdepth 1 -type d ! -name ".")

echo -e "\e[1;34mAll repositories processed.\e[0m"
if [ ${#failed_repos[@]} -eq 0 ]; then
    echo -e "\e[32m\e[1m\033#3All repositories were successfully updated.\e[0m"
    echo ""
    echo ""
else
    echo -e "\e[31m\e[1m\033#3The following repositories failed:\e[0m"
    echo ""
    echo ""
    for repo in "${failed_repos[@]}"; do
        echo -e "\e[31m- $repo\e[0m"
    done
fi

if $dry_run; then
    echo -e "\e[1;34m-------------------------------------------------------\e[0m"
    echo -e "\e[1;34mThis was a dry run. No actual changes were made.\e[0m"
    echo -e "\e[1;34m-------------------------------------------------------\e[0m"
fi