{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'django',
        rules: [
          {
            alert: 'DjangoMigrationsUnapplied',
            expr: |||
              sum(
                increase(
                  django_migrations_unapplied_total{
                    %(djangoSelector)s
                  }[15m]
                )
              ) by (namespace, job)
              > 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Django unapplied migrations.',
              description: 'The job {{ $labels.job }} has unapplied migrations.',
            },
          },
          {
            alert: 'DjangoHighHttp4xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_created{
                    %(djangoSelector)s,
                    status=~"^4.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django4xxInterval)s]
                )
              )  by (namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_created{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django4xxInterval)s]
                )
              )  by (namespace, job, view)
              * 100 > %(django4xxThreshold)s
            ||| % $._config,
            annotations: {
              summary: 'Django high HTTP 4xx error rate.',
              description: 'More than %(django4xxThreshold)s%% HTTP requests with status 4xx for {{ $labels.job }}/{{ $labels.view }} the past %(django4xxInterval)s.' % $._config,
              dashboard_url: $._config.requestsByViewDashboardUid + '?var-job={{ $labels.job }}&var-view={{ $labels.view }}',
            },
            'for': '30s',
            labels: {
              severity: $._config.django4xxSeverity,
            },
          },
          {
            alert: 'DjangoHighHttp5xxErrorRate',
            expr: |||
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_created{
                    %(djangoSelector)s,
                    status=~"^5.*",
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django5xxInterval)s]
                )
              )  by (namespace, job, view)
              /
              sum(
                rate(
                  django_http_responses_total_by_status_view_method_created{
                    %(djangoSelector)s,
                    view!~"%(djangoIgnoredViews)s"
                  }[%(django5xxInterval)s]
                )
              )  by (namespace, job, view)
              * 100 > %(django5xxThreshold)s
            ||| % $._config,
            annotations: {
              summary: 'Django high HTTP 5xx error rate.',
              description: 'More than %(django4xxThreshold)s%% HTTP requests with status 5xx for {{ $labels.job }}/{{ $labels.view }} the past %(django4xxInterval)s.' % $._config,
              dashboard_url: $._config.requestsByViewDashboardUid + '?var-job={{ $labels.job }}&var-view={{ $labels.view }}',
            },
            'for': '30s',
            labels: {
              severity: $._config.django5xxSeverity,
            },
          },
        ],
      },
    ],
  },
}
