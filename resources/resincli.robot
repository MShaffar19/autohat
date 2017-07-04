*** Settings ***
Documentation    This resource provides access to resin commands.
Library   Process
Library   OperatingSystem

*** Variables ***

*** Keywords ***
Resin login with email "${email}" and password "${password}"
    ${result} =  Run Process    resin login --credentials --email ${email} --password ${password}    shell=yes    timeout=30sec
    Process ${result}
    ${result} =  Run Process    resin whoami |sed '/USERNAME/!d' |sed 's/^.*USERNAME: //'   shell=yes
    Process ${result}
    Set Suite Variable    ${RESINUSER}    ${result.stdout}

Add new SSH key with name "${key_name}"
    Remove File    /root/.ssh/id_ecdsa
    ${result} =  Run Process    ssh-keygen -b 521 -t ecdsa -f /root/.ssh/id_ecdsa -N ''    shell=yes
    Process ${result}
    ${word_count} =  Run Process    resin keys |grep -w ${key_name} |cut -d ' ' -f 1 | wc -l    shell=yes
    Process ${word_count}
    :FOR    ${i}    IN RANGE    ${word_count.stdout}
    \    ${result} =  Run Process    resin keys |grep -w ${key_name} |cut -d ' ' -f 1 | head -1    shell=yes
    \    Log   all output: ${result.stdout}
    \    Run Process    resin key rm ${result.stdout} -y    shell=yes
    ${result} =  Run Process    resin key add ${key_name} /root/.ssh/id_ecdsa.pub   shell=yes
    Process ${result}

Create application "${application_name}" with device type "${device}"
    ${result} =  Run Process    resin app create ${application_name} --type\=${device}    shell=yes
    Process ${result}
    Should Match    ${result.stdout}    *Application created*

Delete application "${application_name}"
    ${result} =  Run Process    resin app rm ${application_name} --yes    shell=yes
    Process ${result}

Force delete application "${application_name}"
    Run Keyword And Ignore Error    Delete application "${application_name}"

Git clone "${git_url}" "${directory}"
    Remove Directory    ${directory}    recursive=True
    ${result} =  Run Process    git clone ${git_url} ${directory}    shell=yes
    Process ${result}

Git checkout "${commit_hash}" "${directory}"
    ${result} =  Run Process    git checkout ${commit_hash}    shell=yes    cwd=${directory}
    Process ${result}

Git push "${directory}" to application "${application_name}"
    Set Environment Variable    RESINUSER    ${RESINUSER}
    ${result} =  Run Process    git remote add resin $RESINUSER@git.${RESINRC_RESIN_URL}:$RESINUSER/${application_name}.git    shell=yes    cwd=${directory}
    Process ${result}
    ${result} =  Run Buffered Process    git push resin HEAD:refs/heads/master    shell=yes    cwd=${directory}
    Process ${result}

Configure "${image}" with "${application_name}"
    File Should Exist     ${image}  msg="Provided images file does not exist"
    ${result_register} =  Run Process    resin device register ${application_name} | cut -d ' ' -f 4    shell=yes
    Process ${result_register}
    ${result} =  Run Process    echo -ne '\n' | resin os configure ${image} ${result_register.stdout}    shell=yes
    Process ${result}
    Return From Keyword    ${result_register.stdout}

Get "${device_info}" of device "${device_uuid}"
    [Documentation]    Available values for argument ${device_info} are:
    ...                ID, DEVICE TYPE, STATUS, IS ONLINE, IP ADDRESS, APPLICATION NAME, UUID, COMMIT,
    ...                SUPERVISOR VERSION, IS WEB ACCESSIBLE, OS VERSION
    @{list} =  Create List    ID    DEVICE TYPE    STATUS    IS ONLINE    IP ADDRESS    APPLICATION NAME    UUID    COMMIT    SUPERVISOR VERSION    IS WEB ACCESSIBLE    OS VERSION
    Should Contain    ${list}    ${device_info}
    ${result} =  Run Keyword If    '${device_info}' == 'OS VERSION'    Run Process    resin device ${device_uuid} | sed -n -e 's/^.*Resin OS //p' | cut -d ' ' -f 1     shell=yes
    ...    ELSE
    ...    Run Process    resin device ${device_uuid} | grep -w "${device_info}" | cut -d ':' -f 2 | sed 's/ //g'    shell=yes
   Process ${result}
   [Return]    ${result.stdout}

