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
						params: {
							client: tenantAlias
						},
						responseType: 'json',
						timeout: 1800000
					})
						.success(function(response, status, headers, config) {
							requestObj.status = 'success';
							me.requestsWaitingCount--;

							if (response.result) {
								requestObj.status = 'success';
								requestObj.info = 'Request completed in ' + Math.round((new Date() - startTime) / 1000) + 's.';
							} else {
								requestObj.status = 'error';
								requestObj.info = 'Request failed.';
							}

							if ($rootScope.inspectedPage.activeCommand.alias == command) {
								requestObj.unread = false;
							}

							// Database cleaned : log out user to prevent 'User not found' exception
							if (command == 'create-database' || command == 'drop-database' || command == 'reset-setup') {
								Messaging.sendRequest({action: 'code', tabId: chrome.devtools.inspectedWindow.tabId, content: "localStorage.removeItem('prome_user');"});
							}

							// Reload inspected page if no other requests waiting
							if (response.result && me.requestsWaitingCount == 0) {
								Messaging.sendRequest({action: 'reload-tab', tabId: chrome.devtools.inspectedWindow.tabId});
							}

							var formatOutput = function(output) {
								lines = output.split("\n");

								for (i = 0, len = lines.length; i < len; ++i) {
									lines[i] = String(lines[i]).replace(/\[INF\]/g, '<span style="color: green;">[INF]</span>');
									lines[i] = String(lines[i]).replace(/\[WRN\]/g, '<span style="color: yellow;">[WRN]</span>');
									lines[i] = String(lines[i]).replace(/\[ERR\]/g, '<span style="color: red;">[ERR]</span>');
								}

								return lines.join('<br>');
							};

							if (response.result) {
								requestObj.output = $sce.trustAsHtml(formatOutput(response.output));
							} else {
								requestObj.output = $sce.trustAsHtml('<span style="color: red;">' + formatOutput(response.error) + '</span>');
							}
						})
						.error(function(response, status, headers, config) {
							requestObj.status = 'error';
							me.requestsWaitingCount--;

							if ($rootScope.inspectedPage.activeCommand.alias == command) {
								requestObj.unread = false;
							}

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