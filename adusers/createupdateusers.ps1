
Function AddADUser {
       Param(
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Username,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Domain,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [SecureString]$Password,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Firstname,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Lastname,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$OU
       )
       New-ADUser `
           -SamAccountName $Username `
           -UserPrincipalName "$Username@$Domain" `
           -Name "$Firstname $Lastname" `
           -GivenName $Firstname `
           -Surname $Lastname `
           -Enabled $True `
           -ChangePasswordAtLogon $False `
           -DisplayName "$Lastname, $Firstname" `
           -Path $OU `
           -AccountPassword (convertto-securestring $Password -AsPlainText -Force)
           
   
   }
   
   Function UpdateADUser {
       Param(
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Username,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Domain,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [securestring]$Password,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Firstname,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$Lastname,
   
           [Parameter(Mandatory=$True)]
           [ValidateNotNullorEmpty()]
           [string]$OU
       )
   
       Set-ADUser -Identity $Username `
           -UserPrincipalName "$Username@$Domain" `
           -GivenName $Firstname `
           -Surname $Lastname `
           -Enabled $True `
           -ChangePasswordAtLogon $False `
           -DisplayName "$Lastname, $Firstname"
   
   }
   
   
   #user input 
   $ADUsers = Import-csv adusers.csv
   
   foreach ($User in $ADUsers)
   {
   
          $Username = $User.username
          $Domain = $User.domain
          $Password = ConvertTo-SecureString -String $User.password -AsPlainText -Force
          $Firstname = $User.firstname
          $Lastname = $User.lastname
          $OU = $User.ou
   
          #Check if the user account already exists in AD
          if (Get-ADUser -F {SamAccountName -eq $Username})
          {
                  #If user does exist, output a warning message
                  Write-Warning "A user account $Username has already exist in Active Directory."
                  #TODO - update user
                  Write-Host "Attempting to update user $Username"
                  UpdateADUser `
                   -Username $Username `
                   -Domain $Domain `
                   -Password $Password `
                   -Firstname $Firstname `
                   -Lastname $Lastname `
                   -OU $OU
          }
          else
          {
               Write-Host "Attempting to create user $Username"
               #If a user does not exist then create a new user account
               AddADUser `
                   -Username $Username `
                   -Domain $Domain `
                   -Password $Password `
                   -Firstname $Firstname `
                   -Lastname $Lastname `
                   -OU $OU
          }
   }