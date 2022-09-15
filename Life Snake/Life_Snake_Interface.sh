#!/bin/bash
psql -U postgres -d jogo_cobra -qt -A -F ' ' -c "CALL cria_campo(10);"

psql -U postgres -d jogo_cobra -qt -A -F ' ' -c " SELECT * FROM campo ORDER BY row_numb;;"

while true
do 

mode=""
move="O"

read -t 0.3 -rsn1 mode

case "$mode" in
    "W") move="U";;
    "S") move="D";;
    "A") move="L";; 
    "D") move="R";;
esac

tput cup 0 0

psql -U postgres -d jogo_cobra -qt -A -F ' ' -c "SELECT * FROM mv_snake('${move}',NULL::campo)"

done