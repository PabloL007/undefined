angular.module('app', [
    'ngAnimate',
    'ngMaterial',
    'ngMessages',
    'ngSanitize',
    'ui.router',
    'live',
    'settings'
])
.config(function($mdThemingProvider) {
  $mdThemingProvider.theme('default')
    .primaryPalette('indigo')
    .accentPalette('blue-grey')
    .dark();
});
