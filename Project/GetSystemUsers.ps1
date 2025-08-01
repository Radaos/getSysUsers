# This PowerShell script generates a report of system usage by querying user sessions on specified systems.
# It processes systems defined as offline (development) or online (live), and writes the report as .txt or .html.
# Author: Robert Drohan
# Copyright: Copyright 2025, Robert Drohan
# License: GPLv3
# Version: 1.1
# Status: Release

[CmdletBinding()]
param(
    # Hashtable of offline systems with their alternate titles
    [Parameter(Mandatory = $false)]
    [hashtable]$offline_sys,

    # Hashtable of online systems with their alternate titles
    [Parameter(Mandatory = $false)]
    [hashtable]$online_sys,

    # Output file path where the system usage report will be saved
    [Parameter(Mandatory = $false)]
    [string]$OutFile
)

Add-Type -AssemblyName System.Web

if ($args.Count -gt 0) {
    Write-Error "This script does not accept positional arguments. Please use named parameters."
    exit 1
}

#Start-Transcript -Path "C:\temp\getSysUsersLog.txt" -Append

# Read system definitions and output file from CSV if not provided as parameters
if (-not $offline_sys -or -not $online_sys -or -not $OutFile) {
    $csvPath = Join-Path $PSScriptRoot 'systems.csv'
    if (-not (Test-Path $csvPath)) {
        Write-Error "CSV file with system definitions not found: $csvPath"
        exit 1
    }
    $systems = Import-Csv -Path $csvPath

    # Extract OutFile from the config row
    if (-not $OutFile) {
        $configRow = $systems | Where-Object { $_.Type -eq 'config' -and $_.SystemName -eq 'OutFile' }
        if ($configRow) {
            $OutFile = $configRow.AltTitle
        } else {
            Write-Error "Output file path (OutFile) not found in CSV file. Please add a config row with SystemName=OutFile."
            exit 1
        }
    }

    if (-not $offline_sys) {
        $offline_sys = [ordered]@{}
        foreach ($row in $systems | Where-Object { $_.Type -eq 'offline' }) {
            $offline_sys[$row.SystemName] = $row.AltTitle
        }
    }
    if (-not $online_sys) {
        $online_sys = [ordered]@{}
        foreach ($row in $systems | Where-Object { $_.Type -eq 'online' }) {
            $online_sys[$row.SystemName] = $row.AltTitle
        }
    }
}

# Function to process a single system and retrieve user session details
function ProcessMachine {
    param(
        # Name of the system to query
        [string]$DeviceName,
        # Alternate title for the system
        [string]$DevTitle
    )

    # Initialize variables for session data and multi-user status
    $SessionData = ""
    $MultiUser = ""

    # Append the alternate title to the system name if provided
    if ($DevTitle) {
        $DevTitle = "/ $DevTitle"
    }

    try {
        # Query the system for user session information using the 'quser' command
        Write-Output "Querying: $DeviceName"
        $SessionQuery = quser /server:$DeviceName

        # Split the query output into lines and count them
        $Lines = $SessionQuery -split "`n"
        $LineCount = $Lines.Count

        # Check if the system has multiple users logged in
        if ($LineCount -gt 2) {
            $MultiUser = "*Multiple Logins*"
        }

        # If there are user sessions, extract the session data
        if ($LineCount -gt 1) {
            $SessionData = $Lines[1..($LineCount - 1)] -join "`n"
            #$SessionData = ParseIdle -SessData $SessionData
        }

        # Log off any disconnected users at specific times (works for admins only)
        if ($false) {
            $Hour = (Get-Date).Hour
            if ($Hour -eq 23 -or $Hour -eq 7) {
                # Find disconnected users and log them off
                $DisconnectedUsers = $SessionQuery | Select-String -Pattern 'Disc'
                foreach ($User in $DisconnectedUsers) {
                    $SessionID = ($User -split '\s+')[1]
                    logoff $SessionID /server:$DeviceName
                }
            }
        }

    } catch {
        # Handle errors during the query and record the system users as Unknown
        Write-Output "Error querying $DeviceName"
        $SessionData = " Unknown"
    }

    # If no session data is found, record the system as having no users.
    if (-not $SessionData) {
        $SessionData = " No User"
    }

    # Return the processed data as a hashtable
    return @{
        DeviceName = $DeviceName
        DevTitle = $DevTitle
        MultiUser = $MultiUser
        SessionData = $SessionData
    }
}

