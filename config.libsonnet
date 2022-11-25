{
  _config+:: {
    djangoSelector: 'job=~"django"',

    grafanaUrl: 'https://grafana.com',

    overviewDashboardUid: 'django-overview-jkwq',
    requestsOverviewDashboardUid: 'django-requests-jkwq',
    requestsByViewDashboardUid: 'django-requests-by-view-jkwq',

    overviewDashboardUrl: '%s/d/%s/django-overview' % [self.grafanaUrl, self.overviewDashboardUid],
    requestsByViewDashboardUrl: '%s/d/%s/django-requests-by-view' % [self.grafanaUrl, self.requestsByViewDashboardUid],

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
