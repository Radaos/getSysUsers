# getSysUsers
List who is logged into specified Windows machines.
This PowerShell script accepts an array of system network names and a hashtable of alternate system names as parameters.
It defines an output file where the system usage status will be written.
It adds header information to the output, including the timestamp and the details of the script run.
For each system in the list, it retrieves the details of user sessions using the quser command.
If a system has multiple users logged in, it notes this in the output.
At a specified time, it finds any users who are still logged in but disconnected and logs them off.
If quser cannot find users on a system, or if no logins are reported, the system is added to the list of free systems.
Generates a report or web page with system user details.
