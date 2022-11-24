local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;

{
  grafanaDashboards+:: {

    local prometheusTemplate =
      template.datasource(
        'datasource',
        'prometheus',
        'Prometheus',
        hide='',
      ),

    local namespaceTemplate =
      template.new(
        name='namespace',
        label='Namespace',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{}, namespace)',
        hide='',
        refresh=1,
        multi=false,
        includeAll=false,
        sort=1
      ),

    local jobTemplate =
      template.new(
        name='job',
        label='Job',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{namespace=~"$namespace"}, job)',
        hide='',
        refresh=1,
        multi=false,
        includeAll=false,
        sort=1
      ),

    local defaultFilters = 'namespace=~"$namespace", job=~"$job"',

    local viewTemplate =
      template.new(
        name='view',
        label='View',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{%s, view!~"%s"}, view)' % [defaultFilters, $._config.djangoIgnoredViews],
        hide='',
        refresh=1,
        multi=false,
        includeAll=false,
        sort=1
      ),

    local methodTemplate =
      template.new(
        name='method',
        label='Method',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{%s, view=~"$view"}, method)' % defaultFilters,
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local requestTemplates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
      viewTemplate,
      methodTemplate,
    ],


    local requestHttpExceptionsQuery = |||
      sum by (view) (
        increase(
          django_http_exceptions_total_by_view_total{
            namespace=~"$namespace",
            job=~"$job",
            view="$view",
          }[1w]
        ) > 0
      )
    ||| % $._config,

    local requestHttpExceptionsStatPanel =
      statPanel.new(
        'HTTP Exceptions [1w]',
        datasource='$datasource',
        unit='reqps',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestHttpExceptionsQuery))
      .addThresholds([
        { color: 'green', value: 0.1 },
        { color: 'yellow', value: 10 },
        { color: 'red', value: 100 },
      ]),

    local requestSuccessRateQuery = |||
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{namespace=~"$namespace", job=~"$job", view="$view", method=~"$method", status!~"[4-5].*"}[1w]
          )
      ) /
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{namespace=~"$namespace", job=~"$job", view="$view", method=~"$method"}[1w]
        )
      )
    ||| % $._config,
    local requestSuccessRateStatPanel =
      statPanel.new(
        'Success Rate (non 4xx-5xx responses) [1w]',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestSuccessRateQuery))
      .addThresholds([
        { color: 'red', value: 0.90 },
        { color: 'yellow', value: 0.95 },
        { color: 'green', value: 0.99 },
      ]),

    local requestLatencyP50SummaryQuery = |||
      histogram_quantile(0.50,
        sum (
          rate (
              django_http_requests_latency_seconds_by_view_method_bucket {
                namespace=~"$namespace",
                job=~"$job",
                view="$view",
                method=~"$method"
              }[$__range]
          )
        ) by (job, le)
      )
    ||| % $._config,
    local requestLatencyP50SummaryStatPanel =
      statPanel.new(
        'Average Request Latency (P50) [1w]',
        datasource='$datasource',
        unit='s',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestLatencyP50SummaryQuery))
      .addThresholds([
        { color: 'green', value: 0 },
        { color: 'yellow', value: 1000 },
        { color: 'red', value: 2000 },
      ]),

    local requestLatencyP95SummaryQuery = std.strReplace(requestLatencyP50SummaryQuery, '0.50', '0.95'),
    local requestLatencyP95SummaryStatPanel =
      statPanel.new(
        'Request Latency (P95) [1w]',
        datasource='$datasource',
        unit='s',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestLatencyP95SummaryQuery))
      .addThresholds([
        { color: 'green', value: 0 },
        { color: 'yellow', value: 2500 },
        { color: 'red', value: 5000 },
      ]),

    local responseQuery = |||
      round(
        sum(
          irate(
            django_http_responses_total_by_status_view_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view="$view",
              method=~"$method",
            }[5m]
          ) > 0
        ) by (namespace, job, view, status, method), 0.001
      )
    ||| % $._config,

    local responseGraphPanel =
      graphPanel.new(
        'Response Status',
        datasource='$datasource',
        format='reqps',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
      )
      .addTarget(
        prometheus.target(
          responseQuery,
          legendFormat='{{ view }} / {{ status }} / {{ method }}',
        )
      ),

    local requestLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          rate(
            django_http_requests_latency_seconds_by_view_method_bucket{
              namespace=~"$namespace",
              job=~"$job",
              view="$view",
              method=~"$method"
            }[$__range]
          ) > 0
        ) by (view, le)
      )
    ||| % $._config,
    local requestLatencyP95Query = std.strReplace(requestLatencyP50Query, '0.50', '0.95'),
    local requestLatencyP99Query = std.strReplace(requestLatencyP50Query, '0.50', '0.99'),
    local requestLatencyP999Query = std.strReplace(requestLatencyP50Query, '0.50', '0.999'),

    local requestLatencyGraphPanel =
      graphPanel.new(
        'Request Latency',
        datasource='$datasource',
        format='s',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
      )
      .addTarget(
        prometheus.target(
          requestLatencyP50Query,
          legendFormat='50 - {{ view }}',
        )
      )
      .addTarget(
        prometheus.target(
          requestLatencyP95Query,
          legendFormat='95 - {{ view }}',
        )
      )
      .addTarget(
        prometheus.target(
          requestLatencyP99Query,
          legendFormat='99 - {{ view }}',
        )
      )
      .addTarget(
        prometheus.target(
          requestLatencyP999Query,
          legendFormat='99.9 - {{ view }}',
        )
      ),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local apiViewRow =
      row.new(
        title='API Views & Other'
      ),

    'django-requests-by-view.json':
      dashboard.new(
        'Django / Requests / By View',
        description='A dashboard that monitors Django. It is created using the Django-mixin for the the (Django-exporter)[https://github.com/adinhodovic/django-exporter]',
        uid=$._config.requestsByViewDashboardUid,
        tags=$._config.tags,
        time_from='now-1h',
        editable=true,
        time_to='now',
        timezone='utc'
      )
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(requestSuccessRateStatPanel, gridPos={ h: 4, w: 6, x: 0, y: 1 })
      .addPanel(requestHttpExceptionsStatPanel, gridPos={ h: 4, w: 6, x: 6, y: 1 })
      .addPanel(requestLatencyP50SummaryStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(requestLatencyP95SummaryStatPanel, gridPos={ h: 4, w: 6, x: 18, y: 1 })
      .addPanel(apiViewRow, gridPos={ h: 1, w: 24, x: 0, y: 5 })
      .addPanel(responseGraphPanel, gridPos={ h: 10, w: 12, x: 0, y: 6 })
      .addPanel(requestLatencyGraphPanel, gridPos={ h: 10, w: 12, x: 12, y: 6 })
      +
      { templating+: { list+: requestTemplates } },
  },
}
