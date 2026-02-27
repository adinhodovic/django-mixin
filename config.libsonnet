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

    // Django alert configuration
    alerts: {
      enabled: true,

      migrationsUnapplied: {
        enabled: true,
        severity: 'warning',
        duration: '15m',
        threshold: '0',  // any unapplied migrations triggers alert
      },

      databaseException: {
        enabled: true,
        severity: 'info',
        interval: '10m',
        threshold: '0',  // any exception triggers alert
      },

      http4xxErrorRate: {
        enabled: true,
        severity: this.django4xxSeverity,  // backward compatibility
        interval: this.django4xxInterval,  // backward compatibility
        threshold: this.django4xxThreshold,  // backward compatibility
        duration: '1m',
      },

      http5xxErrorRate: {
        enabled: true,
        severity: this.django5xxSeverity,  // backward compatibility
        interval: this.django5xxInterval,  // backward compatibility
        threshold: this.django5xxThreshold,  // backward compatibility
        duration: '1m',
      },
    },

    // Backward compatibility: keep old alert config fields
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
      'django-model-overview': 'django-model-overview-jkwq',
    },
    dashboardUrls: {
      'django-overview': '%s/d/%s/django-overview' % [this.grafanaUrl, this.dashboardIds['django-overview']],
      'django-requests-overview': '%s/d/%s/django-requests-overview' % [this.grafanaUrl, this.dashboardIds['django-requests-overview']],
      'django-requests-by-view': '%s/d/%s/django-requests-by-view' % [this.grafanaUrl, this.dashboardIds['django-requests-by-view']],
      'django-model-overview': '%s/d/%s/django-model-overview' % [this.grafanaUrl, this.dashboardIds['django-model-overview']],
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
