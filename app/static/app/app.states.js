angular.module('app').config(function ($stateProvider, $urlRouterProvider) {
    $stateProvider
        // Abstract state serves as a PLACEHOLDER or NAMESPACE for application states
        .state('app', {
            url: '',
            abstract: true
        })
        .state('app.live', {
          url: '/',
          views:{
              'body@': {
                controller: 'LiveCtrl',
                controllerAs: 'ctrl',
                templateUrl: 'static/app/live/live.tmpl.html'
              }
          }
        })
        .state('app.settings', {
          url: '/settings',
          views:{
              'body@': {
                controller: 'SettingsCtrl',
                controllerAs: 'ctrl',
                templateUrl: 'static/app/settings/settings.tmpl.html'
              }
          }
        })
    ;

    $urlRouterProvider.otherwise('/');
});