Get "${application_info}" from application "${application_name}"
    [Documentation]    Available values for argument ${application_info} are:
    ...                ID, APP_NAME, DEVICE_TYPE, ONLINE_DEVICES, DEVICES_LENGTH
    &{dictionary} =  Create Dictionary    ID=1    APP_NAME=2    DEVICE_TYPE=3    ONLINE_DEVICES=4    DEVICES_LENGTH=5
    ${result} =  Run Process    resin apps | grep -w "${application_name}" | awk '{print $${dictionary.${application_info}}}'    shell=yes
    Process ${result}
    [Return]    ${result.stdout}

Device "${device_uuid}" is online
    ${result} =  Get "IS ONLINE" of device "${device_uuid}"
    Should Contain    ${result}    true

Device "${device_uuid}" is offline
    ${result} =  Get "IS ONLINE" of device "${device_uuid}"
    Should Contain    ${result}    false

Device "${device_uuid}" log should contain "${value}"
    ${result} =  Run Buffered Process    resin logs ${device_uuid}    shell=yes
    Process ${result}
    Should Contain    ${result.stdout}    ${value}

Device "${device_uuid}" log should not contain "${value}"
    ${result} =  Run Buffered Process    resin logs ${device_uuid}    shell=yes
    Process ${result}
    Should Not Contain    ${result.stdout}    ${value}

Check if host OS version of device "${device_uuid}" is "${os_version}"
    ${result} =  Get "OS VERSION" of device "${device_uuid}"
    Should Contain    ${result}    ${os_version}

Add ENV variable "${variable_name}" with value "${variable_value}" to application "${application_name}"
    ${result} =  Run Process    resin env add ${variable_name} ${variable_value} -a ${application_name}    shell=yes
    Process ${result}

Check if ENV variable "${variable_name}" with value "${variable_value}" exists in application "${application_name}"
    ${result_env} =  Run Process    resin envs -a ${application_name} --verbose | sed '/ID[[:space:]]*NAME[[:space:]]*VALUE/,$!d'    shell=yes
    Process ${result_env}
    ${result} =  Run Process    echo "${result_env.stdout}" | grep ${variable_name} | grep " ${variable_value}"    shell=yes
    Process ${result}

Remove ENV variable "${variable_name}" from application "${application_name}"
    ${result_vars} =  Run Process    resin envs -a ${application_name} --verbose | sed '/ID[[:space:]]*NAME[[:space:]]*VALUE/,$!d'   shell=yes
    Process ${result_vars}
    ${result_id} =  Run Process    echo "${result_vars.stdout}" | grep ${variable_name} | cut -d ' ' -f 1    shell=yes
    Process ${result_id}
    ${result} =  Run Process    resin env rm ${result_id.stdout} --yes     shell=yes
    Process ${result}

"${item}" public URL for device "${device_uuid}"
    [Documentation]    Available items for argument ${item} are:
    ...                enable, disable, status, get
    @{list} =  Create List    enable    disable    status    get
    Should Contain    ${list}    ${item}
    ${result} =  Run Keyword If    '${item}' == 'get'    Run Process    resin device public-url ${device_uuid}    shell=yes
    ...    ELSE
    ...    Run Process    resin device public-url ${item} ${device_uuid}    shell=yes
    Process ${result}
    [Return]    ${result.stdout}

