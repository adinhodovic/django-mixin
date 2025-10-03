local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotation = g.dashboard.annotation;

{
  _config+:: {
    local this = self,

    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    djangoSelector: 'job=~"django"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

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

    dashboardIds: {
      'django-overview': 'django-overview-jkwq',
      'django-requests-overview': 'django-requests-jkwq',
    },
    dashboardUrls: {
      'django-overview': '%s/d/%s/django-overview' % [this.grafanaUrl, this.dashboardIds['django-overview']],
      'django-requests-overview': '%s/d/%s/django-requests-overview' % [this.grafanaUrl, this.dashboardIds['django-requests-overview']],
    },

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      datasource: '-- Grafana --',
      iconColor: 'green',
      tags: [],
    },

    customAnnotation:: if $._config.annotation.enabled then
      annotation.withName($._config.annotation.name) +
      annotation.withIconColor($._config.annotation.iconColor) +
      annotation.withHide(false) +
      annotation.datasource.withUid($._config.annotation.datasource) +
      annotation.target.withMatchAny(true) +
      annotation.target.withTags($._config.annotation.tags) +
      annotation.target.withType('tags')
    else {},
  },
}
