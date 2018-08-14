#!/bin/bash
#
# install a set of icingaweb2 modules

set -e

[[ "${INSTALL_MODULES}" = "false" ]] && exit 0

echo "install icingaweb2 modules"


MODULE_DIRECTORY="/usr/share/webapps/icingaweb2/modules"

if [[ -f /build/modules.json ]]
then
  MODULE_JSON=$(cat /build/modules.json)
else
  MODULE_JSON='{
    "Icinga/icingaweb2-module-director": {},
    "Icinga/icingaweb2-module-vsphere": {},
    "Icinga/icingaweb2-module-graphite": {},
    "Icinga/icingaweb2-module-generictts": {},
    "Icinga/icingaweb2-module-businessprocess": {},
    "Icinga/icingaweb2-module-elasticsearch": {},
    "Icinga/icingaweb2-module-cube": {},
    "Icinga/icingaweb2-module-aws": {},
    "Icinga/icingaweb2-module-fileshipper": {},
    "https://github.com/Icinga/icingaweb2-module-toplevelview": {},
    "http://github.com/Mikesch-mp/icingaweb2-module-grafana.git": {},
    "https://github.com/Mikesch-mp/icingaweb2-module-globe": {},
    "nbuchwitz/icingaweb2-module-map": {},
    "Thomas-Gelf/icingaweb2-module-vspheredb": {
      "enable": "false"
    },
    "morgajel/icingaweb2-module-boxydash": {}
  }'
fi

echo " - get latest published versions"

current_time=$(date +%s)

for k in $(echo ${MODULE_JSON} | jq -r '. | to_entries | .[] | .key')
do
  enable="$(echo "${MODULE_JSON}" | jq -r ".[\"$k\"].enable")"
  use_git="$(echo "${MODULE_JSON}" | jq -r ".[\"$k\"].use_git")"
  [[ "${enable}" == null ]] && enable=true
  [[ "${use_git}" == null ]] && use_git=false

  project="$(echo "${k}" | sed -e 's|\.git||g' -e 's/https\?:\/\///' -e 's|github.com/||g')"
  project_maintainer="$(echo "${project}" | cut -d "/" -f1)"
  project_name="$(echo "${project}" | cut -d "/" -f2 | sed -e 's|icingaweb2-module-||g')"
  outfile=$(echo "${project}" | tr [:upper:] [:lower:] | sed -e 's|/|_|g')

  if [[ -f "/build/cache/github_${outfile}.json" ]]
  then
    file_time=$(stat -c '%Y' "/build/cache/github_${outfile}.json")

    echo "${file_time}"

    if (( file_time < ( current_time - ( 60 * 60 * 24 * 10 ) ) )); then
      echo "cached file for github_${outfile}.json is older than 10 days"
    else
      echo "use cached file"
      cp -v /build/cache/github_${outfile}.json /tmp/
    fi
  else
    echo "no cache"
  fi

  if [[ ! -f "github_${outfile}.json" ]]
  then
    curl \
      --silent \
      --out "/tmp/github_${outfile}.json" \
      https://api.github.com/repos/${project}/releases/latest
  fi

  cat "github_${outfile}.json" | \
    jq ". |= .+ {\"enable\": \"${enable}\", \"use_git\": \"${use_git}\", \"project_maintainer\": \"${project_maintainer}\", \"project_name\": \"${project_name}\" }" > /tmp/github_${outfile}.json_TMP
  mv /tmp/github_${outfile}.json_TMP /tmp/github_${outfile}.json

done

cd /tmp

for file in $(ls -1 github_*.json)
do
  published_at=$(jq --raw-output ".published_at" ${file})
  project_name=$(jq --raw-output ".project_name" ${file})
  project_maintainer=$(jq --raw-output ".project_maintainer" ${file})
  author=$(jq --raw-output ".author.login" ${file})
  version=$(jq --raw-output ".tag_name" ${file})
  url=$(jq --raw-output ".tarball_url" ${file})
  enable=$(jq --raw-output ".enable" ${file})
  use_git=$(jq --raw-output ".use_git" ${file})

  if [[ ${published_at} != null ]]
  then
    if [[ -e /etc/alpine-release ]]
    then
      release_date=$(date -d @$(date -u -D %Y-%m-%dT%TZ -d "${published_at}" +%s) +%d.%m.%Y)
    else
      release_date=$(date -d ${published_at} +%d.%m.%Y)
    fi

    release="released at ${release_date}"

    if [[ "${use_git}" == "true" ]]
    then
      release="${release} but use git"
    fi

  else
    version=""
    release="never released, use git"
  fi

  echo " - ${project_maintainer} :: ${project_name} ${version} (${release})"

  if [[ ${url} != null ]] && [[ "${use_git}" = "false" ]]
  then
    if [[ ! -f "${project_name}.tgz" ]]
    then
    curl \
      --silent \
      --location \
      --retry 3 \
      --output "${project_name}.tgz" \
      ${url}
    fi

    if [[ -f "${project_name}.tgz" ]]
    then
      [[ -d ${MODULE_DIRECTORY} ]] || continue

      tar -xzf ${project_name}.tgz
      find . -mindepth 1 -maxdepth 1 -type d -name "*${project_name}*" -exec mv {} ${MODULE_DIRECTORY}/${project_name} \;

      rm -f ${project_name}.tgz
      mkdir /etc/icingaweb2/modules/${project_name}
    fi

  else
    [[ -d icingaweb2-module-${project_name} ]] && rm -rf icingaweb2-module-${project_name}
    git clone \
      --quiet \
      https://github.com/${project_maintainer}/icingaweb2-module-${project_name} > /dev/null

    [[ -d ${MODULE_DIRECTORY} ]] || continue

    mv icingaweb2-module-${project_name} ${MODULE_DIRECTORY}/${project_name}
  fi

  if [[ "${enable}" = "true" ]]
  then
    /usr/bin/icingacli module enable ${project_name} 2> /dev/null
  fi
done

find ${MODULE_DIRECTORY} -name ".git*" -exec rm -rf {} 2> /dev/null \; || true
