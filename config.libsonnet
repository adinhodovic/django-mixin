{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    djangoSelector: 'job=~"django|django-exporter"',

    // The task interval is used as the interval for Prometheus alerts of failed tasks and the Grafana graph visualizing task state over time.
    taskInterval: '10m',

    httpRequestDashboardUid: 'django-request-jqkwfdqwd',

    tags: ['django', 'django-mixin'],
    djangoIgnoredViews: 'health_check:health_check_home|prometheus-django-metrics',
    djangoIgnoredTemplates: "\\\\['health_check/index.html'\\\\]",
  },
}
