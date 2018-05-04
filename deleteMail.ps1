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

for ($i=$($inbox.Items.count);$i -ge 1; $i--) { # 1-based collection
    $email =  $inbox.Items[$i]
    $blacklist = Get-Content ".\delete_list.txt"

    try {
        if ($blacklist.Contains($email.Sender.Address)) { $email.delete() }
        elseif ($email.Subject.Contains("[E!] - ")) { 
            $email.Unread = $false
            $email.delete() 
        }
    } catch {
        LogWrite $("[" + (Get-Date).ToString() + "] " + $PSItem.Exception.Message)
        LogWrite $("[" + (Get-Date).ToString() + "] " + $email.Sender.Address) 
        LogWrite $("[" + (Get-Date).ToString() + "] " + $email.Subject) 
    }
}

if  ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Get-Process OUTLOOK* | Stop-Process -Force  
}