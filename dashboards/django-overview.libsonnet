local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;
local annotation = grafana.annotation;

{
  grafanaDashboards+:: {

    local customAnnotation = if $._config.annotation.enabled then
      annotation.datasource(
        'Deployment',
        datasource=$._config.datasource,
        hide=false,
      ) + {
        target: {
          limit: 100,
          matchAny: false,
          tags: [
            'wario',
          ],
          type: 'tags',
        },
      } else {},

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
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local jobTemplate =
      template.new(
        name='job',
        label='Job',
        datasource='$datasource',
        query='label_values(django_http_responses_total_by_status_view_method_total{namespace=~"$namespace"}, job)',
        current='',
        hide='',
        refresh=1,
        multi=false,
        includeAll=false,
        sort=1
      ),

    local errorCodesTemplate =
      template.custom(
        name='error_codes',
        label='Error Codes',
        query='4,5',
        allValues='4-5',
        current='All',
        hide='',
        refresh=1,
        multi=false,
        includeAll=true,
      ) + {
        description: '4 represents all 4xx codes, 5 represents all 5xx codes',
      },

    local requestTemplates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
      errorCodesTemplate,
    ],

    local requestVolumeQuery = |||
      round(
        sum(
          irate(
            django_http_requests_total_by_view_transport_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view!~"%(djangoIgnoredViews)s",
            }[2m]
          )
        ), 0.001
      )
    ||| % $._config,
    local requestVolumeStatPanel =
      statPanel.new(
        'Request Volume',
        datasource='$datasource',
        unit='reqps',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(requestVolumeQuery))
      .addThresholds([
        { color: 'red', value: 0 },
        { color: 'green', value: 0.001 },
      ]),

    local requestSuccessRateQuery = |||
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            namespace=~"$namespace",
            job=~"$job",
            view!~"%(djangoIgnoredViews)s",
            status!~"[$error_codes].*"
          }[2m]
        )
      ) /
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            namespace=~"$namespace",
            job=~"$job",
            view!~"%(djangoIgnoredViews)s",
          }[2m]
        )
      )
    ||| % $._config,
    local requestSuccessRateStatPanel =
      statPanel.new(
        'Success Rate (non $error_codes-xx responses)',
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

    local cacheHitrateQuery = |||
      sum (
        rate (
          django_cache_get_hits_total {
            namespace=~"$namespace",
            job=~"$job",
          }[30m]
        )
      ) by (namespace, job)
      /
      sum (
        rate (
          django_cache_get_total {
            namespace=~"$namespace",
            job=~"$job",
          }[30m]
        )
      ) by (namespace, job)
    ||| % $._config,
    local cacheHitrateStatPanel =
      statPanel.new(
        'Cache Hitrate [30m]',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(cacheHitrateQuery))
      .addThresholds([
        // { color: 'red', value: 0.2 },
        // { color: 'yellow', value: 0.5 },
        { color: 'green', value: 0 },
      ]),

    local dbOpsQuery = |||
      sum (
        irate (
          django_db_execute_total {
            namespace=~"$namespace",
            job=~"$job",
          }[2m]
        )
      ) by (namespace, job)
    ||| % $._config,
    local dbOpsStatPanel =
      statPanel.new(
        'Database Ops[2m]',
        datasource='$datasource',
        reducerFunction='lastNotNull',
        unit='ops'
      )
      .addTarget(prometheus.target(dbOpsQuery))
      .addThresholds([
        { color: 'green', value: 0 },
      ]),

    local dbLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          rate(
            django_db_query_duration_seconds_bucket{
              namespace=~"$namespace",
              job=~"$job",
            }[5m]
          ) > 0
        ) by (vendor, namespace, job, le)
      )
    ||| % $._config,
    local dbLatencyP95Query = std.strReplace(dbLatencyP50Query, '0.50', '0.95'),
    local dbLatencyP99Query = std.strReplace(dbLatencyP50Query, '0.50', '0.99'),
    local dbLatencyP999Query = std.strReplace(dbLatencyP50Query, '0.50', '0.999'),

    local dbLatencyGraphPanel =
      graphPanel.new(
        'DB Latency [5m]',
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
          dbLatencyP50Query,
          legendFormat='50 - {{ vendor }}',
        )
      )
      .addTarget(
        prometheus.target(
          dbLatencyP95Query,
          legendFormat='95 - {{ vendor }}',
        )
      )
      .addTarget(
        prometheus.target(
          dbLatencyP99Query,
          legendFormat='99 - {{ vendor }}',
        )
      )
      .addTarget(
        prometheus.target(
          dbLatencyP999Query,
          legendFormat='99.9 - {{ vendor }}',
        )
      ),

    local dbConnectionsQuery = |||
      round(
        sum(
          increase(
            django_db_new_connections_total{
              namespace=~"$namespace",
              job=~"$job",
            }[5m]
          ) > 0
        ) by (namespace, job, vendor)
      )
    ||| % $._config,
    local dbConnectionsGraphPanel =
      graphPanel.new(
        'DB Connections [5m]',
        datasource='$datasource',
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
          dbConnectionsQuery,
          legendFormat='{{ vendor }}',
        )
      ),

    local cacheGetHitsQuery = |||
      sum(
        irate(
          django_cache_get_hits_total{
            namespace=~"$namespace",
            job=~"$job",
          }[5m]
        ) > 0
      ) by (namespace, job, backend)
    ||| % $._config,
    local cacheGetMissesQuery = std.strReplace(cacheGetHitsQuery, 'django_cache_get_hits_total', 'django_cache_get_misses_total'),

    local cacheGetGraphPanel =
      graphPanel.new(
        'Cache Get [5m]',
        datasource='$datasource',
        format='ops',
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
          cacheGetHitsQuery,
          legendFormat='Hit - {{ backend }}',
        )
      )
      .addTarget(
        prometheus.target(
          cacheGetMissesQuery,
          legendFormat='Miss - {{ backend }}',
        )
      ),

    local topDbErrors1wQuery = |||
      round(
        topk(10,
          sum by (type) (
            increase(
              django_db_errors_total{
                namespace=~"$namespace",
                job=~"$job",
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,
    local topDbErrors1wTable =
      grafana.tablePanel.new(
        'Top Database Errors (1w)',
        datasource='$datasource',
        sort={
          col: 2,
          desc: true,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Type',
            pattern: 'type',
          },
        ]
      )
      .addTarget(prometheus.target(topDbErrors1wQuery, format='table', instant=true)),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local dbRow =
      row.new(
        title='Database',
      ),

    local cacheRow =
      row.new(
        title='Cache',
      ),

    'django-overview.json':
      dashboard.new(
        'Django / Overview',
        description='A dashboard that monitors Django. It is created using the Django-mixin for the the (Django-exporter)[https://github.com/adinhodovic/django-exporter]',
        uid=$._config.overviewDashboardUid,
        tags=$._config.tags,
        time_from='now-1h',
        editable=true,
        time_to='now',
        timezone='utc'
      )
      .addAnnotation(customAnnotation)
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(requestVolumeStatPanel, gridPos={ h: 4, w: 6, x: 0, y: 1 })
      .addPanel(requestSuccessRateStatPanel, gridPos={ h: 4, w: 6, x: 6, y: 1 })
      .addPanel(dbOpsStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(cacheHitrateStatPanel, gridPos={ h: 4, w: 6, x: 18, y: 1 })
      .addPanel(dbRow, gridPos={ h: 1, w: 24, x: 0, y: 5 })
      .addPanel(topDbErrors1wTable, gridPos={ h: 10, w: 12, x: 0, y: 6 })
      .addPanel(dbLatencyGraphPanel, gridPos={ h: 5, w: 12, x: 12, y: 6 })
      .addPanel(dbConnectionsGraphPanel, gridPos={ h: 5, w: 12, x: 12, y: 11 })
      .addPanel(cacheRow, gridPos={ h: 1, w: 24, x: 0, y: 16 })
      .addPanel(cacheGetGraphPanel, gridPos={ h: 8, w: 24, x: 0, y: 17 })
      +
      { templating+: { list+: requestTemplates } },
  },
}
