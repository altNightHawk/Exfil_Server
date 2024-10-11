#!/bin/bash
###################################
### Exfil Server Install Script ###
###################################

###Need to add a check to determine if steamcmd is already installed

##############
###Configs####
##############
###DO NOT CHANGE####
steam_app_id=3093190
###DO NOT CHANGE####
#################
###End Configs###
#################

####################
# Start: Functions #
####################

fn_user_exists() {
  if id "$1" >/dev/null 2>&1;
  then
    true
  else
    falsels
  fi
}

fn_quit_if_not_admin() {
  if [ $(id -u) -ne 0 ]
  then
    echo "Please run this script as root or using sudo!"
    exit -1
  fi
}

fn_is_installed() {
  aptOutput=$(apt -qq --installed list ${1} 2>/dev/null | grep -oP '\[installed\]$')

  if [ "${aptOutput}" = "[installed]" ]; then
    true
  else
    false
  fi
}

fn_get_user_input() {
    # $1 = prompt
    # $2 = variable name to set
    # $3 = optional default value

    echo -n "${1} "
    read l_user_input


    if [ -n "${3}" ] && [ -z "${l_user_input}" ]; then
      l_user_input=$3
    fi

    export "${2}=${l_user_input}"
}

fn_get_required_user_input() {
    # $1 = prompt
    # $2 = variable name to set
    # $3 = required message

    counter=0;
    while [ $counter -eq 0 ]
    do
      echo -n "${1} "
      read l_user_input

      if [ -n "${3}" ] && [ -z "${l_user_input}" ]; then
        >&2 echo $3
        continue
      fi

      export "${2}=${l_user_input}"
      break
    done
}

fn_get_home_dir() {
  getent passwd $1 | cut -d: -f6
}

function fn_set_json_config_value {
  local key=$1
  local value=$2
  local config=$3

  local jq_args=('--arg' 'value' "${value}" "${key} = \$value" "${config}" )
  echo $(jq "${jq_args[@]}") > $config
}

fn_ask() {
  # $1 = prompt
  # $2 = optional default value

  echo -n "${1} "
  read l_user_input

  if [ "${l_user_input}" = "y" ] || [ "${l_user_input}" = "yes" ] ; then
    true
  else
    if [ -n "${2}" ] && [ -z "${l_user_input}" ]; then
      $2
    else
      false
    fi
  fi
}

##################
# End: Functions #
##################

echo "#########################################"
echo "### Installing Exfil Dedicated Server "
echo "#########################################"

fn_quit_if_not_admin

if [ -n "${1}" ]; then
  if [ ! -f ${1} ]; then
    >&2 echo ".env file '${1}' was not found."
    exit -1
  fi

  echo "Including variables from: ${1}"
  . $1
fi


echo "##############################"
echo "### Collecting Information "
echo "##############################"

[ -n "${exfil_user}" ] || fn_get_required_user_input "Username for Server (username to install server under)?:" exfil_user "Username for Server is required. Please provide one!"

if fn_user_exists ${exfil_user};
then
  echo "### User ${exfil_user} exists, continuing"
else
  echo "### User ${exfil_user} does exist, going to create it"
  echo "### Creating User " ${exfil_user}
  sudo useradd -m ${exfil_user}

  echo "### NOTICE: Password has not been set for ${exfil_user}, please create one if your system requires it."
fi

[ -n "${steam_user_name}" ] || fn_get_required_user_input "Steam Username?:" steam_user_name "Steam Username is required. Please provide one!"
[ -n "${steam_user_password}" ] || fn_get_required_user_input "Steam User Password?:" steam_user_password "Steam User Password is required. Please provide one!"
[ -n "${server_name}" ] || fn_get_required_user_input "Server Name (shown in server browser)?:" server_name "Server Name is required. Please provide one!"
[ -n "${server_password}" ] || fn_get_user_input "Server password (optional, default: none)?:" server_password
[ -n "${server_max_players}" ] || fn_get_user_input "Max. players on server (optional, default: 32)?:" server_max_players 32
[ -n "${server_port}" ] || fn_get_user_input "Server Port (optional, default: 7777)?:" server_port 7777
[ -n "${query_port}" ] || fn_get_user_input "Server Query Port (optional, default: 27015)?:" query_port 27015
[ -n "${server_admin_list}" ] || fn_get_user_input "Additional Server Admins (optional, default: none, format: SteamID1=Name1;SteamID2=Name;SteamID3=Name3)?:" server_admin_list


