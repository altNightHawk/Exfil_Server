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
echo "#########################################"
echo "### Installing Exfil Dedicated Server "
echo "#########################################"

if [ $(id -u) -ne 0 ]
then
  echo "Please run this script as root or using sudo!"
  exit
fi

echo "##############################"
echo "### Collecting Information "
echo "##############################"

echo -n "Steam Username? "
read steam_user_name

echo -n "Steam User Password? "
read steam_user_password

echo -n "Username for Server(username to install server under)? "
read exfil_user
exfil_user_home=/home/${exfil_user}

echo -n "Server Name(name your server shows as in host list)? "
read server_name

echo -n "Server Port(default 27015)? "
read server_port

echo -n "Query Port(default 7777)? "
read query_port

echo -n "Exfil Service Name (default exfil)? "
read exfil_service_name

echo "###Creating User " ${exfil_user}
sudo useradd -m ${exfil_user}

echo "###Setting Password for " ${exfil_user}
passwd ${exfil_user}

echo "#########################################"
echo "### Downloading & Installing steamcmd "
echo "#########################################"

sudo add-apt-repository multiverse; sudo dpkg --add-architecture i386; sudo apt update
sudo apt install steamcmd

echo "##########################"
echo "### steamcmd installed "
echo "##########################"

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
