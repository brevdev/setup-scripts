#!/bin/bash

##### Python + Pip + Poetry #####
sudo apt-get install -y build-essential
sudo apt install python-is-python3
sudo apt-get install -y python3-distutils
sudo apt-get install -y python3-apt
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 -
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
rm get-pip.py

export PATH=/home/brev/.local/bin:$PATH 
# below 4 lines are to get above line behavior

echo "" >> ~/.zshrc
echo "export PATH=/home/brev/.local/bin:$PATH" >> ~/.zshrc
echo "" >> ~/.bashrc
echo "export PATH=/home/brev/.local/bin:$PATH" >> ~/.bashrc
source ~/.zshrc
source ~/.bashrc

source $HOME/.poetry/env

##### mkdocs #####
pip install mkdocs
pip install mkdocs-material