if fn_is_installed steamcmd;
then
  echo "### SteamCmd is already installed"
else
  echo "#########################################"
  echo "### Downloading & Installing steamcmd "
  echo "#########################################"

  sudo add-apt-repository multiverse; sudo dpkg --add-architecture i386; sudo apt update
  sudo apt install steamcmd

  echo "##########################"
  echo "### steamcmd installed "
  echo "##########################"
fi

if fn_is_installed jq;
then
  echo "### jq is already installed"
else
  echo "#########################################"
  echo "### Downloading & Installing jq "
  echo "#########################################"

  sudo apt update
  sudo apt-get install jq

  echo "##########################"
  echo "### jq installed "
  echo "##########################"
fi

echo "#####################################################################"
echo "### Downloading and installing Exfil Server on user ${exfil_user} "
echo "#####################################################################"

exfil_user_home=$(fn_get_home_dir ${exfil_user})
cd ${exfil_user_home}
sudo -u ${exfil_user} /usr/games/steamcmd +force_install_dir ${exfil_user_home}/exfil-dedicated +login ${steam_user_name} ${steam_user_password} +app_update ${steam_app_id} +quit
sudo -u ${exfil_user} mkdir -p ${exfil_user_home}/.steam/sdk64
sudo -u ${exfil_user} ln -s  ${exfil_user_home}/.local/share/Steam/steamcmd/linux64/steamclient.so ${exfil_user_home}/.steam/sdk64/steamclient.so

echo "##############################"
echo "### Creating Config Files: "
echo "##############################"

mkdir -p "${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings"
sudo -u ${exfil_user} echo "vi ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/DedicatedSettings.JSON" > ${exfil_user_home}/edit_server_settings_config && chmod +x ${exfil_user_home}/edit_server_settings_config
sudo -u ${exfil_user} echo "vi ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/ServerSettings.JSON" > ${exfil_user_home}/edit_admin_settings_config && chmod +x ${exfil_user_home}/edit_admin_settings_config
sudo -u ${exfil_user} echo "/usr/games/steamcmd +force_install_dir ${exfil_user_home}/exfil-dedicated +login ${steam_user_name} '${steam_user_password}' +app_update ${steam_app_id} +quit && ${exfil_user_home}/exfil-dedicated/ExfilServer.sh -port=${server_port} -QueryPort=${query_port}"  > ${exfil_user_home}/start_exfil_service && chmod +x ${exfil_user_home}/start_exfil_service

