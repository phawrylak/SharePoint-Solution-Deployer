###############################################################################
# SharePoint Solution Deployer (SPSD) Extension for SharePoint Features
# Version          : 1.0.0.1
# Creator          : René Hézser
# License          : MS-PL
# File             : Features.ps1
###############################################################################

function Execute-WebsiteExtension($parameters, [System.Xml.XmlElement]$data, [string]$extId, [string]$extensionPath){
	$websitesNode = $data.FirstChild
	foreach($websiteNode in $websitesNode.ChildNodes){
		if ($websiteNode.LocalName -ne 'Website') { continue }
		
		Log -message ('Working on Website "'+$websiteNode.Url+'"') -type $SPSD.LogTypes.Information
		Execute-WebsiteAction $websiteNode
	}
}

function Execute-WebsiteAction ([System.Xml.XmlElement]$websiteNode) {
	try {
		$request = Prepare-Request $websiteNode
		if ($request -eq $null) {
			return
		}

		Log -message ('Calling "' + $websiteNode.Url + '"') -type $SPSD.LogTypes.Verbose
		$webResponse = $request.GetResponse()
		$responseStream = $webResponse.GetResponseStream()
		if ($webResponse.StatusCode -eq 'OK'){
			$sr = new-object IO.StreamReader($responseStream)
			$response = $sr.ReadToEnd()
		} else {
			Log -message ($webResponse.StatusCode+':'+$webResponse.StatusDescription) -type $SPSD.LogTypes.Error
		}
		$webResponse.close()
	
		$success = Validate-Response $response $websiteNode
		if ($success -eq $true) {
			Log -message ('Success') -type $SPSD.LogTypes.Success
		} else {
			Log -message ('Fail') -type $SPSD.LogTypes.Error
		}

	} catch {
		$errorMessage = $_.Exception.Message
		Log -message ($errorMessage) -type $SPSD.LogTypes.Error
	}
}

function Prepare-Request([System.Xml.XmlElement]$websiteNode){
	if ($websiteNode.Method -ne 'GET' -and $websiteNode.Method -ne 'POST') {
		Log -message ($websiteNode.Method + ' is not a supported operation. Only "GET" and "POST" are supported.') -type $SPSD.LogTypes.Error
		return $null
	}

	$proxy = [System.Net.WebRequest]::GetSystemWebProxy()
	$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

	if ($websiteNode.Method -eq 'GET' -and $websiteNode.Payload.Length -gt 0) {
		Log -message ('Adding "' + $websiteNode.Payload + '" to the request url') -type $SPSD.LogTypes.VerboseExtended
		$websiteNode.Url += $websiteNode.Payload
	}
	$request = [System.Net.HttpWebRequest]::CreateHttp($websiteNode.Url)
	$request.Method = $websiteNode.Method
	$request.UseDefaultCredentials = $true ## Proxy credentials only
	$request.Proxy.Credentials = $request.Credentials
	
	if ($websiteNode.Method -eq 'POST') {	
		$requestStream = $request.GetRequestStream()
		if ($websiteNode.Payload.Length -gt 0){
			$encoding = [system.Text.Encoding]::UTF8
			$postBytes = $encoding.GetBytes($websiteNode.Payload)
			$requestStream.Write($postBytes, 0, $postBytes.Length)
		}
		$requestStream.flush()
		$requestStream.close()
	}

	return $request
}

function Validate-Response($response, [System.Xml.XmlElement]$webSiteNode){
	$success = $false
	if ($websiteNode.ContainsText.Length -gt 0) {
		if ($response.ToLowerInvariant().Contains($websiteNode.ContainsText.ToLowerInvariant())) {
			$success = $true
			Log -message ('The response contains the text') -type $SPSD.LogTypes.Verbose
		} else {
			Log -message ('The response does not contains the text') -type $SPSD.LogTypes.Verbose
		}
	}

	if ($websiteNode.NotContainsText.Length -gt 0) {
		if ($response.ToLowerInvariant().Contains($websiteNode.NotContainsText.ToLowerInvariant())) {
			$success = $false
			Log -message ('The response contains the text') -type $SPSD.LogTypes.Verbose
		} else {
			if ($success -eq $true) {
				$success = $true
			}
			Log -message ('The response does not contains the text') -type $SPSD.LogTypes.Verbose
		}
	}
	return $success
}
