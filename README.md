# getSysUsers
List who is logged into specified Windows machines.\
This PowerShell script reads a set of system network names and alternate (more readable) names from a .csv file.\
It adds header information to the output, including the timestamp and the details of the script run.\
For each system in the list, it retrieves the details of user sessions using the quser command.\
If a system has multiple users logged in, it notes this in the output.\
Generates a .txt report or a web page with system user details.\
