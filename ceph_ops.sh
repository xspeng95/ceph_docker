#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
test  ${basedir} == ${PWD}
source ${basedir}/scripts/functions.sh

cephLocalRoot=$(cd ${basedir}/../ceph_all;pwd)
cephDockerRoot=/home/ceph/ceph
srcDir=/home/grakra/workspace/ceph

ceph_mon_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_mon\d+\s*$/' ${PWD}/hosts |wc -l);
ceph_osd_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_osd\d+\s*$/' ${PWD}/hosts |wc -l);
ceph_mgr_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_mgr\d+\s*$/' ${PWD}/hosts |wc -l);
ceph_mds_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_mds\d+\s*$/' ${PWD}/hosts |wc -l);
ceph_client_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_client\d+\s*$/' ${PWD}/hosts |wc -l);
ceph_rgw_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+ceph_rgw\d+\s*$/' ${PWD}/hosts |wc -l);

ceph_mon_num_init=$(min ${ceph_mon_num} 3)
ceph_osd_num_init=$(min ${ceph_osd_num} 3)
ceph_mgr_num_init=$(min ${ceph_mgr_num} 3) 
ceph_mds_num_init=$(min ${ceph_mds_num} 3)
ceph_client_num_init=$(min ${ceph_client_num} 3)
ceph_rgw_num_init=$(min ${ceph_rgw_num} 3)

dockerFlags="--rm -u ceph -w /home/ceph --privileged --net static_net0 \
  -e PATH=${srcDir}/build/ceph-volume-virtualenv/bin:${srcDir}/build/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -v ${PWD}/hosts:/etc/hosts \
  -v ${PWD}/ceph_conf:/etc/ceph \
  -v ${srcDir}:${srcDir} \
  -v /lib/modules:/lib/modules \
  -v ${PWD}/scripts:/home/ceph/scripts" 

dockerImage="ceph_build:v15.0.0"

stop_node(){
  local name=$1;shift
  set +e +o pipefail
  docker kill ${name}
  docker rm ${name}
  set -e -o pipefail
}

ceph_cmd(){
  local node=${1:?"undefined 'node'"};shift
  local detach=${1:?"undefined 'detach'"};shift
  local hup=${1:?"undefined 'hup'"};shift
  checkArgument detach ${detach} "attach|detach"
  checkArgument hup ${hup} "hup|nohup"
  local role=$(perl -e "print \$1 if qq/${node}/=~/ceph_(\\w+?)\\d+$/")

  local mode="-it"
  if isIn ${detach} "detach";then
    local mode="-dit"
  fi

  local cmd="$*"
  if isIn ${hup} "hup";then
    local cmd="$* && sleep 100000000"
  fi

	local ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)

  local dataDir=$(cd $(readlink -f ${PWD}/data/${node}_data);pwd)
  local extraDockerFlags="--hostname ${node} --name ${node} --ip ${ip} \
    -v ${PWD}/data/${node}_logs:/var/log/ceph \
    -v ${PWD}/data/${node}_run:/var/run/ceph \
    -v ${dataDir}:/home/ceph/${role}"

  docker run ${mode} ${dockerFlags} ${extraDockerFlags} ${dockerImage} /bin/bash -c "${cmd}"
}

login_ceph_node(){
  ceph_cmd ${1:?"missing node"} attach nohup /bin/bash
}

bootstrap_ceph_mon(){
  ceph_cmd ${1:?"undefined 'node'"} attach nohup /home/ceph/scripts/bootstrap_ceph_mon.sh
  #ceph_cmd ${1:?"undefined 'node'"} attach nohup /bin/bash
}

mkfs_ceph_mon(){
  local node=$1;shift
  ceph_cmd ${node} attach nohup /home/ceph/scripts/mkfs_ceph_mon.sh
}

mkfs_all_ceph_mon(){
  for node in $(eval "echo ceph_mon{0..$((${ceph_mon_num_init}-1))}") ;do
    mkfs_ceph_mon ${node}
  done
}

