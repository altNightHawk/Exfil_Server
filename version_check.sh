#!/bin/bash
##############
###Configs####
##############
steam_user_name=YourSteamUser
steam_user_password=YourSteamPassword
steam_app_id=3093190
####Default exfil_user=steam
exfil_user=YourExfilUser
####Default exfil_service_name=exfil
exfil_service_name=YourExfilService
#################
###End Configs###
#################

local_buildid=$(grep -oP  'buildid.+?"\K[0-9]+' /home/${exfil_user}/exfil-dedicated/steamapps/appmanifest_${steam_app_id}.acf)
echo "Local Build: " $local_buildid

remote_buildid=$(steamcmd +login ${steam_user_name} ${steam_user_password} +app_info_update 1 +app_info_print ${steam_app_id} +quit | grep -oPz '(?s)"branches"\s+{\s+"public"\s+{\s+"buildid"\s+"\d+"' | grep -aoP  'buildid.+?"\K[0-9]+')
echo "Remote Build: " $remote_buildid

if [ "${remote_buildid}" = "${local_buildid}" ]; then
  echo "Exfil (${steam_app_id}) is up to date"
else
  echo "Exfil (${steam_app_id}) is not up to date."
  echo "Going to restart ExfilServer process"
  systemctl restart ${exfil_service_name}
fi
