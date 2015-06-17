angular.module('prome.services')
	.factory('Commander', [
		'$rootScope', '$http', '$sce', 'Messaging',

		function($rootScope, $http, $sce, Messaging) {

			return {
				available: false,
				requestsWaitingCount: 0,
				queue: [],

				sendRequest: function(commandAlias, tenantAlias, requestObj) {
					var me = this;

					var task = {
						commandAlias: commandAlias,
						tenantAlias: tenantAlias,
						requestObj: requestObj
					};

					if (commandAlias == 'create-database') {
						task.waitFor = 'drop-database';
					} else if (commandAlias == 'load-common-fixtures') {
						task.waitFor = 'create-database';
					} else if (commandAlias == 'load-tenant-fixtures') {
						task.waitFor = 'load-common-fixtures';
					}

					// Queue task
					this.queue.push(task);
					this.requestsWaitingCount++;

					var delayed = false;

					if (task.waitFor) {
						// If task has dependency, check if a dependent task is currently processing
						var length = this.queue.length;
						for (var i = 0; i < length; i++) {
							var queuedTask = me.queue[i];

							// If a dependent task is processing, delay the current task
							if (queuedTask == task.waitFor) {
								delayed = true;
								break;
							}
						}
					}

					if (!delayed) {
						this.processRequest(task, requestObj);
					}
				},

				processRequest: function(task, requestObj) {
					var me = this,
						startTime;

					// Open socket connection to dispatcher
					var webSocket = new WebSocket('ws://localhost:7500/command');

					webSocket.onopen = function(event) {
						startTime = new Date();

						// Send command order
						webSocket.send(JSON.stringify({
							command: task.commandAlias,
							tenant: task.tenantAlias
						}));

						//console.log('Commant sent to dispatcher:' + task.commandAlias);
					};

					// Wait for response
					webSocket.onmessage = function(message) {
						var response = JSON.parse(message.data);

						//console.log('Response from dispatcher:');
						//console.log(response);

						var formatOutput = function (output) {
							lines = output.split("\n");

							for (i = 0, len = lines.length; i < len; ++i) {
								lines[i] = String(lines[i]).replace(/\[INF\]/g, '<span style="color: green;">[INF]</span>');
								lines[i] = String(lines[i]).replace(/\[WRN\]/g, '<span style="color: yellow;">[WRN]</span>');
								lines[i] = String(lines[i]).replace(/\[ERR\]/g, '<span style="color: red;">[ERR]</span>');
							}

							return lines.join('<br>');
						};

						$rootScope.$apply(function () {
							if (response.status) {
								requestObj.status = 'success';
								requestObj.info = 'Request completed in ' + Math.round((new Date() - startTime) / 1000) + 's.';
								me.requestsWaitingCount--;

								if ($rootScope.inspectedPage.activeCommand.alias == task.commandAlias) {
									requestObj.unread = false;
								}

								// Database cleaned : log out user to prevent 'User not found' exception
								if (task.commandAlias == 'create-database' || task.commandAlias == 'drop-database' || task.commandAlias == 'reset-setup') {
									Messaging.sendRequest({
										action: 'code',
										tabId: chrome.devtools.inspectedWindow.tabId,
										content: "localStorage.removeItem('prome_user');"
									});
								}

								// Reload inspected page if no other requests waiting
								if (me.requestsWaitingCount == 0) {
									Messaging.sendRequest({action: 'reload-tab', tabId: chrome.devtools.inspectedWindow.tabId});
								}

								requestObj.output = $sce.trustAsHtml(formatOutput(response.output));
							} else {
								requestObj.status = 'error';
								me.requestsWaitingCount--;

								if ($rootScope.inspectedPage.activeCommand.alias == task.commandAlias) {
									requestObj.unread = false;
								}

								if (response.error) {
									requestObj.output = $sce.trustAsHtml('<span style="color: red;">' + formatOutput(response.error) + '</span>');
								} else {
									requestObj.output = $sce.trustAsHtml(formatOutput(response.output));
								}

								requestObj.info = 'Request failed.';
							}

							me.completeTask(task, response);
						});

						// Close socket connection
						webSocket.close();
					};

					webSocket.onclose = function(message) {
						if (requestObj.status == 'loading') {
							requestObj.status = 'error';
							me.requestsWaitingCount--;

							if ($rootScope.inspectedPage.activeCommand.alias == task.commandAlias) {
								requestObj.unread = false;
							}

							requestObj.info = 'Request failed: connection closed';

							me.completeTask(task, {
								status: false
							});
						}
					};
				},

				completeTask: function(task, response) {
					var me = this,
						taskIndex,
						dependentTask;

					// Find queued task
					var length = this.queue.length;
					for (var i = 0; i < length; i++) {
						var queuedTask = me.queue[i];

						if (queuedTask == task.commandAlias) {
							taskIndex = i;
						}

						if (queuedTask.waitFor && queuedTask.waitFor == task.commandAlias) {
							dependentTask = queuedTask;
						}
					}

					// Unqueue task
					me.queue.splice(taskIndex, 1);

					// If this task is a dependency to another task, execute the other task
					if (response.status && dependentTask) {
						this.processRequest(dependentTask, dependentTask.requestObj);
					}
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