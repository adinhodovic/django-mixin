{
  _config+:: {
    local this = self,

    djangoSelector: 'job="django"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    grafanaUrl: 'https://grafana.com',

    tags: ['django', 'django-mixin'],

    adminViewRegex: 'admin.*',
    djangoIgnoredViews: '<unnamed view>|health_check:health_check_home|prometheus-django-metrics',
    djangoIgnoredTemplates: ".*'health_check/index.html'.*|None",

    django4xxSeverity: 'warning',
    django4xxInterval: '5m',
    django4xxThreshold: '5',  // percent
    django5xxSeverity: 'warning',
    django5xxInterval: '5m',
    django5xxThreshold: '5',  // percent

    dashboardIds: {
      'django-overview': 'django-overview-jkwq',
      'django-requests-overview': 'django-requests-jkwq',
      'django-requests-by-view': 'django-requests-by-view-jkwq',
    },
    dashboardUrls: {
      'django-overview': '%s/d/%s/django-overview' % [this.grafanaUrl, this.dashboardIds['django-overview']],
      'django-requests-overview': '%s/d/%s/django-requests-overview' % [this.grafanaUrl, this.dashboardIds['django-requests-overview']],
      'django-requests-by-view': '%s/d/%s/django-requests-by-view' % [this.grafanaUrl, this.dashboardIds['django-requests-by-view']],
    },

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      tags: [],
      datasource: '-- Grafana --',
      iconColor: 'blue',
      type: 'tags',
    },
  },
}
