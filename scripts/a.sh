#!/bin/bash
ssh example.org -t "tmux attach -t uni || tmux new -s uni"

