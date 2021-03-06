#!/bin/bash
#
# install a set of icingaweb2 themes

[[ "${INSTALL_THEMES}" = "false" ]] && exit 0

echo "install icingaweb2 themes"

MODULE_DIRECTORY="/usr/share/icingaweb2/modules"

cd /tmp

if [[ -f /build/themes.json ]]
then
  THEMES_JSON=$(cat /build/themes.json)
else
  THEMES_JSON='{
    "Mikesch-mp/icingaweb2-theme-unicorn" : {
      "image": [{
        "name": "unicorn.png",
        "url": "http://i.imgur.com/SCfMd.png"
      }]
    },
    "Icinga/icingaweb2-theme-company": {},
    "jschanz/icingaweb2-theme-batman": {},
    "sysadmama/icingaweb2-theme-nordlicht": {},
    "dnsmichi/icingaweb2-theme-spring": {},
    "vita2/icingaweb2-module-theme-dark": {}
  }'
fi

#set -e

for k in $(echo ${THEMES_JSON} | jq -r '. | to_entries | .[] | .key')
do
  enable="$(echo "${THEMES_JSON}" | jq -r ".[\"$k\"].enable")"
  [[ "${enable}" == null ]] && enable=true

  project="$(echo "${k}" | sed -e 's|\.git||g' -e 's/https\?:\/\///' -e 's|github.com/||g')"
  project_maintainer="$(echo "${project}" | cut -d "/" -f1)"
  project_name="$(echo "${project}" | cut -d "/" -f2 | sed -e 's|icingaweb2-||g' -e 's|module-||g' -e 's|theme-||g' | tr [:upper:] [:lower:])"
  outpath=$(echo "${project}" | tr [:upper:] [:lower:] | sed -e 's|/|_|g')

  #echo " - ${project_name} (${project_maintainer})"

  #[[ -d ${outpath} ]] || mkdir ${outpath}
  #[[ -d ${MODULE_DIRECTORY}/${project_name} ]] || mkdir ${MODULE_DIRECTORY}/${project_name}
  #
  #pushd ${outpath} > /dev/null
  #
  #git clone https://github.com/${k} 2> /dev/null
  #
  #images=$(echo "${THEMES_JSON}" | jq -r ".[\"$k\"].image")
  #
  #if [[ $images != null ]]
  #then
  #  data=$(echo "${THEMES_JSON}" | jq -r ".[\"$k\"].image")
  #
  #  for row in $(echo "${data}" | jq -r '.[] | @base64'); do
  #    _jq() {
  #      echo ${row} | base64 -d | jq -r ${1}
  #    }
  #
  #    name=$(_jq '.name')
  #    url=$(_jq '.url')
  #
  #    curl \
  #      --silent \
  #      --location \
  #      --retry 3 \
  #      --output ${name} \
  #      ${url}
  #
  #    mv ${name} */public/img/
  #  done
  #fi
  #
  #mv */public ${MODULE_DIRECTORY}/${project_name}/

  if [[ "${enable}" = "true" ]]
  then
    echo "   enable module"
    /usr/bin/icingacli module enable ${project_name} 2> /dev/null
  fi

  # popd > /dev/null
done
