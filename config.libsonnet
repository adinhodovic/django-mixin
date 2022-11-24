{
  _config+:: {
    // The task interval is used as the interval for Prometheus alerts of failed tasks and the Grafana graph visualizing task state over time.
    taskInterval: '10m',

    overviewDashboardUid: 'django-overview-jkwq',
    requestsOverviewDashboardUid: 'django-requests-jkwq',
    requestsByViewDashboardUid: 'django-requests-by-view-jkwq',

    tags: ['django', 'django-mixin'],

    adminViewRegex: 'admin.*',
    djangoIgnoredViews: 'health_check:health_check_home|prometheus-django-metrics',
    djangoIgnoredTemplates: "\\\\['health_check/index.html'\\\\]|None",

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      datasource: '-- Grafana --',
      tags: [],
    },
  },
}
