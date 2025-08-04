# Product Specification Documant

## Project Title: getSysUsers

## Purpose: To collect current system session data on a timed basis. Generate a clean HTML report viewable in a browser, providing a near-real-time snapshot of active and disconnected user sessions.

## Functional Requirements
1. Timed Execution
Script runs every 5 minutes, configured via Windows Task Scheduler.
No GUI or interactive input; all logic is contained in the script

2. Data Collection
Uses native PowerShell features and Windows commands (quser) to retrieve session details:
Logged-in users
Session ID, state, and type (console or RDP)
Logon time and idle time

3. HTML Report Output
Script generates an HTML page each run, overwriting previous output. 
Page contains timestamp, session data table, and basic styling. 
Report is stored locally (e.g., C:\inetpub\getSysUsers\session.html) or hosted for intranet access. 

## Design Specifications
File Structure
File: Purpose
GetSystemUsers.ps1:	Main script
session.html:	Generated HTML report
TaskScheduler.xml: (optional)	Task import definition for automation
README.md (optional):	Documentation and setup instructions

HTML Output Design
Title: Reflects system state (“System Users Snapshot”)
Table: Displays session data with headers:
Username
Session ID
Status (Active/Disconnected)
Logon Time
Style: Basic HTML

Resilience
Basic try/catch error handling in PowerShell to log failures

