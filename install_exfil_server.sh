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
    false
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

##################
# End: Functions #
##################

echo "#########################################"
echo "### Installing Exfil Dedicated Server "
echo "#########################################"

fn_quit_if_not_admin

echo "##############################"
echo "### Collecting Information "
echo "##############################"

fn_get_required_user_input "Username for Server (username to install server under)?:" exfil_user "Username for Server is required. Please provide one!"

exfil_user_home=/home/${exfil_user}

if fn_user_exists ${exfil_user};
then
  echo "### User ${exfil_user} exists, continuing"
else
  echo "### User ${exfil_user} does exist, going to create it"
  echo "### Creating User " ${exfil_user}
  sudo useradd -m ${exfil_user}

  echo "### Setting Password for " ${exfil_user}
  passwd ${exfil_user}
fi

fn_get_required_user_input "Steam Username?:" steam_user_name "Steam Username is required. Please provide one!"
fn_get_required_user_input "Steam User Password?:" steam_user_password "Steam User Password is required. Please provide one!"
fn_get_required_user_input "Server Name (shown in server browser)?:" server_name "Server Name is required. Please provide one!"
fn_get_user_input "Server Port (default: 27015)?:" server_port 27015
fn_get_user_input "Server Query Port (default: 7777)?:" query_port 7777
fn_get_user_input "Exfil Service Name (default: exfil)?:" exfil_service_name exfil

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

echo "#####################################################################"
echo "### Downloading and installing Exfil Server on user ${exfil_user} "
echo "#####################################################################"

cd ${exfil_user_home}
sudo -u ${exfil_user} /usr/games/steamcmd +force_install_dir ${exfil_user_home}/exfil-dedicated +login ${steam_user_name} ${steam_user_password} +app_update 3093190 +quit
sudo -u ${exfil_user} mkdir -p ${exfil_user_home}/.steam/sdk64
sudo -u ${exfil_user} cp -f ${exfil_user_home}/.steam/steam/steamcmd/linux64/steamclient.so ${exfil_user_home}/.steam/sdk64/steamclient.so
timeout 5s sudo -u ${exfil_user} ${exfil_user_home}/exfil-dedicated/ExfilServer.sh
echo "##############################"
echo "### Creating Config Files: "
echo "##############################"

sudo -u ${exfil_user} echo "vi ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/DedicatedSettings.JSON" > ${exfil_user_home}/edit_server_settings_config && chmod +x ${exfil_user_home}/edit_server_settings_config
sudo -u ${exfil_user} echo "vi ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/ServerSettings.JSON" > ${exfil_user_home}/edit_admin_settings_config && chmod +x ${exfil_user_home}/edit_admin_settings_config
sudo -u ${exfil_user} echo "/usr/games/steamcmd +force_install_dir ${exfil_user_home}/exfil-dedicated +login ${steam_user_name} '${steam_user_password}' +app_update 3093190 +quit && ${exfil_user_home}/exfil-dedicated/ExfilServer.sh -port=${server_port} -QueryPort=${query_port}"  > ${exfil_user_home}/start_exfil_service && chmod +x ${exfil_user_home}/start_exfil_service

chown -R ${exfil_user}:${exfil_user} /home/${exfil_user}


cat <<EOF > ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/DedicatedSettings.JSON
{
    "admin": {
        "76561197972138706": "Misultin",
        "76561198013561063": "Irontaxi",
        "76561198001845029": "Loki",
    },
  "AutoStartTimer": 0,
  "MinAutoStartPlayers": "2",
  "AddAutoStartTimeOnPlayerJoin": 20
}
EOF

cat <<EOF > ${exfil_user_home}/exfil-dedicated/Exfil/Saved/ServerSettings/ServerSettings.JSON
{
    "ServerName": "${server_name}",
    "MaxPlayerCount": "32"
}
EOF


echo "###Building Serice Start Script: "
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

echo "########################"
echo "### Install Complete "
echo "########################"
echo "######################################################"
echo "### Edit your configs:                             "
echo "### ${exfil_user_home}/edit_server_settings_config "
echo "### ${exfil_user_home}/edit_admin_settings_config   "
echo "######################################################"
echo "############################################"
echo "### Start Server:                        "
echo "### systemctl start exfil                "
echo "### Check Status:                        "
echo "### systemctl status exfil               "
echo "### enable start on boot                 "
echo "### systemctl enable exfil               "
echo "### view logs:                           "
echo "### journalctl -u exfil.service -b -e -f "
echo "### stop server:                         "
echo "### systemctl stop exfil                 "
echo "############################################"
