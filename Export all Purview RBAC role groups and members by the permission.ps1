<#
.SYNOPSIS
Export Microsoft Purview / Compliance Center RBAC Role Groups and Their Members

.DESCRIPTION
This PowerShell script connects to both Exchange Online and Microsoft Purview (Compliance PowerShell)
to retrieve all RBAC Role Groups and their assigned members.

It displays the results in a graphical table (Out-GridView)
and exports the same data to a CSV file for documentation or auditing purposes.

If the ExchangeOnlineManagement module is not installed, the script installs it automatically.

Created by Ewelina Paczkowska (Welka’s World)
GitHub: https://github.com/welkasworld
Version: 1.0
Date: 2025-11-02

.REQUIREMENTS
- PowerShell 5.1 or later
- ExchangeOnlineManagement module (auto-installs if missing)
- Global Administrator or Compliance Administrator rights
- Interactive sign-in (supports MFA)

.NOTES
- Run in a fresh PowerShell session.
- Sign in with the same admin account for both connections.
- Results are shown in a window and also saved as a timestamped CSV file.

#>

#------------------------------------------------------------
# 1️-  Check and install the ExchangeOnlineManagement module
#------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement -ErrorAction Stop

#------------------------------------------------------------
# 2️-  Clean up any existing stale PowerShell sessions
#------------------------------------------------------------
Get-PSSession | Where-Object {
    $_.ComputerName -like "*outlook*" -or $_.ComputerName -like "*compliance*"
} | ForEach-Object {
    Remove-PSSession -Id $_.Id -ErrorAction SilentlyContinue
}

#------------------------------------------------------------
# 3️-  Connect to Exchange Online (for mailbox resolution)
#------------------------------------------------------------
Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
Connect-ExchangeOnline -ShowBanner:$false

#------------------------------------------------------------
# 4️-  Connect to Microsoft Purview / Compliance PowerShell
#------------------------------------------------------------
Write-Host "Connecting to Microsoft Purview (Compliance PowerShell)..." -ForegroundColor Cyan
try {
    Connect-IPPSSession -ErrorAction Stop
} catch {
    Write-Warning "Could not connect to Compliance PowerShell: $($_.Exception.Message)"
    Write-Warning "Continuing with Exchange Online connection only..."
}

#------------------------------------------------------------
# 5️-  Retrieve all role groups (RBAC roles)
#------------------------------------------------------------
Write-Host "Retrieving Purview / Compliance role groups..." -ForegroundColor Yellow
[array]$RoleGroups = Get-RoleGroup -ResultSize Unlimited

# Prepare a list for output
$Report = [System.Collections.Generic.List[Object]]::new()

#------------------------------------------------------------
# 6️-  Loop through each role group and list its members
#------------------------------------------------------------
foreach ($RoleGroup in $RoleGroups) {
    $rgDisplay = $RoleGroup.DisplayName
    $rgIdentity = $RoleGroup.Identity -as [string]
    Write-Host "Processing: $rgDisplay" -ForegroundColor Green

    $members = @()
    try {
        # Primary method: use Get-RoleGroupMember
        $members = @(Get-RoleGroupMember -Identity $rgIdentity -ResultSize Unlimited -ErrorAction Stop)
    } catch {
        Write-Warning "Could not get members for '$rgDisplay' by Identity: $($_.Exception.Message)"
        try {
            $members = @(Get-RoleGroupMember -Identity $rgDisplay -ResultSize Unlimited -ErrorAction Stop)
        } catch {
            Write-Warning "Failed to get members for '$rgDisplay' by Name as well."
            $members = @()
        }
    }

    # Collect member details (DisplayName + Primary SMTP if possible)
    $MemberNames = [System.Collections.Generic.List[object]]::new()
    foreach ($m in $members) {
        $name = $m.Name
        $smtp = $null
        if ($m.PSObject.Properties.Match('PrimarySmtpAddress')) {
            $smtp = $m.PrimarySmtpAddress
        } elseif ($m.PSObject.Properties.Match('WindowsEmailAddress')) {
            $smtp = $m.WindowsEmailAddress
        }

        if ($smtp) {
            $MemberNames.Add("$name <$smtp>")
        } else {
            $MemberNames.Add($name)
        }
    }

    # If no members found, fallback to empty
    if ($MemberNames.Count -eq 0) { $MemberNames.Add("(none)") }

    # Format last modified date
    $lastUpdated = if ($RoleGroup.WhenChanged -and ($RoleGroup.WhenChanged -ne "Wednesday 1 January 2020 00:00:00")) {
        Get-Date($RoleGroup.WhenChanged) -Format g
    } else { "Never" }

    # Build the report object
    $Report += [PSCustomObject]@{
        "Role Group"    = $rgDisplay
        "Members"       = ($MemberNames -join ", ")
        "Last Updated"  = $lastUpdated
    }
}

#------------------------------------------------------------
# 7️- Display results and export to CSV
#------------------------------------------------------------
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outFile = ".\Purview_RoleGroups_Members_$timestamp.csv"

$Report | Sort-Object "Role Group" | Out-GridView -Title "Microsoft Purview Role Group Memberships"
$Report | Sort-Object "Role Group" | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8

Write-Host "`n✅ Export complete! File saved as: $outFile" -ForegroundColor Green

#------------------------------------------------------------
# 8️- Disconnect sessions to clean up
#------------------------------------------------------------
try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
try {
    Get-PSSession | Where-Object { $_.ComputerName -like "*compliance*" } |
    Remove-PSSession -ErrorAction SilentlyContinue
} catch {}

Write-Host "`nAll sessions closed. Script finished successfully." -ForegroundColor Cyan
