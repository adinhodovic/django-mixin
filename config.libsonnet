local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local annotation = grafana.annotation;

{
  _config+:: {
    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    djangoSelector: 'job=~"django"',

    grafanaUrl: 'https://grafana.com',

    overviewDashboardUid: 'django-overview-jkwq',
    requestsOverviewDashboardUid: 'django-requests-jkwq',
    requestsByViewDashboardUid: 'django-requests-by-view-jkwq',

    overviewDashboardUrl: '%s/d/%s/django-overview' % [self.grafanaUrl, self.overviewDashboardUid],
    requestsByViewDashboardUrl: '%s/d/%s/django-requests-by-view' % [self.grafanaUrl, self.requestsByViewDashboardUid],

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

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Deploys',
      datasource: '-- Grafana --',
      tags: [],
    },

    customAnnotation:: if $._config.annotation.enabled then
      annotation.datasource(
        $._config.annotation.name,
        datasource=$._config.annotation.datasource,
        hide=false,
      ) + {
        target: {
          matchAny: true,
          tags: $._config.annotation.tags,
          type: 'tags',
        },
      } else {},
  },
}
