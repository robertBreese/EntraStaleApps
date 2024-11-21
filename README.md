The purpose of this script is to identify unused app registrations and service principals in Entra ID for potential cleanup. It evaluates based on the following conditions:

1. **No Service Principal Sign-ins**: Checks if the principal has had no activity as a Service Principal in the last 60 days by querying `AADServicePrincipalSignInLogs`.

2. **No User Sign-ins**: Verifies if no users have signed into the principal in the last 60 days by querying `SigninLogs`.

3. **No Active Secrets or Credentials**: Ensures that the principal has no active secrets, certificates, or federated credentials.
4. **No Ownership**: Confirms if the principal has no assigned owners.

The script uses the Microsoft Graph PowerShell SDK to retrieve metadata about all application and service principals and queries Log Analytics for sign-in activity logs. By combining this data, the script performs the following:

* Identifies app registrations and principals that meet the criteria for inactivity (e.g., no recent sign-ins, no active credentials, and no ownership).

* Outputs a refined list of principals for further review.

If an app registration or service principal does not meet one or more of the conditions above, it can safely be considered stale/unused.

To run this script, you will need powershell 7, the Microsoft.Graph module, and Az module.

Before running, replace the subscription ID and workspace ID at the top of the script. Choose the subscription ID that contains your log analytics workspace connected to Entra, and for workspace ID you will find that on the Log Analytics Workspace resource overview in the Azure Portal.
