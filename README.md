# Flow Action Component to easily export any collection of Sobjects to Google Spreadsheet

##Setup
Needs a Named Credential with scope https://www.googleapis.com/auth/spreadsheets

Settting up a Google Project and the settings on the Salesforce side of things is described here: https://unofficialsf.com/using-google-data-in-flows-authenticating-to-google-from-salesforce/
The only difference is the scope needed. (  https://www.googleapis.com/auth/spreadsheets )

<a href="https://githubsfdeploy.herokuapp.com?owner=jlvanhulst&repo=SalesforceFlow2Gsheet&ref=master">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

Note: this version wil do 'one call' to transfer all values so there is probably a limit as to how man rows it will succesfully handle. Probably the 6mb heaplimit will be hit before the Google Sheets limit. Will be a nice to have for a next version to be able to give a number of rows to be updated at once. 
