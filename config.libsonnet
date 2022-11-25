{
  _config+:: {
    djangoSelector: 'django',

    overviewDashboardUid: 'django-overview-jkwq',
    requestsOverviewDashboardUid: 'django-requests-jkwq',
    requestsByViewDashboardUid: 'django-requests-by-view-jkwq',

    tags: ['django', 'django-mixin'],

    adminViewRegex: 'admin.*',
    djangoIgnoredViews: 'health_check:health_check_home|prometheus-django-metrics',
    djangoIgnoredTemplates: "\\\\['health_check/index.html'\\\\]|None",

    django4xxSeverity: 'warning',
    django4xxInterval: '5m',
    django4xxThreshold: '5',  // percent
    django5xxSeverity: 'warning',
    django5xxInterval: '5m',
    django5xxThreshold: '5',  // percent

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      datasource: '-- Grafana --',
      tags: [],
    },
  },
}
