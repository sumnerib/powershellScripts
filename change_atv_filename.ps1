[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$branch,

    [string]$env,

    [string]$service,

    [switch]$restart
)

function switchEasEnv($path, $new_env, $cur_env) {

    $eas_content = Get-Content $($path + "ateas.properties")
    $eas_content_new = ""
    $encoding = Get-FileEncoding $($path + "ateas.properties")

    foreach ($line in $eas_content) {

        if (($line.Contains($new_env)) -and !($line.Contains("server"))) {
            $line = $line.Replace("#", "")
        } elseif (($line.Contains($cur_env)) -and !($line.Contains("server"))) {
            $line = $line.Insert(0, "#")
        }
        $eas_content_new += $($line + "`r`n")
    }
    $eas_content_new | Set-Content -Path $($path + "ateas.properties") -Encoding $encoding
}

function switchAtlantechEnv($new_env) {
    if ($new_env -eq "dev") {
        $new_env = "test"
    }

    $ini_file = Get-Content "C:\Apps\EAS Acpt\Atlantech.ini"
    $ini_file[1] = changeAtlantechEnvLine $ini_file[1] $new_env

    $ini_file_new = ""
    foreach ($line in $ini_file) {
        $ini_file_new += $($line + "`r`n")
    }
    $ini_file_new > "C:\Apps\EAS Acpt\Atlantech.ini"
}

function changeAtlantechEnvLine($atlantech_env_line, $new_env) {

    $obi_index = $atlantech_env_line.IndexOf("obi")
    $atlantech_env_line = $atlantech_env_line.Insert($obi_index + 3, $new_env)
    $new_length = $atlantech_env_line.IndexOf($new_env) + $new_env.Length
    $atlantech_env_line = $atlantech_env_line.Substring(0, $new_length)
    return $atlantech_env_line
}

function backupFiles($profile_path) {
    mkdir $($profile_path + "backup") | Out-Null
    Copy-Item $($profile_path + "atvantage.properties*") $($profile_path + "\backup")
}

function enableService($service, $path) {

    $properties_file = Get-Content $($path + "atvantage.properties")
    $encoding = Get-FileEncoding $($path + "atvantage.properties")
    $properties_file = $properties_file | ForEach-Object { $_ + "`r`n" }

    if ($service -eq "print") {
        $properties_file = enablePrint $properties_file
        $properties_file = disableRating $properties_file
    } elseif ($service -eq "rating") {
        $properties_file = enableRating $properties_file
        $properties_file = disablePrint $properties_file
    } elseif ($service -eq "both") {
        $properties_file = enablePrint $properties_file
        $properties_file = enableRating $properties_file
    } elseif ($service -eq "neither") {
        $properties_file = disablePrint $properties_file
        $properties_file = disableRating $properties_file
    } else {
        throw "Please specify 'rating', 'print', or 'both' for the service"
    }

    $outString = ""
    $properties_file | ForEach-Object { $outString += $_ }
    $outString | Set-Content -Path $($path + "atvantage.properties") -Encoding $encoding
}

function disablePrint ($propertiesFile) {

    for ($i = 0; $i -lt $propertiesFile.length; $i++) {

        if ($propertiesFile[$i].Contains("PRINT_SVC_WS")) {
            $propertiesFile[$i] = commentLine $propertiesFile[$i]
            $propertiesFile[$i + 1] = commentLine $propertiesFile[$i + 1]
            $propertiesFile[$i + 2] = commentLine $propertiesFile[$i + 2]
        }
    }
    return $propertiesFile
}

function disableRating ($propertiesFile) {

    for ($i = 0; $i -lt $propertiesFile.length; $i++) {

        if ($propertiesFile[$i].Contains("RATING_SVC_WS")) {
            $propertiesFile[$i] = commentLine $propertiesFile[$i]
            $propertiesFile[$i + 1] = commentLine $propertiesFile[$i + 1]
        }
    }
    return $propertiesFile
}

function enablePrint($propertiesFile) {

    for ($i = 0; $i -lt $propertiesFile.length; $i++) {
        if ($propertiesFile[$i].Contains("PRINT_SVC_WS")) {
            $propertiesFile[$i] = $propertiesFile[$i].Replace("#", "")
            $propertiesFile[$i + 1] = $propertiesFile[$i + 1].Replace("#", "")
            $propertiesFile[$i + 2] = $propertiesFile[$i + 2].Replace("#", "")
        }
    }
    return $propertiesFile
}

