# Connect to Microsoft Graph
Connect-MgGraph -Scopes 'Application.Read.All'

# Connect to Azure
Connect-AzAccount
Set-AzContext -Subscription "<subscription_id>"

# Specify Log Analytics workspace ID found in the Azure Portal
$workspaceId = "<workspace_id>"

$AppData = @()

# Retrieve all applications
Write-Host "Fetching all applications from Microsoft Graph..." -ForegroundColor Yellow
$Applications = Get-MgApplication -All

foreach ($App in $Applications)
{
	$AppName = $App.DisplayName
	$AppId = $App.Id
	$AppSecrets = $App.PasswordCredentials
	$AppCertificates = $App.KeyCredentials
	
	# Get active secrets and certificates
	$ActiveSecrets = $AppSecrets | Where-Object { $_.EndDateTime -gt (Get-Date) }
	$ActiveCerts = $AppCertificates | Where-Object { $_.EndDateTime -gt (Get-Date) }
	
	# Get owner information
	$Owners = Get-MgApplicationOwner -ApplicationId $AppId
	$OwnerNames = $Owners | ForEach-Object { $_.AdditionalProperties.displayName }
	$OwnerNames = $OwnerNames -join '; '
	
	# Query for Service Principal sign-in 
	Write-Host "Querying Log Analytics for Service Principal sign-ins for app: $AppName" -ForegroundColor Yellow
	$spSignInQuery = @"
AADServicePrincipalSignInLogs | where TimeGenerated >= ago(60d) | where ServicePrincipalName == '$AppName' | summarize LastSignIn = max(TimeGenerated)
"@
	$spSignInResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $spSignInQuery -ErrorAction Stop
	$LastServicePrincipalSignIn = $spSignInResult.Results.LastSignIn
	
	# Query for User sign-ins 
	Write-Host "Querying Log Analytics for User sign-ins for app: $AppName" -ForegroundColor Yellow
	$userSignInQuery = @"
SigninLogs | where TimeGenerated >= ago(60d) | where AppDisplayName == '$AppName' | summarize LastSignInDate = max(TimeGenerated)
"@
	$userSignInResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $userSignInQuery -ErrorAction Stop
	$LastUserSignIn = $userSignInResult.Results.LastSignInDate
	
	# Collect data for CSV
	$ActiveSecretNames = $ActiveSecrets | ForEach-Object { $_.DisplayName }
	$ActiveSecretNames = $ActiveSecretNames -join ', '
	
	$ActiveCertNames = $ActiveCerts | ForEach-Object { $_.DisplayName }
	$ActiveCertNames = $ActiveCertNames -join ', '
	
	$CertExpiryDates = $ActiveCerts | ForEach-Object { $_.EndDateTime }
	$CertExpiryDates = $CertExpiryDates -join ', '
	
	# Add data to results
	$AppData += [PSCustomObject]@{
		AppName				       = $AppName
		LastServicePrincipalSignIn = $LastServicePrincipalSignIn
		LastUserSignIn			   = $LastUserSignIn
		ActiveSecrets			   = $ActiveSecretNames
		ActiveCerts			       = $ActiveCertNames
		CertExpiryDates		       = $CertExpiryDates
		Owners					   = $OwnerNames
	}
}

# Export to CSV
$OutputPath = Read-Host "Enter the full path to save the CSV (e.g., C:\Users\<USER>\Desktop\ApplicationsData.csv)"
$AppData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Export completed successfully to $OutputPath!" -ForegroundColor Green
