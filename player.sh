#!/bin/bash

PLAYER=$(whoami)
STATE="/srv/chess_game/state"
DRAW="/srv/chess_game/frontend/draw_board.sh"
SELECT="/srv/chess_game/frontend/select_move.sh"

if [ "$PLAYER" != "player1" ] && [ "$PLAYER" != "player2" ]; then
  echo "Please login as player1 or player2."
  exit 1
fi

touch "$STATE/$PLAYER.online"

cleanup() {
  rm -f "$STATE/$PLAYER.online"
  rm -f "$STATE/$PLAYER.ready"
  exit 0
}

trap cleanup INT TERM EXIT

file_flag() {
  if [ -f "$1" ]; then
    echo "1"
  else
    echo "0"
  fi
}

file_sig() {
  if [ -f "$1" ]; then
    cksum "$1" | awk '{print $1 ":" $2}'
  else
    echo "none"
  fi
}

recent_moves() {
  if [ -f "$STATE/log.txt" ]; then
    grep " moved " "$STATE/log.txt" 2>/dev/null | tail -n 5
  fi
}

log_sig() {
  recent_moves | cksum | awk '{print $1 ":" $2}'
}

state_signature() {
  local status
  local turn
  local p1_online
  local p2_online
  local p1_ready
  local p2_ready
  local started
  local board
  local log
  local err

  status=$(cat "$STATE/status.txt" 2>/dev/null)
  turn=$(cat "$STATE/turn.txt" 2>/dev/null)

  p1_online=$(file_flag "$STATE/player1.online")
  p2_online=$(file_flag "$STATE/player2.online")
  p1_ready=$(file_flag "$STATE/player1.ready")
  p2_ready=$(file_flag "$STATE/player2.ready")
  started=$(file_flag "$STATE/game_started")

  board=$(file_sig "$STATE/board.txt")
  log=$(log_sig)
  err=$(file_sig "$STATE/error_$PLAYER.txt")

  echo "$status|$turn|$p1_online|$p2_online|$p1_ready|$p2_ready|$started|$board|$log|$err"
}

draw_lobby_screen() {
  printf "\033[2J\033[H"

  status=$(cat "$STATE/status.txt" 2>/dev/null)
  turn=$(cat "$STATE/turn.txt" 2>/dev/null)

  echo "========================================"
  echo "          Terminal Chess"
  echo "========================================"
  echo "Player: $PLAYER"
  echo "Status: $status"
  echo "Turn  : $turn"
  echo "Mode  : Lobby"
  echo "----------------------------------------"

  if [ -f "$STATE/player1.online" ]; then
    echo "Player1: JOINED"
  else
    echo "Player1: WAITING"
  fi

  if [ -f "$STATE/player2.online" ]; then
    echo "Player2: JOINED"
  else
    echo "Player2: WAITING"
  fi

  echo ""

  if [ -f "$STATE/player1.ready" ]; then
    echo "Player1 Ready: YES"
  else
    echo "Player1 Ready: NO"
  fi

  if [ -f "$STATE/player2.ready" ]; then
    echo "Player2 Ready: YES"
  else
    echo "Player2 Ready: NO"
  fi

  echo "----------------------------------------"

  if [ ! -f "$STATE/player1.online" ] || [ ! -f "$STATE/player2.online" ]; then
    echo "Message:"
    echo "Waiting for another player."
    echo "Press q to leave."
    return
  fi

  if [ ! -f "$STATE/$PLAYER.ready" ]; then
    echo "Message:"
    echo "Both players joined. Press y to ready."
    echo "Press q to leave."
    return
  fi

  if [ ! -f "$STATE/game_started" ]; then
    echo "Message:"
    echo "You are ready. Waiting for game start."
    echo "If the game does not start, check backend/server.sh."
    echo "Press q to leave."
    return
  fi
}

