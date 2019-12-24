angular.module('live')
  .service('LiveService', function LiveService($http) {
    this.getTopics = function getTopics() {
      return $http.get('/topics');
    };
  })
;