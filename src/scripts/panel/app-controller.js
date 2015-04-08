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
									title: 'Database creation',
									label: 'create'
								},
								'drop-database': {
									title: 'Drop database',
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
									title: 'Reset setup',
									label: 'reset setup'
								},
								'load-fixtures': {
									title: 'Load fixtures',
									label: 'load fixtures'
								},
								'clear-cache': {
									title: 'Clear cache',
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
									title: 'Building front-end resources',
									label: 'build'
								}
							}
					},
				resources:
					{
						title: 'Resources',
						actions:
							{
								'sencha-resources': {
									title: 'Resources copy',
									label: 'copy'
								}
							}
					},
				javascript:
					{
						title: 'Javascript',
						actions:
							{
								'sencha-refresh': {
									title: 'Javascript files refresh',
									label: 'refresh'
								},
								'sencha-build-js': {
									title: 'Javascript files build',
									label: 'build'
								}
							}
					},
				sass:
					{
						title: 'SASS',
						actions:
							{
								'sencha-ant-sass': {
									title: 'SASS compile',
									label: 'compile'
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
				// Refresh current tab on page focus
				//$window.addEventListener('focus', function(){
				//	angular.element(document.body).scope().refreshCurrentPage();
				//});

				Messaging.sendRequest({action: 'init', tabId: chrome.devtools.inspectedWindow.tabId});
			};

			$scope.init();
		}
	]);