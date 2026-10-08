#!/bin/bash

PLAYER="${1:-$(whoami)}"

/srv/chess_game/frontend/render_board.sh "$PLAYER" -1 -1 -1 -1
