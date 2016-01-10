#!/bin/bash

reset="\e[0m"

red="\e[0;31m"
green="\e[0;32m"
yellow="\e[0;33m"
blue="\e[0;34m"
pink="\e[0;35m"
cyan="\e[0;36m"

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
PINK="\e[1;35m"
CYAN="\e[1;36m"

red_back="\e[0;41m"
green_back="\e[0;42m"
yellow_back="\e[0;43m"
blue_back="\e[0;44m"
pink_back="\e[0;45m"
cyan_back="\e[0;46m"

RET=""

MODE="none"
ARRAY=()
RRAY_TITLE=()
ARRAY_CONTENT=()

_topics() {
    if [ "$1" = "topics" ]; then
        tmpfile="/tmp/ddc.v2ex.topics.$2.json"
        curl -s -o $tmpfile "https://www.v2ex.com/api/topics/$2.json"
    elif [ "$1" = "node" ]; then
        tmpfile="/tmp/ddc.v2ex.node.$2.json"
        curl -s -o $tmpfile "https://www.v2ex.com/api/topics/show.json?node_name=$2"
    else
        return
    fi
    if [ `cat $tmpfile | jq -r ". | type"` != "array" ]; then
        printf "${red}节点名不存在，另外节点名称不支持中文，如酷工作请使用jobs${reset}\n"
        return
    fi
    LENGTH=`cat $tmpfile | jq ". | length"`
    if ! test $LENGTH; then
        return
    fi
    ARRAY=()
    ARRAY_TITLE=()
    ARRAY_CONTENT=()
    for((i = 0; i < $LENGTH; i++))
    do
        # 替换百分号可能引起的printf输出异常，只能在jq后解析，而不能单独通过echo解析
        title=`jq -r ".[$i].title" $tmpfile | sed "s/\%/\%\%/g"`
        content=`jq -r ".[$i].content" $tmpfile | sed "s/\%/\%\%/g"`
        member=`jq -r ".[$i].member.username" $tmpfile`
        node_title=`jq -r ".[$i].node.title" $tmpfile | sed "s/\%/\%\%/g"`
        replies=`jq -r ".[$i].replies" $tmpfile`
        title="$blue$node_title$reset $green$title$reset $pink$member$reset($cyan$replies$reset)"
        id=`jq -r ".[$i].id" $tmpfile`
        ARRAY[$(($i+1))]=$id
        ARRAY_TITLE[$(($i+1))]="$title"
        ARRAY_CONTENT[$(($i+1))]="$content"
        printf "%2d. $title\n" "$(($i+1))"
    done
    # echo ${ARRAY[@]}
}

_date() {
    if [ `uname` = "Darwin" ]; then
        if [ `date +%Y` -eq `date -r $1 +%Y` ]; then
            if [ `date +%m` -eq `date -r $1 +%m` ] && [ `date +%d` -eq `date -r $1 +%d` ]; then
                RET=`date -r $1 +"%H:%M:%S"`
            else
                RET=`date -r $1 +"%m-%d %H:%M:%S"`
            fi
        else
            RET=`date -r $1 +"%Y-%m-%d %H:%M:%S"`
        fi
    else
        if [ `date +%Y` -eq `date -d @$1 +%Y` ]; then
            if [ `date +%m` -eq `date -d @$1 +%m` ] && [ `date +%d` -eq `date -d @$1 +%d` ]; then
                RET=`date -d @$1 +"%H:%M:%S"`
            else
                RET=`date -d @$1 +"%m-%d %H:%M:%S"`
            fi
        else
            RET=`date -d @$1 +"%Y-%m-%d %H:%M:%S"`
        fi
    fi
}

_replies() {
    id=${ARRAY[$1]}
    if ! test $id; then
        printf "${red}列表序列号越界${reset}\n"
        _usage
        return
    fi
    replies_tmpfile="/tmp/ddc.v2ex.replies.tmp"
    printf "${ARRAY_TITLE[$1]}\n${green}${ARRAY_CONTENT[$1]}${reset}\n" > $replies_tmpfile
    tmpfile="/tmp/ddc.v2ex.replies.json"
    curl -s -o $tmpfile "https://www.v2ex.com/api/replies/show.json?topic_id=$id"
    LENGTH=`cat $tmpfile | jq ". | length"`
    if ! test $LENGTH; then
        return
    fi
    for((i = 0; i < $LENGTH; i++))
    do
        content=`jq -r ".[$i].content" $tmpfile | sed "s/\%/\%\%/g"`
        member=`jq -r ".[$i].member.username" $tmpfile`
        created=`jq -r ".[$i].created" $tmpfile`
        thanks=`jq -r ".[$i].thanks" $tmpfile`
        _date $created
        created=$RET
        id=`jq -r ".[$i].member.id" $tmpfile`
        if [ $thanks != "0" ]; then
            printf "\n${blue}%3dL${reset}. $pink$member$reset $cyan$created$reset ♥️ $RED$thanks$reset\n${green}$content${reset}\n" "$(($i+1))" >> $replies_tmpfile
        else
            printf "\n${blue}%3dL${reset}. $pink$member$reset $cyan$created$reset\n${green}$content${reset}\n" "$(($i+1))" >> $replies_tmpfile
        fi
    done
    # 只有加上-r选项，多行文本的ascii color才会被当作一行处理显示，但是却有回滚时颜色不连续的异常，属于less的bug，暂不能解决。
    less -rms $replies_tmpfile
}

_sel() {
    case "$MODE" in
        hot | late | node)
            _replies $1
            ;;
        *)
            ;;
    esac
}

_usage() {
    printf "Usage:\n"
    printf "\thot: 热门主题\n"
    printf "\tlate: 最新主题\n"
    printf "\tnode <nodename>: 获取节点的主题\n"
    printf "\t<num>: 获取指定主题的回复列表\n"
    printf "\thelp: 查看帮助\n"
    printf "\tq|quit: 退出\n"
}

while true
do
    UPMODE=`echo $MODE | tr "[:lower:]" "[:upper:]"`
    printf "$UPMODE # "
    read data
    if ! test "$data"; then
        continue
    fi
    op=`echo $data | cut -d " " -f 1`
    case "$op" in
        q | quit)
            break
            ;;
        late)
            _topics topics latest
            MODE=$op
            ;;
        hot)
            _topics topics hot
            MODE=$op
            ;;
        node)
            node=`echo $data | cut -d " " -f 2`
            if [ $node != $op ]; then
                _topics node $node
                MODE=node
            else
                printf "${red}使用node <nodename>格式${reset}\n"
            fi
            ;;
        help)
            _usage
            ;;
        *)
            if [ $op -eq $op ] 2>/dev/null ; then
                if [ $MODE = "none" ]; then
                    printf "${red}请先选择主题列表${reset}\n"
                    _usage
                fi
                _sel $op
            else
                _usage
            fi
            ;;
    esac
done
