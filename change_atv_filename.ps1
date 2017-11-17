[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$branch,

    [string]$env,

    [switch]$restart
)

function backupFiles($profile_path) {
    mkdir $($profile_path + "backup") | Out-Null
    Copy-Item $($profile_path + "atvantage.properties*") $($profile_path + "\backup") 
}

function helpAndExit() {
    Write-Host "ex: './change_server_env.ps1 -branch [branchname] -env [env]'"
    exit
}

function prodCheck() {
    $end = $false
    do {
        $keepGoing = Read-Host -Prompt "Are you sure you want to switch to prod? (Y/N)"
        if ($keepGoing -like "Y") {
            $end = $true
        } elseif ($keepGoing -like "N") {
            exit
        } else {
            Write-Host "Please enter Y or N"    
        }  
    } until ($end)
}

function renameFiles($profile_path, $old_env, $new_env) {
    backupFiles $profile_path
    backupFiles $($profile_path + $bin)
    Rename-Item -Path $($profile_path + $atvantage) -NewName $($atvantage + "." + $old_env) 
    Rename-Item -Path $($profile_path + $bin + $atvantage) -NewName $($atvantage + "." + $old_env) 
    Rename-Item -Path $($profile_path + $atvantage + "." + $new_env) -NewName $atvantage 
    Rename-Item -Path $($profile_path + $bin + $atvantage + "." + $new_env) -NewName $atvantage 
    Remove-Item $($profile_path + "backup") -recurse
    Remove-Item $($profile_path + $bin + "backup") -recurse 
}

function restartServer($profile_path) {
    cmd.exe /c $($profile_path + $bin + "stopServer.bat server1")
    cmd.exe /c $($profile_path + $bin + "startServer.bat server1")
}

function rollback($profile_path) {
    Copy-Item $($profile_path + "\backup\atvantage.properties*") $profile_path 
    Remove-Item $($profile_path + "\backup") -recurse 
}

function showCurEnv($branch, $profile_path) {

    $cur_env = ""
    $propertiesFile = Get-Content $($profile_path + $atvantage)
    if ($propertiesFile[0].Contains("DJ1")) {
        $cur_env = "dev"
    } elseif ($propertiesFile[0].Contains("AJ1")) {
        $cur_env = "acpt"
    } elseif ($propertiesFile[0].Contains("RJ1")) {
        $cur_env = "qa"
    } elseif ($propertiesFile[0].Contains("PJ1")) {
        $cur_env = "prod"
    } else {
        Write-Host $("Couldn't identify current environment of " + $branch)
        exit
    }
    Write-Host $("Current environment of " + $branch + ": " + $cur_env)
    exit
}

# Switches the properties files in order to change local Atvantage or Easweb environments
$profile_path = "C:\Projects\IBM\SDP\runtimes\base_v7\profiles"
$atvantage = "atvantage.properties"
$bin = "bin\"

switch ($branch) {
    "next" {  
        Write-Host "Not intended for use with next branch"
        exit
    }
    "main" { 
        $profile_name = "\AppSrv01AtvMain\"
        $profile_path += $profile_name

        if ($env -eq "") {
            showCurEnv $branch $profile_path
        } elseif ($env -eq "dev") {
            $old_env = "acpt"
        } elseif ($env -eq "acpt") {
            $old_env = "dev"
        } else {
            helpAndExit
        }
    }
    "release" {
        $profile_name = "\AppSrv01AtvRelease\"
        $profile_path += $profile_name

        if ($env -eq "") {
            showCurEnv $branch $profile_path
        } elseif ($env -eq "qa") {
            $old_env = "prod"
        } elseif ($env -eq "prod") {
            prodCheck
            $old_env = "qa"
        } else {
            helpAndExit       
        }
    }
    default {
        helpAndExit
    }
}

$ErrorActionPreference = "Stop"

# Rename the files (and optionally restart server)
try {
    renameFiles $profile_path $old_env $env
    if ($restart) {restartServer $profile_path}
} catch {
    rollback $profile_path
    rollback $($profile_path + $bin)
    Write-Error "Rename Failed: $($PSItem.Exception.StackTrace)"
    Write-Error $PSItem.Exception.Message
}
