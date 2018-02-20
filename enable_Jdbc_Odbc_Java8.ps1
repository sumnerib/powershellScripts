#######################################################
# Used to enable use of Access DB with jdbc-odbc driver
# author: Isaac Sumner
# 2-20-2018
#######################################################

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, ParameterSetName='JavaRuntimePath')]
    [ValidateScript({Test-Path $_})]
    [string]$jre,

    [Parameter(Mandatory=$true, ParameterSetName='DoRepair')]
    [switch]$repair,

    [switch]$terse
)

# Courtesy of: https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
function Test-RegistryValue {
    param (
    
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,
        
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )
    
    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

$access_db_engine_msi = 'Microsoft Access database engine 2010 (English)'
$src_path =  "\\mrkvmapp076\E\PrintAccessDB\"
$mso_path = "HKLM:\SOFTWARE\Microsoft\Office\14.0\Common\FilesPaths\"

function Check-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Remove-MSOIfExists {
    $mso_exists = Test-RegistryValue -Path $mso_path -Value "mso.dll"
    if ($mso_exists) {
        Remove-ItemProperty -Path $mso_path -Name "mso.dll"
        Write-Host "mso.dll Removed"
    }
}

function Repair-AfterPatch {
   
    if ($terse) { $ProgressPreference = 'SilentlyContinue' }
    if (Check-Command -cmdname 'Repair-MSIProduct') {
        Get-MSIProductInfo -Name $access_db_engine_msi | Repair-MSIProduct 
    } else {
        Install-Module -Name 'MSI'
        Get-MSIProductInfo -Name $access_db_engine_msi | Repair-MSIProduct 
    }
    if ($terse) { $ProgressPreference = 'Continue' }
    Remove-MSOIfExists
}

if ($PSBoundParameters.ContainsKey('repair')) { 
    Repair-AfterPatch 
    Write-Host "JDBC-ODBC driver enabled!"
    exit
}

if ($jre -notmatch '.+?\\$') { $jre += '\'}

# 1.  Copy jdbc.jar into 'lib/ext' folder of the JRE.
Copy-Item $($src_path + "jdbc.jar") $($jre + "lib\ext")

# 2.  Copy JdbcOdbc.dll into 'bin' folder of the JRE.
Copy-Item $($src_path + "JdbcOdbc.dll") $($jre + "bin")

# 3.  Use regedit to look for mso.dll key in HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Office/14.0/Common/Files/Paths.  
# If it already exists, you are done.  If it does not exist, proceed to step 4.
$mso_exists = Test-RegistryValue -Path $mso_path -Value "mso.dll"
if ($mso_exists) { exit }

# 4.  Install AccessDatabaseEngine_X64.  Add the /passive parameter when executing.
& $($src_path + "AccessDatabaseEngine_X64.exe") "/passive"

# 5.  Look at HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Office/14.0/Common/Files/Paths again and 
# remove mso.dll key if it was added by the install.
Remove-MSOIfExists
Write-Host "JDBC-ODBC driver enabled!"
