#!/usr/bin/env bash

COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_NC='\033[0m'

base_name="${0##*/}"
script_dir=$(
  cd $(dirname "$0") || exit 1
  pwd
)

source "${script_dir}"/functions.sh

work_dir=$(
  cd "${script_dir}"/.. || exit 1
  pwd
)

usage() {
  printf "Usage: %s\n \
    -d <Set debug mode.> \n \
    -h <Set http proxy port.> \n \
    -e <Set run environment, such as dev or prod.> \n \
    -t <Set http tls enable> \n \
    " "${base_name}"
}


env=dev
tls=false
# For macos`s getopt, reference: https://formulae.brew.sh/formula/gnu-getopt
while getopts ":dth:e:" o; do
  case "${o}" in
  t)
    tls=true
    ;;
  # d)
  #   debug_param='--debug'
  #   ;;
  h)
    http_port=${OPTARG}
    ;;
  e)
    env=${OPTARG}
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

if [ "${env}" == "dev" ]; then
  # 默认开发环境的端口，为了方便调试，不同的服务，以及服务运行的环境不一样，端口也都会有区别，另外用户也可以强制指定端口
  if [ -z "${http_port}" ]; then
    http_port=8451
  fi
elif [ "${env}" == "prod" ]; then
  if [ -z "${http_port}" ]; then
    http_port=8452
  fi
else
  echo -e "${COLOR_RED}Not supported environment variable, please set dev or prod!${COLOR_NC}"
  usage
  exit 1
fi

# 设置 base_id
base_id=${http_port}

index=1
printf "\n"
echo -e "step $index -- This is going to start node under ${COLOR_BLUE} ${env} ${COLOR_NC} environment. [$(date)]"
echo "work dir=${work_dir}, http port=${http_port}"

run_dir=${work_dir}/run

identity_file=${run_dir}/app.id
des_log_dir=${run_dir}/log
password_file=${run_dir}/password

if [ ! -d "${run_dir}" ]; then
  mkdir -p "${run_dir}"
fi

if [ ! -d "${des_log_dir}" ]; then
  mkdir -p "${des_log_dir}"
fi

index=$((index + 1))
printf "\n"
echo -e "step $index -- kill process if these exist"
# 如果pid文件存在，则读取其中的进程ID并杀死这些进程
pid_file=${run_dir}/pid.txt
kill_process_with_pid_file "${pid_file}" true

cd "${run_dir}" || exit 1

read -r -s -p "Enter Password: " IDENTITY_PASSWORD
# 将密码写入文件，macos不支持echo命令的-n选项，为了避免写入文件存在换行符，使用printf替代。
printf "%s" "${IDENTITY_PASSWORD}" > "${password_file}"
printf "\n"

index=$((index+1))
echo -e "step $index -- start node service"
# start store service
npm install
npm run build
nohup node "${work_dir}/dist/server.js" "${password_file}" "${http_port}" > "${des_log_dir}/start.log" 2>&1 &
echo $! >> "${pid_file}"

index=$((index+1))
printf "\n"
echo -e "step $index -- check http port of node"
if check_service_port 10 1 "${http_port}"; then
  echo "http of application started successfully."
else
  echo -e "${COLOR_RED}http of application Not started yet. ${COLOR_NC}"
fi

if [ -f "${password_file}" ]; then
  rm -rf "${password_file}"
fi


echo "application startup operation finished. [$(date)]"
