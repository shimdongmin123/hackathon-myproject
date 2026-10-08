#!/bin/bash

PLAYER="${1:-$(whoami)}"
STATE="/srv/chess_game/state"
BOARD="$STATE/board.txt"
RENDER="/srv/chess_game/frontend/render_board.sh"
TTY="/dev/tty"

files="abcdefgh"

if [ "$PLAYER" = "player2" ]; then
  cur_r=6
  cur_c=3
else
  cur_r=6
  cur_c=4
fi

sel_ir=-1
sel_ic=-1
selected_from=""
local_message="Your turn. Choose your own piece."

map_display_to_internal() {
  local dr="$1"
  local dc="$2"

  if [ "$PLAYER" = "player2" ]; then
    echo "$((7 - dr)) $((7 - dc))"
  else
    echo "$dr $dc"
  fi
}

coord_from_internal() {
  local ir="$1"
  local ic="$2"

  local file="${files:$ic:1}"
  local rank=$((8 - ir))

  echo "${file}${rank}"
}

get_piece() {
  local ir="$1"
  local ic="$2"
  sed -n "$((ir + 1))p" "$BOARD" | awk -v c="$((ic + 1))" '{print $c}'
}

is_my_piece() {
  local piece="$1"

  if [ "$PLAYER" = "player1" ]; then
    [[ "$piece" =~ ^[A-Z]$ ]]
    return $?
  else
    [[ "$piece" =~ ^[a-z]$ ]]
    return $?
  fi
}

recent_moves() {
  if [ -f "$STATE/log.txt" ]; then
    grep " moved " "$STATE/log.txt" 2>/dev/null | tail -n 5
  fi
}

read_server_message() {
  local errfile="$STATE/error_$PLAYER.txt"

  if [ -s "$errfile" ]; then
    cat "$errfile"
  else
    echo "$local_message"
  fi
}

draw_screen() {
  mapped=$(map_display_to_internal "$cur_r" "$cur_c")
  ir=$(echo "$mapped" | awk '{print $1}')
  ic=$(echo "$mapped" | awk '{print $2}')
  current_coord=$(coord_from_internal "$ir" "$ic")

  status=$(cat "$STATE/status.txt" 2>/dev/null)
  turn=$(cat "$STATE/turn.txt" 2>/dev/null)

  board_text=$("$RENDER" "$PLAYER" "$cur_r" "$cur_c" "$sel_ir" "$sel_ic")
  message_text=$(read_server_message)
  moves=$(recent_moves)

  screen=""
  screen+="\033[2J\033[H"
  screen+="========================================"$'\n'
  screen+="          Terminal Chess"$'\n'
  screen+="========================================"$'\n'
  screen+="Player: $PLAYER"$'\n'
  screen+="Status: $status"$'\n'
  screen+="Turn  : $turn"$'\n'
  screen+="Mode  : Move Selection"$'\n'
  screen+="----------------------------------------"$'\n'
  screen+="w/a/s/d : move cursor"$'\n'
  screen+="Space or Enter : select"$'\n'
  screen+="q : cancel"$'\n'
  screen+="----------------------------------------"$'\n'

  if [ -n "$selected_from" ]; then
    screen+="Selected piece: $selected_from"$'\n'
  else
    screen+="Selected piece: none"$'\n'
  fi

  screen+="Current cursor: $current_coord"$'\n'
  screen+="----------------------------------------"$'\n'
  screen+="$board_text"$'\n'
  screen+="----------------------------------------"$'\n'
  screen+="Recent moves:"$'\n'
  screen+="----------------------------------------"$'\n'

  if [ -n "$moves" ]; then
    screen+="$moves"$'\n'
  else
    screen+="No moves yet."$'\n'
  fi

  screen+="----------------------------------------"$'\n'
  screen+="Message:"$'\n'
  screen+="$message_text"$'\n'
  screen+="----------------------------------------"$'\n'

  if [ -z "$selected_from" ]; then
    screen+="Yellow cursor: choose your own piece."$'\n'
  else
    screen+="Green piece: selected. Choose target square."$'\n'
  fi

  printf "%b" "$screen" > "$TTY"
}

if [ ! -f "$BOARD" ]; then
  echo "CANCEL"
  exit 1
fi

while true
do
  draw_screen

  IFS= read -rsn1 key < "$TTY"

  case "$key" in
    w|W)
      if [ "$cur_r" -gt 0 ]; then
        cur_r=$((cur_r - 1))
      fi
      ;;
    s|S)
      if [ "$cur_r" -lt 7 ]; then
        cur_r=$((cur_r + 1))
      fi
      ;;
    a|A)
      if [ "$cur_c" -gt 0 ]; then
        cur_c=$((cur_c - 1))
      fi
      ;;
    d|D)
      if [ "$cur_c" -lt 7 ]; then
        cur_c=$((cur_c + 1))
      fi
      ;;
    q|Q)
      echo "CANCEL"
      exit 1
      ;;
    ""|" ")
      mapped=$(map_display_to_internal "$cur_r" "$cur_c")
      ir=$(echo "$mapped" | awk '{print $1}')
      ic=$(echo "$mapped" | awk '{print $2}')
      piece=$(get_piece "$ir" "$ic")
      current_coord=$(coord_from_internal "$ir" "$ic")

      # 아직 내 말을 선택하지 않은 상태
      if [ -z "$selected_from" ]; then
        if is_my_piece "$piece"; then
          selected_from="$current_coord"
          sel_ir="$ir"
          sel_ic="$ic"
          local_message="Piece selected. Choose target square."
          > "$STATE/error_$PLAYER.txt"
        else
          local_message="Choose your own piece."
        fi

      # 이미 내 말을 선택한 상태
      else
        # 내 다른 말을 누르면 선택 변경
        if is_my_piece "$piece"; then
          selected_from="$current_coord"
          sel_ir="$ir"
          sel_ic="$ic"
          local_message="Piece changed. Choose target square."
          > "$STATE/error_$PLAYER.txt"
        else
          selected_to="$current_coord"
          echo "$selected_from $selected_to"
          exit 0
        fi
      fi
      ;;
  esac
done
