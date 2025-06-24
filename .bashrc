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

setup-ssh() {
  KEY="$HOME/.ssh/id_ed25519"

  if [ -f "$KEY" ]; then
    echo "SSH key already exists at $KEY"
  else
    echo "Generating new SSH ed25519 key..."
    ssh-keygen -t ed25519 -C "m.alvee8141@gmail.com" -f "$KEY" -N ""
  fi

  echo "Starting ssh-agent and adding key..."
  eval "$(ssh-agent -s)"
  ssh-add "$KEY"

  echo "Your public key is:"
  cat "${KEY}.pub"
}


setup-go() {
  if command -v go >/dev/null 2>&1; then
    echo "Go is already installed."
  else
    echo "Installing Go 1.24.1..."
    wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
    rm go1.24.1.linux-amd64.tar.gz

    export PATH=$PATH:/usr/local/go/bin
  fi

  echo "Installing Go tools..."

  # Ensure GOPATH and PATH set (optional)
  export PATH=$PATH:$(go env GOPATH)/bin

  go install github.com/nametake/golangci-lint-langserver@latest
  go install golang.org/x/tools/gopls@latest
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  go install golang.org/x/tools/cmd/goimports@latest
  go install github.com/go-delve/delve/cmd/dlv@latest

  echo "Go setup complete."
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
            "compilerPath": "/usr/bin/gcc"
        }
    ],
    "version": 4
}
EOF

    echo "Updated $json_file with forced includes."
}

# Shortcut function for Tetragon headers
c-tetra() {
    cinclude ./bpf/include ./bpf/lib ./bpf/libbpf ./bpf/tetragon
}

c-cilium(){
    cinclude ./bpf/include ./bpf/lib
}

setup-path() {
  grep -Fxq 'export PATH=$PATH:/usr/local/go/bin' /etc/profile || echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile
  grep -Fxq 'export PATH=$PATH:$HOME/go/bin' /etc/profile || echo 'export PATH=$PATH:$HOME/go/bin' | sudo tee -a /etc/profile
}

setup-curl () {
  if command -v curl >/dev/null 2>&1; then
    echo "curl is already installed."
    return
  fi

  echo "curl not found. Attempting to install..."

  if command -v apt >/dev/null 2>&1; then
    echo "Detected Debian-based system. Installing with apt..."
    sudo apt update && sudo apt install -y curl
  elif command -v dnf >/dev/null 2>&1; then
    echo "Detected Fedora-based system. Installing with dnf..."
    sudo dnf install -y curl
  else
    echo "Could not detect a supported package manager (apt or dnf)."
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    echo "curl installed successfully."
  else
    echo "curl installation failed."
    return 1
  fi
}

setup-git() {
  if command -v git >/dev/null 2>&1; then
    echo "git is already installed."
    return
  fi

  echo "git not found. Attempting to install..."

  if command -v apt >/dev/null 2>&1; then
    echo "Detected Debian-based system. Installing with apt..."
    sudo apt update && sudo apt install -y git
  elif command -v dnf >/dev/null 2>&1; then
    echo "Detected Fedora-based system. Installing with dnf..."
    sudo dnf install -y git
  else
    echo "Could not detect a supported package manager (apt or dnf)."
    return 1
  fi

  if command -v git >/dev/null 2>&1; then
    echo "git installed successfully."
  else
    echo "git installation failed."
    return 1
  fi
}

setup-zed-config(){
  ZED_CONFIG_DIR="$HOME/.config/zed"

  echo "Replacing Zed config files from GitHub..."

  curl -fsSL https://raw.githubusercontent.com/0xMALVEE/dotfiles/refs/heads/main/.config/zed/keymap.json -o "$ZED_CONFIG_DIR/keymap.json"
  curl -fsSL https://raw.githubusercontent.com/0xMALVEE/dotfiles/refs/heads/main/.config/zed/settings.json -o "$ZED_CONFIG_DIR/settings.json"

  echo "Zed configuration updated successfully."
}

setup-zed() {
  if command -v zed >/dev/null 2>&1; then
    echo "zed is already installed."
  else
    echo "Installing zed..."
    curl -fsSL https://zed.dev/install.sh | sh
  fi

  setup-zed-config
}

dev-tools() {
  if [ -f /etc/fedora-release ]; then
    echo "Fedora detected. Installing development tools..."
    sudo dnf install @development-tools
  else
    echo "Not a Fedora system. Skipping development tools installation."
  fi
}

