#!/usr/bin/env bash

echo
echo 'you have two options - uncomment the one you want'
echo

echo '=== Option 1 ==='
echo 'https://github.com/cli/cli/blob/trunk/docs/install_linux.md'
echo '  -> uncomment in file'
echo '=== Option 1 ==='
echo

#(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
#	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
#	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
#	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
#	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
#	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
#	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
#	&& sudo apt update \
#	&& sudo apt install gh -y
#
#sudo apt update
#sudo apt install gh

echo '=== Option 2 ==='
echo 'nix profile add nixpkgs#gh'
echo '=== Option 2 ==='
echo

# nix alternative
# nix profile add nixpkgs#gh

echo '=== Authenticate ==='
echo 'Run `gh auth login`'
echo '=== Authenticate ==='
echo
