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
    ;

    $urlRouterProvider.otherwise('/');
});