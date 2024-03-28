# This PowerShell script accepts an array of system network names and a hashtable of alternate system names as parameters.
# It defines an output file where the system usage status will be written.
# It adds header information to the output, including the timestamp and the details of the script run.
# For each system in the list, it retrieves the details of user sessions using the quser command.
# If a system has multiple users logged in, it notes this in the output.
# At a specified time, it finds any users who are still logged in but disconnected and logs them off.
# If quser cannot find users on a system, or if no logins are reported, the system is added to the list of free systems.
# Generates a report or web page with system user details.
# Optionally send an email with list of free systems.

# author = Robert Drohan
# version = 1.1
# status = Production


param (
    # Define network names of systems to check.
    [string[]]$SysNetNames = ("SYS1", "SYS2", "SYS3", "SYS4"),

    # Define alternate names where applicable.
    $SysTitle = @{
        "SYS1" = "XWINS1"
        "SYS2" = "XWINS2"
    }
)

process {
    # Define where to write the output. If writing to Linux ~/public_html, output will be accessible from a web browser.
    [string]$OutFile = '\\server\username\public_html\system_status.txt'

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $Hour = Get-Date -Format "HH"
    $ScriptHostName = [System.Net.Dns]::GetHostName()
    $ScriptUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.split("\")[-1]
    $Error.Clear()

    # Add header information to the output.
    $SysInfo = ""
    $SysInfo = -join ($SysInfo, "SYSTEM USAGE:   $TimeStamp`n")
    $SysInfo = -join ($SysInfo, "SCRIPT RUN:     $ScriptUserName on $ScriptHostName`n`n")
    $SysInfo = -join ($SysInfo, "SYS/USERNAME            SESSIONNAME        ID  STATE   IDLE_TIME  LOGON_TIME`n")
    $SysInfo = -join ($SysInfo, "------------------------------------------------------------------------------------`n")

    $FreeSystems = ""
    foreach ($NetworkName in $SysNetNames ) {
        # Set defaults
        $UserStatus = "No Data"
        $MultiUser = ""        
        $SessionData = $null

        # If machine has an alternate title, include it in the output.
        $PCTitle = $SysTitle[$NetworkName]
        if ($PCTitle) {
            $PCTitle = -join ("/ ", $PCTitle )
        }

        try {
            # Get details of user sessions on this system.
            $SessionQuery = quser /server:$NetworkName
            # Find how many users are logged in. Allow for header on first line.
            $LineCount = ($SessionQuery -split "`n").Count

            if ($LineCount -gt 2) {
                # System has multiple users logged in.
                $MultiUser = ("         *Multiple Logins*")
            }

            if ($LineCount -gt 1) {
                # System is in use
                for ($it = 1; $it -lt $Linecount; $it++) {

                    $UserStatus = $SessionQuery  | Select-Object -index $it
                    $UserStatus = $UserStatus.Trim()
                    #$SessionData = $UserStatus
				    $SessionData = -join ($SessionData, $UserStatus, "`n ")
                }
            }


            if ([int]$Hour -eq 23 -or [int]$Hour -eq 7) {                              
                # At specified time, find any users who are still logged in but disconnected & log them off.
                $DisconUsers = $UserStatus | Select-String -Pattern 'Disc' -CaseSensitive -SimpleMatch
                if ($DisconUsers) {
                    #$ZombieUser = ($DisconUsers -split '\s+')[0]
                    $SessionID = ($DisconUsers -split '\s+')[1]           
                    logoff $SessionID /server:$NetworkName
                }
            }
        }
        catch {
            # Add any system where quser finds no users to the list of free systems.
            $SessionData = "No User`n"
            $FreeSystems = -join ($FreeSystems, $NetworkName, $PCTitle, "`n")
        }           

        if ([string]::IsNullOrEmpty($SessionData)) {
            # Add any system with no logins reported to the list of free systems.
            $SessionData = "No User`n"
            $FreeSystems = -join ($FreeSystems, $NetworkName, $PCTitle, "`n")
        }     

        $SysInfo = -join ($SysInfo, "`n", $NetworkName, $PCTitle, $MultiUser, "`n")
        $SysInfo = -join ($SysInfo, " ", $SessionData)
    }

    # Add an end-of -page delimiter and write output to file
    $SysInfo = -join ($SysInfo, "____________________________________________________________________________________")
    $SysInfo | Out-File -FilePath $OutFile

    #if ($FreeSystems) {
    #    # Email user with list of free systems
    #    $ScriptUserEmail = ([ADSI]"LDAP://<SID=$([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)>").UserPrincipalName.ToString()
    #    Send-MailMessage -To $ScriptUserEmail -From $ScriptUserEmail -Subject 'Free Testers' -Body $FreeSystems -SmtpServer 'owa.organisation.com'
    #}

    switch ($Host.Name) {
        # Exit properly if in an IDE.
        ConsoleHost { [Environment]::Exit(0) }
        PrimalScriptHostImplementation {}
        'Windows PowerShell ISE Host' {}
    }
}