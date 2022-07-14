#!/bin/bash

# ff only
git config --global pull.ff only

# git diff-blame
wget https://raw.githubusercontent.com/dmnd/git-diff-blame/master/git-diff-blame
chmod +x git-diff-blame
sudo mv git-diff-blame /usr/local/bin

# golang
# installing Golang v1.18
(echo ""; echo "##### Golang v18x #####"; echo "";)
wget https://golang.org/dl/go1.18.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz
echo "" | sudo tee -a ~/.bashrc
echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee -a ~/.bashrc
echo "" | sudo tee -a ~/.zshrc
echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee -a ~/.zshrc
echo "" | sudo tee -a ~/.bashrc
echo "export PATH=\$PATH:\$HOME/go/bin" | sudo tee -a ~/.bashrc
echo "" | sudo tee -a ~/.zshrc
echo "export PATH=\$PATH:\$HOME/go/bin" | sudo tee -a ~/.zshrc
rm go1.18.linux-amd64.tar.gz
