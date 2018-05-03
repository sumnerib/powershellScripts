[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$userEmail
)

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
    if ($email.Sender.Address -eq "root@mrkcpiapplx01.localdomain") { $email.delete() }
    elseif ($email.Subject.Contains("[E!] - ")) { 
        Write-Host $email.Subject
        $email.Unread = $false
        $email.delete() 
    }
}

if  ([bool](Get-Process OUTLOOK* -EA SilentlyContinue)) {
    Get-Process OUTLOOK* | Stop-Process -Force  
}