#! /bin/bash
#
#	Wifi Tool init script
#		v1.0
#	Author Aaron - Team 404


								#Set target file
absolutetarget="/etc/rc.local"
targetfile=$(echo $absolutetarget | awk 'BEGIN { FS = "/" } ; { print $NF }')
targetdir=$(echo $absolutetarget | awk 'BEGIN {FS = "/"} ; {$NF--;print}')
echo $absolutetarget
echo $targetfile
echo $targetdir

	
								#Banner and instructions
echo "###################################"
echo "#Team 404 Wifi Analitics tool Init#"
echo "###################################"
echo ""
echo "This file must be run as root and must be only run once.
If you need to rerun for whatever reason, first run the init-wiper.sh script first and then rerun this."
echo ""

								#get which repo we want to add to the rc.local file
echo -e '\nEnter github branch url' 
echo '(e.g. https://github.com/UTS-Team-404/Init-Script-Prototype.git):'
read githuburl

								#grab the repo file name for later
repo=$(echo $githuburl | awk 'BEGIN { FS = "/" } ; { print $NF }' | cut -d "." -f1)
echo Repo name found: $repo

								#Read file to be executed incase its different
echo -e '\nWhat is the file to run on startup?'
read startfile

								#This will make an identifier for where our added lines go incase we need to delete them again.
echo ""
echo "###################################" >> $absolutetarget
echo "#Team 404 Wifi Analitics tool Init#" >> $absolutetarget
echo "###################################" >> $absolutetarget

								#This will add a line that updates from the github branch each time the device turns on.
								#We could make it only pull if it detects cahnges if this adds too much time to the startup.
echo -e '\n--> writing git -c $targetdir clone $githuburl to $absolutetarget'
echo "git -c $targetdir clone $githuburl" >> $absolutetarget

								#This will add a line that runs the file on startup
echo "--> writing .$targetdir$repo/$startfile to $absolutetarget"
startfiledir=$(echo "./$targetdir/$repo/$startfile")
echo ${startfiledir// /} >> $absolutetarget
