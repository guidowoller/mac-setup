#!/bin/bash
ssh cervicales.fim.uni-passau.de -t "tmux attach -t uni || tmux new -s uni"
#autossh -M 0 -t guido@cervicales.fim.uni-passau.de "tmux attach || tmux new"
