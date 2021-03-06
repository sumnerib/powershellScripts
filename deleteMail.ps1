[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$userEmail
)

Add-Type -AssemblyName System.Windows.Forms

function isReady {
    return [System.Windows.Forms.MessageBox]::Show('Can Outlook be closed for Inbox cleaning?', "Question", 4)
}

Set-Location -Path "C:\Users\ibsumne\powershellScripts"

if  ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {

    while ((isReady) -eq 'No') { 
        Start-Sleep -Seconds 180 
    }
    Get-Process OUTLOOK* | Stop-Process -Force  
}

while ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Start-Sleep -Seconds 1
}

$Logfile = ".\delete_mail.log"
function LogWrite {
    Param (
        [string]$logstring,
        [switch]$timestamp
    )

    $value = ""
    if ($timestamp) { $value += $("[" + (Get-Date).ToString() + "] ") }
    $value += $logstring
    Add-content $Logfile -value $value
}

if ($userEmail -notmatch '^[_a-z0-9-]+(.[a-z0-9-]+)@[a-z0-9-]+(.[a-z0-9-]+)*\.([a-z]{2,4})$') {
    Write-Error "Bad User Email"
    exit
}

$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")            
            
$blacklist = Get-Content ".\delete_list.txt"
$account = $namespace.Folders | Where-Object { $_.Name -eq $userEmail }
$inbox = $account.Folders | Where-Object { $_.Name -match "Inbox" }
$deleteCount = 0

for ($i=$($inbox.Items.count); $i -ge 1; $i--) { # 1-based collection
    $email =  $inbox.Items[$i]

    try {
        if ($blacklist.Contains($email.Sender.Address)) {
            LogWrite -t -l $email.Sender.Address
            $email.delete()
            $deleteCount += 1
        } elseif ($email.Subject.Contains("[E!] - ") -or
                $email.Subject.Contains("Incident ISSUE=") -or
                $email.Subject.Contains("Subtask Opened to Team, Update with Assignee")) {
            
            LogWrite -t -l $email.Subject
            $email.delete() 
            $deleteCount += 1
        }
    } catch {
        LogWrite -t -l $PSItem.Exception.Message
    }
}
LogWrite -t -l $("Number of Items Deleted: " + $deleteCount) 

# Restart Outlook
Start-Process outlook.exe 
