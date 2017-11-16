function backupFiles($profile_path) {
    mkdir $($profile_path + "backup") | Out-Null
    Copy-Item $($profile_path + "atvantage.properties*") $($profile_path + "\backup") 
}

function helpAndExit() {
    Write-Host "ex: './change_server_env.ps1 [branchname] [env]'"
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

function rollback($profile_path) {
    Copy-Item $($profile_path + "\backup\atvantage.properties*") $profile_path 
    Remove-Item $($profile_path + "\backup") -recurse 
}

# Switches the properties files in order to change local Atvantage or Easweb environments
$profile_path = "C:\Projects\IBM\SDP\runtimes\base_v7\profiles"
$atvantage = "atvantage.properties"
$bin = "bin\"

switch ($args[0]) {
    "next" {  
        Write-Host "Not intended for use with next branch"
        exit
    }
    "main" { 
        $profile_name = "\AppSrv01AtvMain\"
        if ($args[1] -eq "dev") {
            $old_env = "acpt"
        } elseif ($args[1] -eq "acpt") {
            $old_env = "dev"
        } else {
            helpAndExit
        }
    }
    "release" {
        $profile_name = "\AppSrv01AtvRelease\"
        if ($args[1] -eq "qa") {
            $old_env = "prod"
        } elseif ($args[1] -eq "prod") {
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
$profile_path += $profile_name

$ErrorActionPreference = "Stop"

# Rename the files
try {
    renameFiles $profile_path $old_env $args[1]
} catch {
    rollback $profile_path
    rollback $($profile_path + $bin)
    Write-Error "Rename Failed: $($PSItem.Exception.StackTrace)"
    Write-Error $PSItem.Exception.Message
}