function enableRating($propertiesFile) {

    for ($i = 0; $i -lt $propertiesFile.length; $i++) {
        if ($propertiesFile[$i].Contains("RATING_SVC_WS")) {
            $propertiesFile[$i] = $propertiesFile[$i].Replace("#", "")
            $propertiesFile[$i + 1] = $propertiesFile[$i + 1].Replace("#", "")
        }
    }
    return $propertiesFile
}

function commentLine($line) {
    if (!$line.Contains("#")) {
        return $line.Insert(0, "#")
    } else {
        return $line
    }
}

function getCurrentEnvironment() {

    $propertiesFile = Get-Content $($profile_path + $atvantage)
    if ($propertiesFile[0].Contains("DJ1")) {
        return "dev"
    } elseif ($propertiesFile[0].Contains("AJ1")) {
        return "acpt"
    } elseif ($propertiesFile[0].Contains("RJ1")) {
        return "qa"
    } elseif ($propertiesFile[0].Contains("PJ1")) {
        return "prod"
    } else {
        return $false;
    }
}

function Get-FileEncoding {
    param ( [string] $FilePath )

    [byte[]] $byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $FilePath

    if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
        { $encoding = 'UTF8' }
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
        { $encoding = 'BigEndianUnicode' }
    elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
        { $encoding = 'Unicode' }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
        { $encoding = 'UTF32' }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76)
        { $encoding = 'UTF7'}
    else
        { $encoding = 'ASCII' }
    return $encoding
}

function helpAndExit() {
    Write-Host "ex: './change_server_env.ps1 -branch [branchName] -env [env] -service [serviceName] -restart'"
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

function renameFiles($profile_path, $cur_env, $new_env) {

    Rename-Item -Path $($profile_path + $atvantage) -NewName $($atvantage + "." + $cur_env) 
    Rename-Item -Path $($profile_path + $bin + $atvantage) -NewName $($atvantage + "." + $cur_env) 
    Rename-Item -Path $($profile_path + $atvantage + "." + $new_env) -NewName $atvantage 
    Rename-Item -Path $($profile_path + $bin + $atvantage + "." + $new_env) -NewName $atvantage 
}

function restartServer($profile_path) {
    cmd.exe /c $($profile_path + $bin + "stopServer.bat server1")
    cmd.exe /c $($profile_path + $bin + "startServer.bat server1")
}

function rollback($profile_path) {
    Copy-Item $($profile_path + "\backup\atvantage.properties*") $profile_path 
    Remove-Item $($profile_path + "\backup") -recurse 
}

function showCurEnv($branch, $cur_env) {
    if (!$cur_env) {
        Write-Host $("Couldn't identify current environment of " + $branch)
    } else {
        Write-Host $("Current environment of " + $branch + ": " + $cur_env)
    }
    exit
}


# Switches the properties files in order to change local Atvantage or Easweb environments
$profile_path = "C:\Projects\IBM\WebSphere\AppServer\profiles\"
$atvantage = "atvantage.properties"
$bin = "bin\"
$profile_name = ""

switch ($branch) {
    "next" {
        $profile_name = "\AppSrv01Next\"
        if ($env -ne "") {
            $env = ""
            Write-Host "Ignoring -env when -branch is 'next'"
        }
    } "main" { $profile_name = "\AppSrv01AtvMain\" }
    "acp" { $profile_name = "\ACPConversionAppSrv01\" }
    "release" { $profile_name = "\AppSrv01Release\" }
    default { helpAndExit }
}

$profile_path += $profile_name
$cur_env = getCurrentEnvironment
if ($env -eq $cur_env) {
    Write-Host $("Already in " + $cur_env)
    $env = ""
} elseif ($env -eq "prod") {
    prodCheck
} elseif ($env -eq "") {
    if ($service -eq "") { showCurEnv $branch $cur_env }
}

$ErrorActionPreference = "Stop"

# Rename the files (and optionally restart server)
try {
    backupFiles $profile_path
    backupFiles $($profile_path + $bin)
    if ($env -ne "") {
        renameFiles $profile_path $cur_env $env
        switchEasEnv $profile_path $env $cur_env
        switchEasEnv $($profile_path + $bin) $env $cur_env
        switchAtlantechEnv $env
    }
    if ($service -ne "") {
        enableService $service $profile_path
        enableService $service $($profile_path + $bin)
    }
    if ($restart) {restartServer $profile_path}
    Remove-Item $($profile_path + "backup") -recurse
    Remove-Item $($profile_path + $bin + "backup") -recurse
} catch {
    rollback $profile_path
    rollback $($profile_path + $bin)
    Write-Error "Rename Failed: $($PSItem.Exception.StackTrace)"
    Write-Error $PSItem.Exception.Message
}