setup-flatpak() {
  if command -v flatpak >/dev/null 2>&1; then
    echo "flatpak is already installed."
  else
    if [ -f /etc/fedora-release ]; then
      echo "Detected Fedora. Installing flatpak..."
      sudo dnf install -y flatpak
    elif [ -f /etc/debian_version ]; then
      echo "Detected Debian-based system. Installing flatpak..."
      sudo apt update && sudo apt install -y flatpak

      # Detect desktop environment
      DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

      if [[ "$DE" == *gnome* ]]; then
        echo "Detected GNOME. Installing GNOME Flatpak plugin..."
        sudo apt install -y gnome-software-plugin-flatpak
      elif [[ "$DE" == *kde* || "$DE" == *plasma* ]]; then
        echo "Detected KDE/Plasma. Installing KDE Flatpak plugin..."
        sudo apt install -y plasma-discover-backend-flatpak
      else
        echo "Unknown DE or DE not detected. Skipping plugin installation."
      fi
    else
      echo "Unsupported distribution. Only Fedora and Debian are supported."
      return 1
    fi
  fi

  # Add Flathub repo
  echo "Adding Flathub repository..."
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  echo "Flatpak setup complete."
}


setup-flatpack-apps(){
  flatpak install flathub io.github.shiftey.Desktop
  flatpak install flathub com.slack.Slack
  flatpak install flathub com.discordapp.Discord
}

setup-kind() {
  if command -v kind >/dev/null 2>&1; then
    echo "kind is already installed."
  else
    echo "Installing kind..."
    go install sigs.k8s.io/kind@v0.29.0
  fi
}

setup-kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is already installed."
  else
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
  fi

  kubectl version --client
}


setup-docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed."
    return
  fi

  if [ -f /etc/fedora-release ]; then
    echo "Detected Fedora. Installing Docker..."
    sudo dnf -y install dnf-plugins-core
    sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker

  elif [ -f /etc/debian_version ]; then
    echo "Detected Debian-based system. Installing Docker..."

    # Prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    # Keyring setup
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker's official repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker packages
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  else
    echo "Unsupported OS. Only Fedora and Debian are supported."
    return 1
  fi

  if command -v docker >/dev/null 2>&1; then
    echo "Docker installed successfully."
  else
    echo "Docker installation failed."
    return 1
  fi

  sudo usermod -aG docker $USER
}

setup-node-pnpm(){
  # Download and install nvm:
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  # in lieu of restarting the shell
  \. "$HOME/.nvm/nvm.sh"

  # Download and install Node.js:
  nvm install 22

  # Verify the Node.js version:
  node -v # Should print "v22.16.0".
  nvm current # Should print "v22.16.0".

  # Download and install pnpm:
  corepack enable pnpm

  # Verify pnpm version:
  pnpm -v
}

setup-repos(){
  gclone git@github.com:0xMALVEE/aistor-console.git
  gclone git@github.com:0xMALVEE/eos.git
  gclone git@github.com:0xMALVEE/ec.git
  gclone git@github.com:0xMALVEE/mc.git
  gclone git@github.com:0xMALVEE/minio.git
  gclone git@github.com:0xMALVEE/madmin-go.git
  gclone git@github.com:0xMALVEE/object-browser.git

  cd ~/code/aistor-console
  gupstream git@github.com:miniohq/aistor-console.git
  gsync

  cd ~/code/eos
  gupstream git@github.com:miniohq/eos.git
  gsync

  cd ~/code/ec
  gupstream git@github.com:0xMALVEE/ec.git
  gsync

  cd ~/code/mc
  gupstream git@github.com:minio/mc.git
  gsync

  cd ~/code/minio
  gupstream git@github.com:minio/minio.git
  gsync

  cd ~/code/madmin-go
  gupstream git@github.com:minio/madmin-go.git
  gsync

  cd ~/code/object-browser
  gupstream git@github.com:minio/object-browser.git
  gsync
}

setup-linux () {
  setup-curl
  setup-git
  setup-flatpak

  setup-zed
  setup-go
  setup-path

  setup-docker
  setup-kind
  setup-kubectl

  setup-flatpack-apps
  setup-node-pnpm

  dev-tools
  setup-ssh
}
