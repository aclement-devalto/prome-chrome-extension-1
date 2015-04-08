angular.module('prome.services')
	.factory('Commander', [
		'$rootScope', '$http', '$sce', 'Messaging',

		function($rootScope, $http, $sce, Messaging) {

			return {
				available: false,
				requestsWaitingCount: 0,

				sendRequest: function(command, tenantAlias, requestObj) {
					var me = this,
						startTime = new Date();

					this.requestsWaitingCount++;

					$http.get('http://localhost:7500/execute/' + command, {
						data: {
							client: tenantAlias
						},
						responseType: 'json',
						timeout: 60000
					})
						.success(function(response, status, headers, config) {
							requestObj.status = 'success';
							me.requestsWaitingCount--;

							if (response.result) {
								requestObj.status = 'success';
							} else {
								requestObj.status = 'error';
							}

							// Reload inspected page if no other requests waiting
							if (me.requestsWaitingCount == 0) {
								Messaging.sendRequest({action: 'reload-tab', tabId: chrome.devtools.inspectedWindow.tabId});
							}

							requestObj.info = 'Request completed in ' + Math.round((new Date() - startTime) / 1000) + 's.';

							requestObj.output = $sce.trustAsHtml(response.output);
						})
						.error(function(response, status, headers, config) {
							requestObj.status = 'error';
							me.requestsWaitingCount--;

							requestObj.info = 'Request failed.';
						});
				},

				ping: function() {
					$http.get('http://localhost:7500/ping', {
						timeout: 1000
					})
						.success(function(response, status) {
							this.available = true;
						})
						.error(function(response, status) {
							this.available = false;
						});
				},

				getStatus: function() {
					return this.available;
				}
			};
		}
	]);