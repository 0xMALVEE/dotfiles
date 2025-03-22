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