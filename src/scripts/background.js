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
		name: 'UNDP - Malawi'
	},
	{
		alias: 'lasip-lbr',
		name: 'LASIP - Liberia'
	}
];

var tabs = [];

// Instantiate websocket connection with Listener
var webSocket = new WebSocket('ws://localhost:7500/socket');
webSocket.onmessage = function(m) {
	var message = JSON.parse(m.data);
	switch(message.action) {
		case 'watcher-rebuild':
			// Reload Prome tabs for this tenant
			for (var tabId in tabs) {
				if( tabs.hasOwnProperty( tabId ) ) {
					if (tabs[tabId].isProme === true && tabs[tabId].tenant.alias == message.tenant) {
						// Clear cache & reload tab
						(function(){
							const id = tabId;
							chrome.browsingData.removeCache({
								"since": new Date().setDate(new Date().getDate() - 7)
							}, function(){
								chrome.tabs.reload(id);
							})
						})();
					}
				}
			}
			break;
	}
};

// Keep track of which open tabs are Prome
chrome.tabs.onUpdated.addListener(function (tabId, changeInfo, tabObj){
	if (changeInfo.url) {
		var host = getLocationHost(changeInfo.url);

		if (tabs[tabId]) {
			var tab = tabs[tabId];

			// Check if tab hostname changed
			if (tab.host != host) {
				// Update saved tab info
				tabs[tabId] = getTabInfo(changeInfo.url);
			}
		} else {
			// Save new tab with tab info
			tabs[tabId] = getTabInfo(changeInfo.url);
		}
	}
});

// Listen to internal messaging from inspected pages or devtools panel
chrome.runtime.onConnect.addListener(function (port) {
	if (port.name !== 'devtools') return;

	var extensionListener = function (message) {

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
					var location = tab.url;

					var tabInfo = getTabInfo(location);

					// Send page info back to the panel
					port.postMessage({
						type: 'inspected-page',
						content: mergeObjects(tabInfo, {
							tabId: message.tabId,
							location: location,
							requests: {},
							tenants: tenants
						})
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
				// Clear cache & reload tab
				chrome.browsingData.removeCache({
					"since": new Date().setDate(new Date().getDate() - 7)
				}, function(){
					chrome.tabs.reload(message.tabId);
				});
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

var mergeObjects = function(target, source) {

	/* Merges two (or more) objects,
	 giving the last one precedence */

	if ( typeof target !== 'object' ) {
		target = {};
	}

	for (var property in source) {

		if ( source.hasOwnProperty(property) ) {

			var sourceProperty = source[ property ];

			if ( typeof sourceProperty === 'object' ) {
				target[ property ] = mergeObjects( target[ property ], sourceProperty );
				continue;
			}

			target[ property ] = sourceProperty;

		}

	}

	for (var a = 2, l = arguments.length; a < l; a++) {
		mergeObjects(target, arguments[a]);
	}

	return target;
};

var parseTabUrl = function(href) {
	var l = document.createElement("a");
	l.href = href;
	return l;
};

var getLocationHost = function(location) {
	return String(parseTabUrl(location).hostname);
};

var getTabInfo = function(location) {
	var host = getLocationHost(location),
		isProme = false,
		tenantAlias = null,
		env = null,
		currentTenant = null;

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

	// Find corresponding tenant
	for(var i = 0; i < tenants.length; i++) {
		var tenant = tenants[i];

		if (tenant.alias == tenantAlias) {
			currentTenant = tenant;
		}
	}

	// If no tenant found in the list, just use the alias as name
	if (!currentTenant) {
		var tenantName = tenantAlias.split('-');

		currentTenant = {
			alias: tenantAlias,
			name: tenantName[0].toUpperCase() + ' (' + tenantName[1].toUpperCase() + ')'
		};
	}

	return {
		host: host,
		isProme: isProme,
		tenant: currentTenant,
		env: env
	}
};