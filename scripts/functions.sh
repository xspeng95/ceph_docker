#!/bin/bash
selectWord(){
  local words=${1:?"undefined 'words'"};shift
  local sep=${1:?"undefined 'sep'"};shift
  local kw=${1:?"undefined 'kw'"};shift
  perl -e "print (join qq{\\t}, (grep /^${kw}/, (split qq/${sep}/, qq/${words}/)))"
}

kill2docker(){
  local p=${1:?"undefined 'p'"};shift
  local kw=${1:?"undefined 'p'"};shift
  docker kill $p
}

killAll(){
  local comp=$(docker ps -a --format "{{.Names}}"|perl -lne 'chomp;push @a,$_}{print join ":", @a')
  local kw=${1:?"missing 'keyword'"};shift
  for p in $(selectWord ${comp} ":" ${kw});do
    echo kill2docker $p ${kw}
    kill2docker $p ${kw}
  done
}

selectOption(){
  test $# -gt 0
  select opt in $*;do
    echo ${opt}
    break;
  done
}

selectHostList(){
  local dir=${1:?"missing 'dir'"};shift
  dir=${dir%%/}
  local oldshopt=$(set +o)
  set -e -o pipefail
  test -d ${dir}
  local n=$(ls ${dir}|wc -l)
  test ${n} -gt 0
  local selectList=$(ls ${dir}|xargs -i{} basename '{}')
  local chosed=""
  select opt in ${selectList};do
    chosed=${opt}
    break;
  done
  set +vx;eval "${oldshopt}"
  echo ${dir}/${chosed}
}

confirm(){
  echo -n "Are your sure[yes/no]: "
    while : ; do
      read input
      input=$(perl -e "print qq/\L${input}\E/")
      case ${input} in
        y|ye|yes)
          break
          ;;
        n|no)
          echo "operation is cancelled!!!"
          exit 0
          ;;
        *)
          echo -n "invalid choice, choose again!!! [yes|no]: "
          ;;
      esac
    done
}

checkArgument(){
  local name=${1:?"missing 'name'"};shift
  local arg=${1:?"missing 'arg'"};shift
  local alternatives=${1:?"missing 'alternatives'"};shift

  if [ -z ${alternatives} ];then
    red_print "ERROR: empty alternatives for '${name}', value='${arg}'"
    exit 1
  fi

  if test x$(perl -e "print qq/${alternatives}/=~/^\w+(?:\|\w+)*$/")x != x1x;then
    red_print "ERROR: alternatives must be in format word1|word2|word3..., name='${name}', value='${arg}', alternatives='${alternatives}"
    exit 2
  fi

  if test x$(perl -e "print qq/$arg/=~/^(?:${alternatives})$/")x != x1x; then
    red_print "ERROR: unmatched argument, name='${name}', value='${arg}', alternatives='${alternatives}'"
    exit 1
  fi
}

isIn(){
  local arg=${1:?"missing 'arg'"};shift
  local alternatives=${1:-"823c843e5ab037c2ca8426b5eb083da8"};shift

  if [ -z ${alternatives} ];then
    echo "ERROR: empty alternatives, value=${arg}" >&2
    exit 1
  fi

  if test x$(perl -e "print qq/${alternatives}/=~/^\w+(?:\|\w+)*$/")x != x1x;then
    echo "ERROR: alternatives must be in format word1|word2|word3..., value='${arg}', alternatives='${alternatives}" >&2
    exit 2
  fi

  if test x$(perl -e "print qq/$arg/=~/^(?:${alternatives})$/")x != x1x; then
    return 1
  else
    return 0
  fi
}

startsWith(){
  local arg=${1:?"missing 'arg'"};shift
  local prefix=${1:?"missing 'prefix'"};shift
  if [ "x${arg##${prefix}}x" = "x${arg}x" ];then
    return 1
  else
    return 0
  fi
}

endsWith(){
  local arg=${1:?"missing 'arg'"};shift
  local suffix=${1:?"missing 'prefix'"};shift
  if [ "x${arg%%${suffix}}x" = "x${arg}x" ];then
    return 1
  else
    return 0
  fi
}

green_print(){
  echo -e "\e[32;40;1m$*\e[m" 
}

red_print(){
  echo -e "\e[31;40;1m$*\e[m"
}

yellow_print(){
  echo -e "\e[33;100;1m$*\e[m"
}

hrule(){
  yellow_print "###############################################"
}

replace(){
  local s=${1:?"undefind 's'"};shift
  local a=${1:?"undefined 'a'"};shift
  local b=${1:?"undefined 'b'"};shift
  perl -e "print qq/${s}/ =~ y/${a}/${b}/r"
}

replace_before_remove_whitespace(){
  local s=${1:?"undefined 's'"};shift
  local a=${1:?"undefined 'a'"};shift
  local b=${1:?"undefined 'b'"};shift
  perl -e "print qq/${s}/ =~ s/\\s*//gr =~ y/${a}/${b}/r"
}

split_head_tail(){
  local text=${1:?"missing 'text'"};shift
  local sep=${1:?"missing 'sep'"};shift
  perl -e "my (\$car, @cdr) = (split /\\s*${sep}\\s*/, qq/${text}/=~s/^\\s*|\\s*$//gr); print \$car, qq/ /, join(qq/${sep}/, @cdr)"
}

list_head(){
  local text=${1:?"missing 'text'"};shift
  local sep=${1:?"missing 'sep'"};shift
  set $(split_head_tail ${text} ${sep})
  echo ${1:-""}
}

list_tail(){
  local text=${1:?"missing 'text'"};shift
  local sep=${1:?"missing 'sep'"};shift
  set $(split_head_tail ${text} ${sep})
  shift
  echo ${1:-""}
}

max(){
  local m=${1:?"missing arg"};shift
  for e in $*;do
    if [ $e -gt $m ];then
      m=$e
    fi
  done
  echo $m
}

min(){
  local m=${1:?"missing arg"};shift
  for e in $*;do
    if [ $e -lt $m ];then
      m=$e
    fi
  done
  echo $m
}