function ParseIdle {
    param(
        [string] $SessData
    )

    # Split the session data into lines
    $Lines = $SessData -split "`n"
    $UpdatedLines = @()

    try {
        foreach ($Line in $Lines) {
            # Extract the Idle Time (5th column)
            $Columns = $Line -split '\s{2,}'
            if ($Columns.Count -ge 5) {
                $IdleTime = $Columns[4]

                # If Idle Time is greater than 28 days, report it as invalid.
                if ($IdleTime -match '(\d+)\+.*') {
                    $Days = [int]$Matches[1]
                    if ($Days -gt 28) {
                        $Columns[4] = "?"
                    }
                }

            # Reconstruct the line with updated column spacing
			# USERNAME, SESSIONNAME, ID, STATE, IDLE_TIME, LOGON_TIME
            $UpdatedLine = $Columns[0] +
                (" " * (24 - $Columns[0].Length)) + $Columns[1] +
                (" " * (20 - $Columns[1].Length)) + $Columns[2] +
                (" " * (3 - $Columns[2].Length)) + $Columns[3] +
                (" " * (12 - $Columns[3].Length)) + $Columns[4] +
                (" " * (7 - $Columns[4].Length)) + $Columns[5]

            $UpdatedLines += $UpdatedLine
            }
             else {
                # If the line doesn't have enough columns, keep it as is
                $UpdatedLines += $Line
            }
        }

    }
    catch {    
        Write-Output "Session parsing error"
        $UpdatedLines += $Line + " ."
    }


    # Return the updated session data
    return $UpdatedLines -join "`n"
}

# Function to generate a report for a list of systems
function GenerateReport {
    param(
        # Hashtable of systems to process
        [hashtable]$Systems
    )

    $Report = ""

    # Iterate through each system and process it
    $Systems.GetEnumerator() | Sort-Object Value | ForEach-Object {
        $Result = ProcessMachine -DeviceName $_.Key -DevTitle $_.Value

        # Append the processed data to the report
        $Report += "`n$($Result.DeviceName) $($Result.DevTitle) $($Result.MultiUser)`n"
        $Report += "$($Result.SessionData)`n"
    }
    return $Report
}

# Main body of program
function Main {
    # Get the current timestamp, hostname, and username for the report header
    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $ScriptHostName = [System.Net.Dns]::GetHostName()
    $ScriptUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]

    # Create the report header
    $Header = @"
SYSTEM USAGE:   $TimeStamp
SCRIPT RUN:     $ScriptUserName on $ScriptHostName

 USERNAME              SESSIONNAME        ID  STATE   IDLE_TIME  LOGON_TIME
`nOffline ---------------------------------------------------------------------------`n
"@

    # Generate reports for offline and online systems
    $OfflineReport = GenerateReport -Systems $offline_sys
    $OnlineReport = GenerateReport -Systems $online_sys

    # Create the report footer
    $Footer = @"
___________________________________________________________________________________`n
"@

    # Combine the header, reports, and footer into the full report
    $FullReport = $Header + $OfflineReport + "`nTesters ---------------------------------------------------------------------------`n" + $OnlineReport + $Footer

    # Write the full report to the output file
    #    | Out-File -FilePath $OutFile

    $HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>System Usage Report</title>
<style>
    body { font-family: Consolas, monospace; font-size: 16px; margin: 20px; }
    h1, h2 { color: #2c3e50; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    .section-title { margin-top: 30px; font-size: 1.2em; color: #34495e; }
    .footer { margin-top: 40px; font-size: 0.9em; color: #888; }
    pre { font-family: inherit; font-size: inherit; }
</style>
</head>
<body>
"@

    $HtmlBody = "<h1>System Usage Report</h1>"
    $HtmlBody += "<pre>"
    $HtmlBody += [System.Web.HttpUtility]::HtmlEncode($FullReport)
    $HtmlBody += "</pre>"
    $HtmlContent = $HtmlHeader + $HtmlBody + $HtmlFooter
    $HtmlContent | Out-File -FilePath $OutFile -Encoding UTF8
}

Main
#Stop-Transcript

