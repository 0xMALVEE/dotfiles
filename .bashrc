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

export PATH=$PATH:/usr/local/go/bin