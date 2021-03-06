
# wait for the Icinga2 Master
#
wait_for_icinga_master() {

  if [[ -z "${ICINGA2_MASTER}" ]]
  then
    log_error "ICINGA2_MASTER isn't set"
    exit 1
  fi

  log_info "wait for icinga2 master '${ICINGA2_MASTER}'"

  . /init/wait_for/dns.sh
  . /init/wait_for/port.sh

  wait_for_dns ${ICINGA2_MASTER}
  wait_for_port ${ICINGA2_MASTER} 5665 50

  if [[ "${ICINGAWEB_DIRECTOR}" == "true" ]]
  then

    log_info "For a clean director configuration, the Icinga2 Master must run for at least ${ICINGA2_UPTIME} seconds without interruption."

    RETRY=50

    until [[ ${RETRY} -le 0 ]]
    do
      code=$(curl \
        --silent \
        --user ${ICINGA2_CMD_API_USER}:${ICINGA2_CMD_API_PASS} \
        --header 'Accept: application/json' \
        --insecure \
        https://${ICINGA2_MASTER}:5665/v1/status/CIB)

      if [[ $? -eq 0 ]]
      then
          uptime=$(echo "${code}" | jq --raw-output ".results[].status.uptime")

          utime=${uptime%.*}

          if [[ ${utime} -gt ${ICINGA2_UPTIME} ]]
          then
            break
            log_info "The icinga2 master '${ICINGA2_MASTER}' has uptime of ${utime}"
          else
            log_info "The icinga2 master '${ICINGA2_MASTER}' has uptime of ${utime}"
            sleep 20s
            RETRY=$(expr ${RETRY} - 1)
          fi
      else
        sleep 10s
        RETRY=$(expr ${RETRY} - 1)
      fi
    done

    sleep 5s

    log_info "The icinga2 master '${ICINGA2_MASTER}' seems to be available stable"
  fi
}

wait_for_icinga_master
