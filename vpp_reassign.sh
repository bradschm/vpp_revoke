#!/bin/bash


###################################################################################
### Revoke VPP and allow for new Apple ID to accpet invite from a list of users ###
### Authored by Brad Schmidt on February 10, 2015 							              	###
###################################################################################

###################################################################################################################
### What this script solves:
### If a user wishes to associate their username with a different Apple ID you are required to remove the following:
### Device Assignments
### VPP App Assignments
### The user account
### Then you can recreate the account and a new invitation can be sent and they can setup VPP with a different Apple ID
### This script will remove the user from the devices and assignments and reassign them
###################################################################################################################

###################################################################################################################
### REQUIREMENTS															                                	
### Casper
### Static User Group set to an exclusion target on your VPP Assignment(s)
### xml2 - used for xml parsing takes xml input and outputs to a path
### For example - <computer><user>username</user></computer> turns into
### /computer/user=username
### xml2 Website: http://www.ofb.net/~egnor/xml2/
### How to obtain: 
### Linux: sudo apt-get install xml2
### Mac using Mac brew: brew install xml2
### If you don't have Homebrew on your Mac, check out: http://brew.sh
### Quickest way to get Homebrew setup on your Mac: 
### Run this in terminal: ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
####################################################################################################################

####################################################################################################################
### Note: This script uses files but eventually I would like to use arrays. The files will be created in whatever path
### you run the script from. You may want to hardcode these values in your environment.
### Users should be added the users.txt file that you want to send a new invitation to.
####################################################################################################################
# Please set these variables
# JSS Credentials
un=username
pw=password
# JSS URL
jssurl='https://jss.com:8443'
# Smart Group ID that is excluded from App Assignments - Get ID by viewing the group in the JSS
vppexclusion_group_id="11"

# Get list of users from users.txt
# Iterate through to remove users from devices, add to revoking user group, delete the user, and add back to existing device
while read line
	do 
		/usr/bin/curl -k -u $un:$pw $jssurl/JSSResource/users/name/$line > users.xml
		#get user id
		id=`xml2 < users.xml | /usr/bin/grep '/user/id=' | /usr/bin/cut -d '=' -f2`
		# Get username
		username=$line
		# Add to user group to revoke vpp assignment
		/usr/bin/curl -k -u $un:$pw -H "Content-Type: application/xml" -d "<user_group><users><user><id>$id</id></user></users></user_group>" -X PUT $jssurl/JSSResource/usergroups/id/$vppexclusion_group_id
		# Getting list of mobile devices
		xml2 < users.xml | /usr/bin/grep '/user/links/mobile_devices/mobile_device/id=' | cut -d '=' -f2 > usermobiledevices.txt
		# Getting list of computers
		xml2 < users.xml | /usr/bin/grep '/user/links/computers/computer/id=' | /usr/bin/cut -d '=' -f2 > usercomputers.txt
			
			# Delete user from mobile devices
			while read line
				do
					mdid=$line
					/usr/bin/curl -k -u $un:$pw -H "Content-Type: application/xml" -d "<mobile_device><location><username></username></location></mobile_device>" -X PUT $jssurl/JSSResource/mobiledevices/id/$mdid;
				done < usermobiledevices.txt

			# Delete user from computers
			while read line
				do
					computerid=$line
					/usr/bin/curl -k -u $un:$pw -H "Content-Type: application/xml" -d "<computer><location><username></username></location></computer>" -X PUT $jssurl/JSSResource/computers/id/$computerid;
				done < usercomputers.txt

		# Step to delete user
		/usr/bin/curl -k -u $un:$pw -X DELETE $jssurl/JSSResource/users/id/$id;

			# Readd user to mobile devices
			while read line
				do
					mdid=$line
					/usr/bin/curl -k -u $un:$pw -H "Content-Type: application/xml" -d "<mobile_device><location><username>$username</username></location></mobile_device>" -X PUT $jssurl/JSSResource/mobiledevices/id/$mdid
done < usermobiledevices.txt

			# Readd user to computers
			while read line
				do
					computerid=$line
					/usr/bin/curl -k -u $un:$pw -H "Content-Type: application/xml" -d "<computer><location><username>$username</username></location></computer>" -X PUT $jssurl/JSSResource/computers/id/$computerid;
				done < usercomputers.txt

	done < users.txt

# Clean up time
/bin/echo "Put users here" > users.txt
/bin/rm usercomputers.txt usermobiledevices.txt users.xml

exit 0