bootstrap_all_ceph_mon(){
  stop_all_ceph_mon
  bootstrap_ceph_mon ceph_mon0
  mkfs_all_ceph_mon
}

start_ceph_mon(){
  local node=$1;shift
  ceph_cmd ${node} detach hup /home/ceph/scripts/start_ceph_mon.sh
  #ceph_cmd ${node} attach nohup /bin/bash
}

start_all_ceph_mon(){
  for node in $(eval "echo ceph_mon{0..$((${ceph_mon_num_init}-1))}") ;do
    start_ceph_mon ${node}
  done
}

stop_ceph_mon(){
  stop_node ${1:?"missing 'node'"}
}

stop_all_ceph_mon(){
  for node in $(eval "echo ceph_mon{0..$((${ceph_mon_num_init}-1))}") ;do
    stop_ceph_mon ${node}
  done
}

restart_ceph_mon(){
  stop_ceph_mon  ${1:?"missing 'node'"}
  start_ceph_mon $1
}

restart_all_ceph_mon(){
  for node in $(eval "echo ceph_mon{0..$((${ceph_mon_num_init}-1))}") ;do
    restart_ceph_mon ${node}
  done
}

start_ceph_client(){
  ceph_cmd ${1:?"missing 'node'"} attach nohup /bin/bash
}

ceph_argv(){
  local node=${1:?"missing 'node'"};shift
  ceph_cmd ${node}  attach nohup "$*"
}

stop_ceph_clent(){
  stop_node ${1:?"missing 'node'"}
}

restart_ceph_client(){
  stop_ceph_client ${1:?"missing 'node'"}
  start_ceph_client $1
}

#################################################################
## ceph-osd

bootstrap_ceph_osd(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /home/ceph/scripts/bootstrap_ceph_osd.sh
}

bootstrap_all_ceph_osd(){
  for node in $(eval "echo ceph_osd{0..$((${ceph_osd_num_init}-1))}") ;do
    bootstrap_ceph_osd ${node}
  done
}

stop_ceph_osd(){
  local node=$1;shift
  stop_node ${name}
}

stop_all_ceph_osd(){
  for node in $(eval "echo ceph_osd{0..$((${ceph_osd_num_init}-1))}") ;do
    stop_node ${node}
  done
}


start_ceph_osd(){
  local node=$1;shift
  ceph_cmd ${node} detach hup /home/ceph/scripts/start_ceph_osd.sh
}

start_all_ceph_osd(){
  for node in $(eval "echo ceph_osd{0..$((${ceph_osd_num_init}-1))}") ;do
    start_ceph_osd ${node}
  done
}

restart_ceph_osd(){
  local node=$1;shift
  stop_node ${node}
  start_ceph_osd ${node}
}

restart_all_ceph_osd(){
  for node in $(eval "echo ceph_osd{0..$((${ceph_osd_num_init}-1))}") ;do
    restart_ceph_osd ${node}
  done
}

###############################################################################
# ceph-mgr

bootstrap_ceph_mgr(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /home/ceph/scripts/bootstrap_ceph_mgr.sh
}

bootstrap_all_ceph_mgr(){
  for node in $(eval "echo ceph_mgr{0..$((${ceph_mgr_num_init}-1))}") ;do
    bootstrap_ceph_mgr ${node}
  done
}

start_ceph_mgr(){
  ceph_cmd ${1:?"undefined node"} detach hup /home/ceph/scripts/start_ceph_mgr.sh
}

start_all_ceph_mgr(){
  for node in $(eval "echo ceph_mgr{0..$((${ceph_mgr_num_init}-1))}") ;do
    start_ceph_mgr ${node}
  done
}

stop_ceph_mgr(){
  stop_node ${1:?"undefined node"}
}

stop_all_ceph_mgr(){
  for node in $(eval "echo ceph_mgr{0..$((${ceph_mgr_num_init}-1))}") ;do
    stop_ceph_mgr ${node}
  done
}

restart_ceph_mgr(){
  stop_ceph_mgr ${1:?"undefined node"}
  start_ceph_mgr $1
}

