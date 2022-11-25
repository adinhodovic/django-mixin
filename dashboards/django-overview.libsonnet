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
        current='',
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

    local templates = [
      prometheusTemplate,
      namespaceTemplate,
      jobTemplate,
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
          }[$__rate_interval]
        )
      ) by (namespace, job)
    ||| % $._config,
    local dbOpsStatPanel =
      statPanel.new(
        'Database Ops',
        datasource='$datasource',
        reducerFunction='lastNotNull',
        unit='ops'
      )
      .addTarget(prometheus.target(dbOpsQuery))
      .addThresholds([
        { color: 'green', value: 0 },
      ]),

    local response2xxQuery = |||
      round(
        sum(
          irate(
            django_http_responses_total_by_status_view_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view!~"%(djangoIgnoredViews)s",
              status=~"2.*",
            }[$__rate_interval]
          ) > 0
        ) by (job), 0.001
      )
    ||| % $._config,
    local response4xxQuery = std.strReplace(response2xxQuery, '2.*', '4.*'),
    local response5xxQuery = std.strReplace(response2xxQuery, '2.*', '5.*'),

    local responseGraphPanel =
      graphPanel.new(
        'Responses',
        datasource='$datasource',
        format='reqps',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
        legend_sort='avg',
        legend_sortDesc=true,
        fill=10,
        stack=true,
        percentage=true,
        nullPointMode='null as zero'
      )
      .addTarget(
        prometheus.target(
          response2xxQuery,
          legendFormat='2xx',
        )
      )
      .addTarget(
        prometheus.target(
          response4xxQuery,
          legendFormat='4xx',
        )
      )
      .addTarget(
        prometheus.target(
          response5xxQuery,
          legendFormat='5xx',
        )
      ),

    local dbLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          rate(
            django_db_query_duration_seconds_bucket{
              namespace=~"$namespace",
              job=~"$job",
            }[$__rate_interval]
          ) > 0
        ) by (vendor, namespace, job, le)
      )
    ||| % $._config,
    local dbLatencyP95Query = std.strReplace(dbLatencyP50Query, '0.50', '0.95'),
    local dbLatencyP99Query = std.strReplace(dbLatencyP50Query, '0.50', '0.99'),
    local dbLatencyP999Query = std.strReplace(dbLatencyP50Query, '0.50', '0.999'),

    local dbLatencyGraphPanel =
      graphPanel.new(
        'DB Latency',
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
          }[$__rate_interval]
        ) > 0
      ) by (namespace, job, backend)
    ||| % $._config,
    local cacheGetMissesQuery = std.strReplace(cacheGetHitsQuery, 'django_cache_get_hits_total', 'django_cache_get_misses_total'),

    local cacheGetGraphPanel =
      graphPanel.new(
        'Cache Get',
        datasource='$datasource',
        format='ops',
        legend_show=true,
        legend_values=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        legend_avg=true,
        legend_max=true,
        legend_hideZero=true,
        legend_sort='avg',
        legend_sortDesc=true,
        stack=true,
        fill=10,
        nullPointMode='null as zero'
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

    local migrationsAppliedQuery = |||
      max (
        django_migrations_applied_total {
            namespace="$namespace",
            job="$job"
        }
      ) by (namespace, job)
    ||| % $._config,
    local migrationsAppliedStatPanel =
      statPanel.new(
        'Migrations Applied',
        datasource='$datasource',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(migrationsAppliedQuery))
      .addThresholds([
        { color: 'green', value: 0 },
      ]),

    local migrationsUnAppliedQuery = |||
      max (
        django_migrations_unapplied_total {
            namespace="$namespace",
            job="$job"
        }
      ) by (namespace, job)
    ||| % $._config,
    local migrationsUnAppliedStatPanel =
      statPanel.new(
        'Migrations Unapplied',
        datasource='$datasource',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(migrationsUnAppliedQuery))
      .addThresholds([
        { color: 'green', value: 0 },
        { color: 'red', value: 0.1 },
      ]),

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
        description='A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache). It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).',
        uid=$._config.overviewDashboardUid,
        tags=$._config.tags,
        time_from='now-1h',
        editable=true,
        time_to='now',
        timezone='utc'
      )
      .addPanel(summaryRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(requestVolumeStatPanel, gridPos={ h: 4, w: 12, x: 0, y: 1 })
      .addPanel(dbOpsStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(cacheHitrateStatPanel, gridPos={ h: 4, w: 6, x: 18, y: 1 })
      .addPanel(responseGraphPanel, gridPos={ h: 6, w: 24, x: 0, y: 5 })
      .addPanel(dbRow, gridPos={ h: 1, w: 24, x: 0, y: 11 })
      .addPanel(migrationsAppliedStatPanel, gridPos={ h: 3, w: 6, x: 0, y: 12 })
      .addPanel(migrationsUnAppliedStatPanel, gridPos={ h: 3, w: 6, x: 6, y: 12 })
      .addPanel(topDbErrors1wTable, gridPos={ h: 9, w: 12, x: 0, y: 15 })
      .addPanel(dbLatencyGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 12 })
      .addPanel(dbConnectionsGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 18 })
      .addPanel(cacheRow, gridPos={ h: 1, w: 24, x: 0, y: 24 })
      .addPanel(cacheGetGraphPanel, gridPos={ h: 6, w: 24, x: 0, y: 25 })
      +
      { templating+: { list+: templates } } +
      if $._config.annotation.enabled then
        {
          annotations: {
            list: [
              $._config.customAnnotation,
            ],
          },
        }
      else {},
  },
}
