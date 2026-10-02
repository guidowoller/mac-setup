#!/bin/bash
ssh uni -t "tmux attach -t uni || tmux new -s uni"
#autossh -M 0 -t uni "tmux attach || tmux new"