draw_game_screen() {
  printf "\033[2J\033[H"

  status=$(cat "$STATE/status.txt" 2>/dev/null)
  turn=$(cat "$STATE/turn.txt" 2>/dev/null)

  echo "========================================"
  echo "          Terminal Chess"
  echo "========================================"
  echo "Player: $PLAYER"
  echo "Status: $status"
  echo "Turn  : $turn"
  echo "Mode  : Game"
  echo "----------------------------------------"
  echo "w/a/s/d : move cursor on your turn"
  echo "Space or Enter : select on your turn"
  echo "q : leave"
  echo "----------------------------------------"

  "$DRAW" "$PLAYER"

  echo "----------------------------------------"
  echo "Recent moves:"
  echo "----------------------------------------"

  moves=$(recent_moves)

  if [ -n "$moves" ]; then
    echo "$moves"
  else
    echo "No moves yet."
  fi

  echo "----------------------------------------"
  echo "Message:"

  errfile="$STATE/error_$PLAYER.txt"

  if [ -s "$errfile" ]; then
    cat "$errfile"
  else
    if [ "$turn" = "$PLAYER" ]; then
      echo "Your turn. Choose and move your piece."
    else
      echo "Opponent's turn. Waiting for move."
    fi
  fi

  echo "----------------------------------------"

  if [ "$turn" = "$PLAYER" ]; then
    echo "You can move now."
  else
    echo "Screen will update when the opponent moves."
  fi
}

draw_screen() {
  if [ -f "$STATE/game_started" ]; then
    draw_game_screen
  else
    draw_lobby_screen
  fi
}

last_signature=""
force_draw=1

while true
do
  current_signature=$(state_signature)

  if [ "$force_draw" = "1" ] || [ "$current_signature" != "$last_signature" ]; then
    draw_screen
    last_signature="$current_signature"
    force_draw=0
  fi

  status=$(cat "$STATE/status.txt" 2>/dev/null)
  turn=$(cat "$STATE/turn.txt" 2>/dev/null)

  # 한 명이라도 아직 접속하지 않은 경우
  if [ ! -f "$STATE/player1.online" ] || [ ! -f "$STATE/player2.online" ]; then
    read -rsn1 -t 1 input

    if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
      cleanup
    fi

    continue
  fi

  # 둘 다 접속했지만 내가 Ready하지 않은 경우
  if [ ! -f "$STATE/$PLAYER.ready" ]; then
    read -rsn1 -t 1 answer

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
      touch "$STATE/$PLAYER.ready"
      force_draw=1
    elif [ "$answer" = "q" ] || [ "$answer" = "Q" ]; then
      cleanup
    fi

    continue
  fi

  # Ready했지만 아직 서버가 game_started를 만들지 않은 경우
  if [ ! -f "$STATE/game_started" ]; then
    read -rsn1 -t 1 input

    if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
      cleanup
    fi

    continue
  fi

  # 게임 시작 후, 내 턴인데 이미 명령을 제출한 상태면 서버 처리 대기
  if [ "$turn" = "$PLAYER" ] && [ -s "$STATE/$PLAYER.cmd" ]; then
    read -rsn1 -t 1 input

    if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
      cleanup
    fi

    continue
  fi

  # 게임 시작 후, 내 턴이면 선택 모드 실행
  if [ "$turn" = "$PLAYER" ]; then
    move=$("$SELECT" "$PLAYER")
    result=$?

    if [ $result -ne 0 ] || [ "$move" = "CANCEL" ]; then
      echo "Move canceled." > "$STATE/error_$PLAYER.txt"
      force_draw=1
    else
      if [[ "$move" =~ ^[a-h][1-8][[:space:]][a-h][1-8]$ ]]; then
        echo "$move" > "$STATE/$PLAYER.cmd"
        force_draw=1
      else
        echo "ERR input format must be like e2 e4" > "$STATE/error_$PLAYER.txt"
        force_draw=1
      fi
    fi

    continue
  fi

  # 상대 턴이면 화면은 유지하고, 상태 변경만 조용히 감지
  read -rsn1 -t 1 input

  if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
    cleanup
  fi
done
