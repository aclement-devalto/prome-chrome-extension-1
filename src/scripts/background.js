// Chrome automatically creates a background.html page for this to execute.
// This can access the inspected page via executeScript
// 
// Can use:
// chrome.tabs.*
// chrome.extension.*

var tenants = [
	{
		alias: 'adra-aus',
		name: 'ADRA Australia'
	},
	{
		alias: 'undp-mwi',
		name: 'UNDP Malawi'
	}
];

chrome.runtime.onConnect.addListener(function (port) {
	if (port.name !== 'devtools') return;

	var extensionListener = function (message) {
		console.log(JSON.stringify(message));

		switch (message.action) {
			case 'code':
				// Execute code in inspected page
				chrome.tabs.executeScript(message.tabId, {code: message.content});
			break;
			case 'script':
				// Attach script to inspected page
				chrome.tabs.executeScript(message.tabId, {file: message.content});
			break;
			case 'init':
				chrome.tabs.get(message.tabId, function(tab){
					var parseUrl = function(href) {
						var l = document.createElement("a");
						l.href = href;
						return l;
					};

					var location = tab.url,
						host = String(parseUrl(location).hostname),
						isProme = false,
						tenantAlias = null,
						env = null;

					// Check if inspected page is from Prome Web
					if (host.match(/prome.(dev|prod)/i)) {
						isProme = true;

						// Extract tenant alias from host
						tenantAlias = String(host.replace(/.?prome.(dev|prod)/i, ''));

						// Extract dev environment from host
						if (host.match(/prome.dev/i)) {
							env = 'dev';
						} else {
							env = 'prod';
						}
					}

					var currentTenant = null;

					// Find corresponding tenant
					for(var i = 0; i < tenants.length; i++) {
						var tenant = tenants[i];

						if (tenant.alias == tenantAlias) {
							currentTenant = tenant;
						}
					}

					// Send page info back to the panel
					port.postMessage({
						type: 'inspected-page',
						content: {
							tabId: message.tabId,
							location: location,
							host: host,
							isProme: isProme,
							tenant: currentTenant,
							env: env,
							requests: {}
						}
					});
				});
				break;
			case 'new-tab':
				// Open new tab with provided URL
				chrome.tabs.create({
					url: message.content.url
				});
			break;
			case 'reload-tab':
				// Reload tab
				chrome.tabs.reload(message.tabId);
				break;
			default:
				//Pass message to inspectedPage
				chrome.tabs.sendMessage(message.tabId, message, sendResponse);
		}

        // This accepts messages from the inspectedPage and 
        // sends them to the panel
        /*} else {
            port.postMessage(message);
        }*/
        
        //sendResponse(message);
    };

    // Listens to messages sent from the panel
	port.onMessage.addListener(extensionListener);

    port.onDisconnect.addListener(function(port) {
		port.onMessage.removeListener(extensionListener);
    });

});