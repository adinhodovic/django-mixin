{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',
  prometheusAlerts+:: {
    groups+: if $._config.alerts.enabled then [
      {
        name: 'django',
        rules: std.prune([
          if $._config.alerts.migrationsUnapplied.enabled then {
            alert: 'DjangoMigrationsUnapplied',
            expr: |||
              sum(
                django_migrations_unapplied_total{
                  %(djangoSelector)s
                }
              ) by (%(clusterLabel)s, namespace, job)
              > %(threshold)s
            ||| % ($._config + $._config.alerts.migrationsUnapplied),
            labels: {
              severity: $._config.alerts.migrationsUnapplied.severity,
            },
            'for': $._config.alerts.migrationsUnapplied.duration,
            annotations: {
              summary: 'Django has unapplied migrations.',
              description: 'The job {{ $labels.job }} has unapplied migrations.',
              dashboard_url: $._config.dashboardUrls['django-overview'] + '?var-namespace={{ $labels.namespace }}&var-job={{ $labels.job }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.databaseException.enabled then {
            alert: 'DjangoDatabaseException',
            expr: |||
              sum (
                increase(
                  django_db_errors_total{
                    %(djangoSelector)s
                  }[%(interval)s]
                )
              ) by (%(clusterLabel)s, type, namespace, job)
              > %(threshold)s
            ||| % ($._config + $._config.alerts.databaseException),
            labels: {
              severity: $._config.alerts.databaseException.severity,
            },
            annotations: {
              summary: 'Django database exception.',
              description: 'The job {{ $labels.job }} has hit the database exception {{ $labels.type }}.',
              dashboard_url: $._config.dashboardUrls['django-overview'] + '?var-namespace={{ $labels.namespace }}&var-job={{ $labels.job }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.http4xxErrorRate.enabled then {
            alert: 'DjangoHighHttp4xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    status=~"4.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(interval)s]
                )
              )  by (%(clusterLabel)s, namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(interval)s]
                )
              )  by (%(clusterLabel)s, namespace, job, view)
              * 100 > %(threshold)s
            ||| % ($._config + $._config.alerts.http4xxErrorRate),
            'for': $._config.alerts.http4xxErrorRate.duration,
            annotations: {
              summary: 'Django high HTTP 4xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 4xx for {{ $labels.job }}/{{ $labels.view }} the past %(interval)s.' % $._config.alerts.http4xxErrorRate,
              dashboard_url: $._config.dashboardUrls['django-requests-by-view'] + '?var-namespace={{ $labels.namespace }}&var-job={{ $labels.job }}&var-view={{ $labels.view }}' + clusterVariableQueryString,
            },
            labels: {
              severity: $._config.alerts.http4xxErrorRate.severity,
            },
          },
          if $._config.alerts.http5xxErrorRate.enabled then {
            alert: 'DjangoHighHttp5xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    status=~"5.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(interval)s]
                )
              )  by (%(clusterLabel)s, namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_total{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(interval)s]
                )
              )  by (%(clusterLabel)s, namespace, job, view)
              * 100 > %(threshold)s
            ||| % ($._config + $._config.alerts.http5xxErrorRate),
            'for': $._config.alerts.http5xxErrorRate.duration,
            annotations: {
              summary: 'Django high HTTP 5xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 5xx for {{ $labels.job }}/{{ $labels.view }} the past %(interval)s.' % $._config.alerts.http5xxErrorRate,
              dashboard_url: $._config.dashboardUrls['django-requests-by-view'] + '?var-namespace={{ $labels.namespace }}&var-job={{ $labels.job }}&var-view={{ $labels.view }}' + clusterVariableQueryString,
            },
            labels: {
              severity: $._config.alerts.http5xxErrorRate.severity,
            },
          },
        ]),
      },
    ] else [],
  },
}
