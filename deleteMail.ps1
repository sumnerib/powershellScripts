[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$userEmail
)

if  ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Get-Process OUTLOOK* | Stop-Process -Force  
}

while ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Start-Sleep -Seconds 1
}

# Used to log emails that should be deleted but for some reason can't be
$Logfile = ".\delete_mail.log"
Function LogWrite
{
    Param ([string]$logstring)
    Add-content $Logfile -value $logstring
}

if ($userEmail -notmatch '^[_a-z0-9-]+(.[a-z0-9-]+)@[a-z0-9-]+(.[a-z0-9-]+)*\.([a-z]{2,4})$') {
    Write-Error "Bad User Email"
    exit
}

$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")            
            
$account = $namespace.Folders | Where-Object { $_.Name -eq $userEmail }
$inbox = $account.Folders | Where-Object { $_.Name -match "Inbox" }
$subjectList = ""
$deleteCount = 0

for ($i=$($inbox.Items.count); $i -ge 1; $i--) { # 1-based collection
    $email =  $inbox.Items[$i]
    $blacklist = Get-Content ".\delete_list.txt"

    $subjectList += $($email.Subject + "`r`n")
    try {
        if ($blacklist.Contains($email.Sender.Address)) { 
            $email.delete()
            $deleteCount += 1
        } elseif ($email.Subject.Contains("[E!] - ") -or
                $email.Subject.Contains("Incident ISSUE=") -or
                $email.Subject.Contains("Subtask Opened to Team, Update with Assignee")) {
            
            $deleteCount += 1
            $email.Unread = $false
            $email.delete() 
        }
    } catch {
        LogWrite $("[" + (Get-Date).ToString() + "] " + $PSItem.Exception.Message)
        LogWrite $("[" + (Get-Date).ToString() + "] " + $email.Sender.Address) 
        LogWrite $("[" + (Get-Date).ToString() + "] " + $email.Subject) 
    }
}
LogWrite $subjectList
LogWrite $("[" + (Get-Date).ToString() + "] Number of Items Deleted: " + $deleteCount) 

if  ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Get-Process OUTLOOK* | Stop-Process -Force  
}