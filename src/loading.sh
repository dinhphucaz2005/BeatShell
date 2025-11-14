#!/bin/bash

BLUE='\033[38;2;122;162;247m'
DARK_BLUE='\033[38;2;65;88;208m'
CYAN='\033[38;2;115;218;255m'
PURPLE='\033[38;2;187;154;247m'
GREEN='\033[38;2;158;206;106m'
YELLOW='\033[38;2;224;175;104m'
RED='\033[38;2;247;118;142m'
NC='\033[0m'

TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)

unicode_length() {
    echo -n "$1" | sed 's/\\033\[[0-9;]*m//g' | wc -m
}

# In-ra ở giữa dòng (chuẩn xác cho Unicode)
center_print() {
    local text="$1"
    # Loại bỏ mã màu để tính chiều dài thực
    local clean_text=$(echo -n "$text" | sed 's/\\033\[[0-9;]*m//g')
    local len=$(echo -n "$clean_text" | wc -m)
    local padding=$(( (TERM_WIDTH - len) / 2 ))
    
    printf "%*s" $padding ""
    printf "%b\n" "$text"
}

display_title() {
    clear
    echo
    echo
    printf "${BLUE}"
    center_print "██████╗ ███████╗ █████╗ ████████╗"
    center_print "██╔══██╗██╔════╝██╔══██╗╚══██╔══╝"
    center_print "██████╔╝█████╗  ███████║   ██║   "
    center_print "██╔══██╗██╔══╝  ██╔══██║   ██║   "
    center_print "██████╔╝███████╗██║  ██║   ██║   "
    center_print "╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝   "
    printf "${CYAN}"
    center_print "███████╗██╗  ██╗███████╗██╗     ██╗     "
    center_print "██╔════╝██║  ██║██╔════╝██║     ██║     "
    center_print "███████╗███████║█████╗  ██║     ██║     "
    center_print "╚════██║██╔══██║██╔══╝  ██║     ██║     "
    center_print "███████║██║  ██║███████╗███████╗███████╗"
    center_print "╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝"
    printf "${NC}"
    echo
}

big_progress_bar() {
    local total=${1:-100}
    local current=0
    local bar_width=$((TERM_WIDTH - 2))

    while [ $current -le $total ]; do
        percentage=$((current * 100 / total))
        completed=$((current * bar_width / total))
        remaining=$((bar_width - completed))
        
        tput cup 20 0
        
        # Dòng 1 - viền trên
        printf "${DARK_BLUE}╭"
        printf "%0.s─" $(seq 1 $bar_width)
        printf "╮${NC}\n"
        
        # Dòng 2 - thanh tiến trình
        printf "${DARK_BLUE}│${BLUE}"
        
        if [ $completed -gt 0 ]; then
            printf "%0.s█" $(seq 1 $completed)
        fi
        
        printf "${CYAN}"
        if [ $remaining -gt 0 ]; then
            printf "%0.s░" $(seq 1 $remaining)
        fi
        
        printf "${DARK_BLUE}│${NC}\n"  # Không có phần trăm
        
        # Dòng 3 - viền dưới
        printf "${DARK_BLUE}╰"
        printf "%0.s─" $(seq 1 $bar_width)
        printf "╯${NC}\n"
        
        current=$((current + 1))
        sleep 0.001
    done
}

main() {
    if [ $TERM_HEIGHT -lt 20 ] || [ $TERM_WIDTH -lt 60 ]; then
        echo "Please enlarge your terminal window (min 60x20)"
        exit 1
    fi
    
    display_title
    big_progress_bar 100
}

main