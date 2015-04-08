'use strict';

// Declare app level module which depends on filters, and services
angular.module('prome', [
	'prome.controllers',
	'prome.services',
	'LocalStorageModule'
])
	.config([
		'localStorageServiceProvider',

		function(localStorageServiceProvider) {
			localStorageServiceProvider
				.setPrefix('promeDevExtension')
				.setStorageType('sessionStorage')
				.setNotify(true, true);
		}
	])
	.run([
		'$rootScope',

		function ($rootScope) {
			$rootScope.inspectedPage = null;

			$rootScope.tenants = [
				{
					alias: 'adra-aus',
					name: 'ADRA Australia'
				},
				{
					alias: 'undp-mwi',
					name: 'UNDP Malawi'
				}
			];
		}
	]);

angular.module('prome.controllers', []);
angular.module('prome.services', []);