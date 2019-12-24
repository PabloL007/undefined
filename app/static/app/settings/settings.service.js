angular.module('settings')
  .service('SettingsService', function SettingsService($http) {
    this.getTopics = function getTopics() {
      return $http.get('/topics');
    };
  })
;