Check if resin sync works on "${device_uuid}"
    ${random} =  Evaluate    random.randint(0, sys.maxint)    modules=random, sys
    Git clone "${application_repo}" "/tmp/${random}"
    Git checkout "${application_commit}" "/tmp/${random}"
    Add console output "Hello Resin Sync!" to "/tmp/${random}"
    ${result} =  Run Buffered Process    resin sync ${device_uuid} -s . -d /usr/src/app    shell=yes    cwd=/tmp/${random}
    Process ${result}
    Should Contain    ${result.stdout}    resin sync completed successfully!
    Wait Until Keyword Succeeds    30x    10s    Device "${device_uuid}" log should contain "Hello Resin Sync!"
    [Teardown]    Run Keyword    Remove Directory    /tmp/${random}    recursive=True

Check if setting environment variables works on "${application_name}"
    ${random} =   Evaluate    random.randint(0, 10000)    modules=random
    Add ENV variable "autohat${random}" with value "RandomValue" to application "${application_name}"
    Check if ENV variable "autohat${random}" with value "RandomValue" exists in application "${application_name}"
    Remove ENV variable "autohat${random}" from application "${application_name}"

Check enabling supervisor delta on "${application_name}"
    Add ENV variable "RESIN_SUPERVISOR_DELTA" with value "1" to application "${application_name}"
    Device "${device_uuid}" log should not contain "Killing application"
    ${random} =  Evaluate    random.randint(0, sys.maxint)    modules=random, sys
    Git clone "${application_repo}" "/tmp/${random}"
    Git checkout "${application_commit}" "/tmp/${random}"
    Add console output "Grettings World!" to "/tmp/${random}"
    ${last_commit} =    Get the last git commit from "/tmp/${random}"
    Git checkout "${last_commit}" "/tmp/${random}"
    Git push "/tmp/${random}" to application "${application_name}"
    Wait Until Keyword Succeeds    30x    10s    Device "${device_uuid}" log should contain "Grettings World!"
    Check if ENV variable "RESIN_SUPERVISOR_DELTA" with value "1" exists in application "${application_name}"
    Remove ENV variable "RESIN_SUPERVISOR_DELTA" from application "${application_name}"
    [Teardown]    Run Keyword    Remove Directory    /tmp/${random}    recursive=True

Add console output "${message}" to "${directory}"
    ${result} =  Run Process    git config --global user.email "%{email}"    shell=yes    cwd=${directory}
    Process ${result}
    ${result} =  Run Process    sed -ie 's/Hello World!/${message}/g' start.sh    shell=yes    cwd=${directory}
    Process ${result}
    ${result} =  Run Process    git add .    shell=yes    cwd=${directory}
    Process ${result}
    ${result} =  Run Process    git commit -m "Console message added: ${message}"    shell=yes    cwd=${directory}
    Process ${result}

Get the last git commit from "${directory}"
    ${result} =  Run Buffered Process    git log | grep commit | head -1 | cut -d ' ' -f 2    shell=yes    cwd=${directory}
    Process ${result}
    [Return]    ${result.stdout}

Check that "${device_uuid}" does not return "${interface}" IP address through API using socket "${socket}"
    ${ip_address} =    Get "${interface}" IP address using socket "${socket}"
    ${ip_address_device} =    Get "IP ADDRESS" of device "${device_uuid}"
    Should Not Contain    ${ip_address_device}    ${ip_address}    msg=Device ${device_uuid} is returning the ${interface} IP address

Shutdown resin device "${device_uuid}"
    ${result} =  Run Buffered Process    resin device shutdown ${device_uuid}    shell=yes
    Process ${result}

Run Buffered Process
    [Arguments]    ${command}    ${shell}    ${cwd}=${EXECDIR}    ${timeout}=30min
    ${random} =  Evaluate    random.randint(0, sys.maxint)    modules=random, sys
    ${result} =  Run Process    ${command}    shell=${shell}    cwd=${cwd}    timeout=${timeout}    stdout=/tmp/autohat.${random}.stdout    stderr=/tmp/autohat.${random}.stderr
    [Return]    ${result}

Process ${result}
    Log   all output: ${result.stdout}
    Log   all output: ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0    msg="Command exited with error: ${result.stderr}"    values=False
