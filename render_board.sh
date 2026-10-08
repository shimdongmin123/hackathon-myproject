#!/bin/bash

PLAYER="$1"
CUR_R="${2:--1}"
CUR_C="${3:--1}"
SEL_R="${4:--1}"
SEL_C="${5:--1}"

BOARD="/srv/chess_game/state/board.txt"
files="abcdefgh"
OUT=""

add_line() {
  OUT+="$1"$'\n'
}

piece_icon() {
  case "$1" in
    K) echo "♔" ;;
    Q) echo "♕" ;;
    R) echo "♖" ;;
    B) echo "♗" ;;
    N) echo "♘" ;;
    P) echo "♙" ;;
    k) echo "♚" ;;
    q) echo "♛" ;;
    r) echo "♜" ;;
    b) echo "♝" ;;
    n) echo "♞" ;;
    p) echo "♟" ;;
    .) echo " " ;;
    *) echo "$1" ;;
  esac
}

get_piece() {
  local row="$1"
  local col="$2"
  sed -n "$((row + 1))p" "$BOARD" | awk -v c="$((col + 1))" '{print $c}'
}

map_display_to_internal() {
  local dr="$1"
  local dc="$2"

  if [ "$PLAYER" = "player2" ]; then
    echo "$((7 - dr)) $((7 - dc))"
  else
    echo "$dr $dc"
  fi
}

file_labels() {
  if [ "$PLAYER" = "player2" ]; then
    echo "      h   g   f   e   d   c   b   a"
  else
    echo "      a   b   c   d   e   f   g   h"
  fi
}

if [ ! -f "$BOARD" ]; then
  echo "board.txt not found."
  exit 1
fi

add_line "$(file_labels)"
add_line "    +---+---+---+---+---+---+---+---+"

for dr in 0 1 2 3 4 5 6 7
do
  first_map=$(map_display_to_internal "$dr" 0)
  ir_for_rank=$(echo "$first_map" | awk '{print $1}')
  rank=$((8 - ir_for_rank))

  line=" $rank  |"

  for dc in 0 1 2 3 4 5 6 7
  do
    mapped=$(map_display_to_internal "$dr" "$dc")
    ir=$(echo "$mapped" | awk '{print $1}')
    ic=$(echo "$mapped" | awk '{print $2}')

    raw_piece=$(get_piece "$ir" "$ic")
    icon=$(piece_icon "$raw_piece")

    if [ "$ir" -eq "$SEL_R" ] && [ "$ic" -eq "$SEL_C" ]; then
      line+="\033[102;30m $icon \033[0m|"
    elif [ "$dr" -eq "$CUR_R" ] && [ "$dc" -eq "$CUR_C" ]; then
      line+="\033[43;30m $icon \033[0m|"
    else
      sum=$((ir + ic))

      if [ $((sum % 2)) -eq 0 ]; then
        line+="\033[47;30m $icon \033[0m|"
      else
        line+="\033[100;37m $icon \033[0m|"
      fi
    fi
  done

  line+="  $rank"
  add_line "$line"
  add_line "    +---+---+---+---+---+---+---+---+"
done

add_line "$(file_labels)"

printf "%b" "$OUT"
