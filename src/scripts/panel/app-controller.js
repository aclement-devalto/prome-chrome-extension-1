angular.module('prome.controllers')
	.controller('AppController', [
		'$rootScope', '$scope', '$window', 'localStorageService', 'Messaging', 'Commander',

		function($rootScope, $scope, $window, localStorageService, Messaging, Commander){

			$scope.tenants = $rootScope.tenants;

			$scope.commands = {
				database:
					{
						title: 'Database',
						actions:
							{
								'create-database': {
									title: 'Creating database',
									label: 'create'
								},
								'drop-database': {
									title: 'Dropping database',
									label: 'drop',
									confirm: 'Do you really want to drop the database ?'
								}
							}
					},
				backend:
					{
						title: 'Back-end',
						actions:
							{
								'reset-setup': {
									title: 'Reset backend setup',
									label: 'reset setup',
									reload: true
								},
								'load-common-fixtures': {
									title: 'Loading common fixtures',
									label: 'load common fixtures'
								},
								'load-tenant-fixtures': {
									title: 'Loading tenant fixtures',
									label: 'load tenant fixtures',
									reload: true
								},
								'clear-cache': {
									title: 'Clearing backend cache',
									label: 'clear cache'
								}
							}
					},
				frontend:
					{
						title: 'Front-end',
						actions:
							{
								'sencha-build': {
									title: 'Building front-end',
									label: 'build all',
									reload: true
								}
							}
					},
				resources:
					{
						title: 'Resources',
						actions:
							{
								'sencha-resources': {
									title: 'Copying resources',
									label: 'copy',
									reload: true
								}
							}
					},
				javascript:
					{
						title: 'Javascript',
						actions:
							{
								'sencha-refresh': {
									title: 'Refresh Javascript files index',
									label: 'refresh index',
									reload: true
								},
								'sencha-build-js': {
									title: 'Compiling Javascript files',
									label: 'build',
									reload: true
								}
							}
					},
				sass:
					{
						title: 'SASS',
						actions:
							{
								'sencha-ant-sass': {
									title: 'Compiling SASS',
									label: 'compile',
									reload: true
								}
							}
					}
			};

			$scope.newUrl = {
				tenant: $scope.tenants[0].alias,
				env: 'dev'
			};

			$scope.inspectedPage = $rootScope.inspectedPage;
			$scope.isCommanderAvailable = function() {
				return Commander.getStatus();
			};
			//$scope.webSocket = Messaging.initWebSocket();

			/**
			 * Manually refresh current inspected page
			 */
			$scope.refreshCurrentPage = function() {
				if (!$scope.inspectedPage || $scope.inspectedPage.tabId != chrome.devtools.inspectedWindow.tabId) {
					Messaging.sendRequest({action: 'init', tabId: chrome.devtools.inspectedWindow.tabId});
				}
			};

			$scope.pingCommander = function() {
				Commander.ping();
			};

			/**
			 * Open Prome with provided tenant and environment in a new tab
			 *
			 * @param {{tenant: String, env: String}} options
			 */
			$scope.openPromeUrl = function(options) {
		        Messaging.sendRequest({
		            action: 'new-tab',
		            content: {
		                url: 'http://' + options.tenant + '.prome.' + options.env
		            }
		        });
			};

			$scope.listenMessagingResponse = function(response) {
				Messaging.handleResponse(response);

				$scope.$apply(function () {
					$scope.inspectedPage = $rootScope.inspectedPage;
				});
			};

			$scope.getActiveRequest = function() {
				if (!$scope.inspectedPage || !$scope.inspectedPage.activeCommand) return null;

				return $scope.inspectedPage.requests[$scope.inspectedPage.activeCommand.alias];
			};

			/**
			 *
			 * @param {string} commandAlias
			 * @param {string} categoryAlias
			 * @param {boolean} launchRequest
			 */
			$scope.switchCommand = function(commandAlias, categoryAlias, launchRequest) {
				var category = $scope.commands[categoryAlias],
					command = category.actions[commandAlias];

				if ($scope.inspectedPage.requests[commandAlias]) {
					$scope.inspectedPage.requests[commandAlias].unread = false;
				}

				if ($scope.inspectedPage.activeCommand && $scope.inspectedPage.activeCommand.alias == commandAlias) {
					launchRequest = true;
				}

				$scope.inspectedPage.activeCommand = command;
				$scope.inspectedPage.activeCommand.alias = commandAlias;

				if (launchRequest) {
					$scope.launchRequest($scope.inspectedPage.activeCommand);
				}
			};

			$scope.launchRequest = function(command) {
				// Stop if similar request is already underway
				if ($scope.inspectedPage.requests[command.alias] && $scope.inspectedPage.requests[command.alias].status == 'loading') return true;

				$scope.inspectedPage.requests[command.alias] = {
					status: 'loading',
					unread: true
				};

				// Send command request to virtual machine listener
				Commander.sendRequest(command.alias, $scope.inspectedPage.tenant.alias, $scope.inspectedPage.requests[command.alias]);
			};

			$scope.init = function() {
				Messaging.sendRequest({action: 'init', tabId: chrome.devtools.inspectedWindow.tabId});
			};

			$scope.init();
		}
	]);