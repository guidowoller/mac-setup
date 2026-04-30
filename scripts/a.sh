#!/bin/bash
ssh example.org -t "tmux attach -t uni || tmux new -s uni"
#autossh -M 0 -t guido@example.org "tmux attach || tmux new"