SERVER_SETTINGS_FILE=${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/ServerSettings.JSON
cat <<EOF > $SERVER_SETTINGS_FILE
{
  "admin": {
      "76561197972138706": "Misultin",
      "76561198013561063": "Irontaxi",
      "76561198001845029": "Loki"
  },
  "AutoStartTimer": 0,
  "MinAutoStartPlayers": "2",
  "AddAutoStartTimeOnPlayerJoin": 20
}
EOF

if [ -n "${server_admin_list}" ]; then
  IFS=';' read -ra server_admins <<< "${server_admin_list}"

  for server_admin in "${server_admins[@]}"
  do
      admin_steam_id="${server_admin%=*}"
      admin_name="${server_admin#*=}"
      printf "\t> Adding '${admin_name}' with steam id '${admin_steam_id}' to admins\n"
      fn_set_json_config_value ".admin.\"${admin_steam_id}\"" "${admin_name}" "${SERVER_SETTINGS_FILE}"
  done
fi

# settings here will be overriden later
DEDICATED_SETTINGS_FILE=${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/DedicatedSettings.JSON
cat <<EOF > $DEDICATED_SETTINGS_FILE
{
    "ServerName": "New Server",
    "MaxPlayerCount": "32"
}
EOF

# set the properties using jq to avoid escape problems
fn_set_json_config_value '.ServerName' "${server_name}" "${DEDICATED_SETTINGS_FILE}"
fn_set_json_config_value '.MaxPlayerCount' "${server_max_players}" "${DEDICATED_SETTINGS_FILE}"
fn_set_json_config_value '.ServerPassword' "${server_password}" "${DEDICATED_SETTINGS_FILE}"

chown -R ${exfil_user}:${exfil_user} /home/${exfil_user}

echo "######################################################"
echo "### Edit your configs:                             "
echo "### ${exfil_user_home}/edit_server_settings_config "
echo "### ${exfil_user_home}/edit_admin_settings_config   "
echo "######################################################"


if [ "${exfil_service_skip}" !=  "1" ] && [ "${exfil_service_skip}" != "true" ];
then
  if [ -n "${exfil_service_name}" ] || fn_ask "Do you want to setup a service?  ([y]es, [n]o)?:";
  then
    [ -n "${exfil_service_name}" ] || fn_get_user_input "Exfil Service Name (default: exfil)?:" exfil_service_name exfil
    echo "###Building Service Start Script: "
cat <<EOF > /etc/systemd/system/${exfil_service_name}.service
        [Unit]
        Description=Exfil dedicated server
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=5
        User=${exfil_user}
        ExecStart=/bin/bash ${exfil_user_home}/start_exfil_service

        [Install]
        WantedBy=multi-user.target

EOF

if [ -n "${exfil_cron}" ] || fn_ask "Do you want to a cron to update the server?  ([y]es, [n]o)?:";
  then
    echo "###Building Update Cron: "
cat <<EOF > /etc/cron.hourly/exfil_${exfil_user}_version_check
#!/bin/bash
##############
###Configs####
##############
steam_user_name=${steam_user_name}
steam_user_password=${steam_user_password}
steam_app_id=${steam_app_id}
exfil_user=${exfil_user}
exfil_service_name=${exfil_service_name}.service
#################
###End Configs###
#################

local_buildid=\$(grep -oP  'buildid.+?"\K[0-9]+' /home/\${exfil_user}/exfil-dedicated/steamapps/appmanifest_\${steam_app_id}.acf)
echo "Local Build: " \$local_buildid

remote_buildid=\$(steamcmd +login \${steam_user_name} \${steam_user_password} +app_info_update 1 +app_info_print \${steam_app_id} +quit | grep -oPz '(?s)"branchs"\s+{\s+"public"\s+{\s+"buildid"\s+"\d+"' | grep -aoP  'buildid.+?"\K[0-9]+')
echo "Remote Build: " \$remote_buildid

if [ "\${remote_buildid}" = "\${local_buildid}" ]; then
  echo "Exfil (\${steam_app_id}) is up to date"
else
  echo "Exfil (\${steam_app_id}) is not up to date."
  echo "Going to restart ExfilServer process"
  systemctl restart \${exfil_service_name}
fi

EOF

echo "########################"
echo "### Cron installed at: "
echo "### /etc/cron.hourly/exfil_${exfil_user}_version_check "
echo "########################"
fi

    echo "############################################"
    echo "### Start Server:                        "
    echo "### systemctl start ${exfil_service_name}"
    echo "### Check Status:                        "
    echo "### systemctl status ${exfil_service_name}"
    echo "### enable start on boot                 "
    echo "### systemctl enable ${exfil_service_name}"
    echo "### view logs:                           "
    echo "### journalctl -u ${exfil_service_name}.service -b -e -f "
    echo "### stop server:                         "
    echo "### systemctl stop ${exfil_service_name} "
    echo "############################################"
  else
    echo "############################################"
    echo "### Start Server:                           "
    echo "### ./${exfil_user_home}/start_exfil_service"
    echo "############################################"
  fi
else
  echo "############################################"
  echo "### Start Server:                           "
  echo "### .${exfil_user_home}/start_exfil_service"
  echo "############################################"
fi

echo "########################"
echo "### Install Complete "
echo "########################"