restart_all_ceph_mgr(){
  for node in $(eval "echo ceph_mgr{0..$((${ceph_mgr_num_init}-1))}") ;do
    restart_ceph_mgr ${node}
  done
}

##############################################################################
# rgw

bootstrap_ceph_rgw(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /home/ceph/scripts/bootstrap_ceph_rgw.sh
}

login_ceph_rgw(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /bin/bash
}

bootstrap_all_ceph_rgw(){
  for node in $(eval "echo ceph_rgw{0..$((${ceph_rgw_num_init}-1))}") ;do
    bootstrap_ceph_rgw ${node}
  done
}

start_ceph_rgw(){
  ceph_cmd ${1:?"undefined node"} detach hup /home/ceph/scripts/start_ceph_rgw.sh
}

start_all_ceph_rgw(){
  for node in $(eval "echo ceph_rgw{0..$((${ceph_rgw_num_init}-1))}") ;do
    start_ceph_rgw ${node}
  done
}

stop_ceph_rgw(){
  stop_node ${1:?"undefined node"}
}

stop_all_ceph_rgw(){
  for node in $(eval "echo ceph_rgw{0..$((${ceph_rgw_num_init}-1))}") ;do
    stop_ceph_rgw ${node}
  done
}

restart_ceph_rgw(){
  stop_ceph_rgw ${1:?"undefined node"}
  start_ceph_rgw $1
}

restart_all_ceph_rgw(){
  for node in $(eval "echo ceph_rgw{0..$((${ceph_rgw_num_init}-1))}") ;do
    restart_ceph_rgw ${node}
  done
}

##########################################################################
# mds

bootstrap_ceph_mds(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /home/ceph/scripts/bootstrap_ceph_mds.sh
}

login_ceph_mds(){
  local node=$1;shift
  stop_node ${node}
  ceph_cmd ${node} attach nohup /bin/bash
}

bootstrap_all_ceph_mds(){
  for node in $(eval "echo ceph_mds{0..$((${ceph_mds_num_init}-1))}") ;do
    bootstrap_ceph_mds ${node}
  done
}

start_ceph_mds(){
  ceph_cmd ${1:?"undefined node"} detach hup /home/ceph/scripts/start_ceph_mds.sh
}

start_all_ceph_mds(){
  for node in $(eval "echo ceph_mds{0..$((${ceph_mds_num_init}-1))}") ;do
    start_ceph_mds ${node}
  done
}

stop_ceph_mds(){
  stop_node ${1:?"undefined node"}
}

stop_all_ceph_mds(){
  for node in $(eval "echo ceph_mds{0..$((${ceph_mds_num_init}-1))}") ;do
    stop_ceph_mds ${node}
  done
}

restart_ceph_mds(){
  stop_ceph_mds ${1:?"undefined node"}
  start_ceph_mds $1
}

restart_all_ceph_mds(){
  for node in $(eval "echo ceph_mds{0..$((${ceph_mds_num_init}-1))}") ;do
    restart_ceph_mds ${node}
  done
}

##########################################################################
# cluster

bootstrap_ceph_cluster(){
  bootstrap_all_ceph_mon
  bootstrap_all_ceph_osd
  bootstrap_all_ceph_mgr
}

start_ceph_cluster(){
  start_all_ceph_mon
  start_all_ceph_osd
  start_all_ceph_mgr
}

bootstrap_start_ceph_cluster(){
  bootstrap_all_ceph_mon
  start_all_ceph_mon
  bootstrap_all_ceph_osd
  start_all_ceph_osd
  bootstrap_all_ceph_mgr
  start_all_ceph_mgr
  ceph_argv ceph_client0 ceph mon enable-msgr2
  ceph_argv ceph_client0 ceph -s
  ceph_argv ceph_client0 ceph df
}

stop_ceph_cluster(){
  stop_all_ceph_mgr
  stop_all_ceph_osd
  stop_all_ceph_mon
}

restart_ceph_cluster(){
  restart_all_ceph_mon
  restart_all_ceph_osd
  restart_all_ceph_mgr
}
