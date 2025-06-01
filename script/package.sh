#!/usr/bin/env bash

script_dir=$(cd "$(dirname "$0")" || exit;pwd)

work_dir=$(
  cd "${script_dir}"/.. || exit 1
  pwd
)

version=$(node -p "require('${work_dir}/package.json').version")
if [ -n "$1" ]; then
  version="$1"
fi

if [ -z "${version}" ]; then
  echo -e "the version couldnot be zero"
  exit 3
fi

index=1
echo -e "\nstep $index -- yeying-app-identity package version: ${version} "


function record_version_information() {
  local recode_file=$1
  echo -e "\n========branch information:" | tee "$recode_file"
  git branch --show-current | tee -a "$recode_file"
  echo -e "\n========commit log information:" >> "$recode_file"
  git log -3 | grep -v Author | tee -a "$recode_file"
  echo -e "\n====Finished" | tee -a "$recode_file"
}


dist_dir=${work_dir}/dist

index=$((index+1))
echo -e "\nstep $index -- This is going to generate package for yeying-app-identity"
output_dir=${work_dir}/output
if [ -d "${output_dir}" ]; then
  rm -rf "${output_dir}"
fi


index=$((index+1))
echo -e "\nstep $index -- prepare package files under directroy: ${output_dir}"
package_name=yeying-app-identity-${version}
file_name=$package_name.tar.gz
yeying_service_dir=${output_dir}/${package_name}
mkdir -p "${yeying_service_dir}"


index=$((index+1))
echo -e "\nstep $index -- copy necessary file to  ${yeying_service_dir}"
if [ ! -d "${dist_dir}" ]; then
  echo -e "please execute 'npm run build' before package!"
  exit 1
fi
cp -rf "${dist_dir}" "${yeying_service_dir}"/
cp -rf "${script_dir}" "${yeying_service_dir}"/
formatted_date=$(date '+%Y%m%d_%H%M%S')
VERSION_FILE="version_information_$formatted_date"
record_version_information "$VERSION_FILE"
mv "$VERSION_FILE" "${yeying_service_dir}"/


sleep 1
index=$((index+1))
echo -e "\nstep $index -- generate package file"
pushd "${output_dir}" || exit 2
tar -zcf "${file_name}" "${package_name}"
rm -rf "${package_name}"
popd  || exit 2


index=$((index+1))
echo -e "\nstep $index -- package : ${file_name} under [ ${output_dir} ] is ready. $(date)"