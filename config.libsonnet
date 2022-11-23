{
  _config+:: {
    // The task interval is used as the interval for Prometheus alerts of failed tasks and the Grafana graph visualizing task state over time.
    taskInterval: '10m',

    overviewDashboardUid: 'django-overview-jqkwfdqwd',
    requestsDashboardUid: 'django-requests-jqkwfdqwd',

    tags: ['django', 'django-mixin'],
    djangoIgnoredViews: 'health_check:health_check_home|prometheus-django-metrics',
    djangoIgnoredTemplates: "\\\\['health_check/index.html'\\\\]",
  },
}
