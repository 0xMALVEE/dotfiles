# Add this function to your ~/.bashrc

gsync() {
  if ! git remote | grep -q "^upstream$"; then
    echo "Upstream remote not found."
    return 1
  fi

  local default_branch=$(git symbolic-ref HEAD 2>/dev/null | sed -e 's/^refs\/heads\///')

  if [ -z "$default_branch" ]; then
    default_branch="main"
  fi

  git checkout "$default_branch" && git fetch upstream && git rebase "upstream/$default_branch" && git push
}

gclone() {
  if [ -z "$1" ]; then
    echo "Usage: git_clone_code <git_repo_url>"
    return 1
  fi

  mkdir -p ~/code
  cd ~/code
  git clone "$1"
}

gupstream() {
  if [ -z "$1" ]; then
    echo "Usage: g-upstream <main_repo_url>"
    return 1
  fi

  git remote add upstream "$1"
}

gamend(){
    git commit --amend --no-edit -a && git push -f
}

grepo() {
  local remote_info=$(git remote get-url origin 2>/dev/null)
  if [[ -n "$remote_info" ]]; then
    local repo_url="$remote_info"
    if [[ "$repo_url" =~ ^git@github\.com:([^/]+)/([^.]+)\.git$ ]]; then
      repo_url="https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$repo_url" =~ ^https?://github\.com/([^/]+)/([^.]+)\.git$ ]]; then
      repo_url="${repo_url%.git}"
    fi
    echo "Opening repository URL in browser: $repo_url"
    xdg-open "$repo_url"
  else
    echo "Error: Could not extract the 'origin' repository URL."
    return 1
  fi
}

setup-ssh(){
  ssh-keygen -t ed25519 -C "m.alvee8141@gmail.com"
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub
}

setup-go() {
	wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
	sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
	rm go1.24.1.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
	go install github.com/nametake/golangci-lint-langserver@latest
	go install golang.org/x/tools/gopls@latest
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  go install golang.org/x/tools/cmd/goimports@latest
  go install github.com/go-delve/delve/cmd/dlv@latest
}

cinclude() {
    local workspaceFolder="\${workspaceFolder}"  # Keep as a literal string
    local json_file=".vscode/c_cpp_properties.json"

    # Ensure the .vscode directory exists
    mkdir -p "$(dirname "$json_file")"

    # Collect all header files
    local includes=()
    for dir in "$@"; do
        while IFS= read -r -d '' file; do
            # Get the relative path correctly, ensuring it starts with "/bpf"
            local rel_path="${file#$(pwd)}"
            rel_path="${rel_path#./}"  # Remove leading "./" if present
            includes+=("\"${workspaceFolder}/${rel_path#"/"}\"")  # Ensure "/" is always present
        done < <(find "$dir" -type f -name "*.h" -print0)
    done

    # Format JSON properly
    cat > "$json_file" <<EOF
{
    "configurations": [
        {
            "name": "Linux",
            "includePath": ["\${workspaceFolder}/**"],
            "forcedInclude": [
                $(printf "%s,\n                " "${includes[@]}" | sed '$s/,$//')
            ],
            "intelliSenseMode": "clang-x64",
            "compilerPath": "/usr/bin/clang"
        }
    ],
    "version": 4
}
EOF

    echo "Updated $json_file with forced includes."
}

# Shortcut function for Tetragon headers
c-tetra() {
    cinclude ./bpf/include ./bpf/lib ./bpf/libbpf
}

export PATH=$PATH:/usr/local/go/bin