local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboardUtil = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local timeSeriesPanel = g.panel.timeSeries;
local tablePanel = g.panel.table;

// Stat
local stStandardOptions = statPanel.standardOptions;

// Timeseries
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsOverride = tsStandardOptions.override;

// Table
local tbQueryOptions = tablePanel.queryOptions;

{
  local dashboardName = 'django-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = dashboardUtil.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
      ];

      local defaultFilters = dashboardUtil.filters($._config);
      local queries = {
        requestVolume: |||
          round(
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(defaultIgnoredViews)s
                }[$__rate_interval]
              )
            ), 0.001
          )
        ||| % defaultFilters,

        cacheHitrate: |||
          sum (
            rate (
              django_cache_get_hits_total {
                %(default)s
              }[30m]
            )
          ) by (namespace, job)
          /
          sum (
            rate (
              django_cache_get_total {
                %(default)s
              }[30m]
            )
          ) by (namespace, job)
        ||| % defaultFilters,


        dbOps: |||
          sum (
            rate (
              django_db_execute_total {
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job)
        ||| % defaultFilters,

        response2xx: |||
          round(
            sum(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(defaultIgnoredViews)s,
                  status=~"2.*",
                }[$__rate_interval]
              ) > 0
            ) by (job), 0.001
          )
        ||| % defaultFilters,
        response3xx: std.strReplace(queries.response2xx, '2.*', '3.*'),
        response4xx: std.strReplace(queries.response2xx, '2.*', '4.*'),
        response5xx: std.strReplace(queries.response2xx, '2.*', '5.*'),

        dbLatencyP50: |||
          histogram_quantile(0.50,
            sum(
              irate(
                django_db_query_duration_seconds_bucket{
                  %(default)s
                }[$__rate_interval]
              ) > 0
            ) by (vendor, namespace, job, le)
          )
        ||| % defaultFilters,
        dbLatencyP95: std.strReplace(queries.dbLatencyP50, '0.50', '0.95'),
        dbLatencyP99: std.strReplace(queries.dbLatencyP50, '0.50', '0.99'),
        dbLatencyP999: std.strReplace(queries.dbLatencyP50, '0.50', '0.999'),

        dbConnections: |||
          round(
            sum(
              increase(
                django_db_new_connections_total{
                  %(default)s
                }[$__rate_interval]
              ) > 0
            ) by (namespace, job, vendor)
          )
        ||| % defaultFilters,

        migrationsApplied: |||
          max (
            django_migrations_applied_total {
              %(default)s
            }
          ) by (namespace, job)
        ||| % defaultFilters,
        migrationsUnapplied: std.strReplace(queries.migrationsApplied, 'applied', 'unapplied'),

        topDbErrors1w: |||
          round(
            topk(10,
              sum(
                increase(
                  django_db_errors_total{
                    %(default)s
                  }[1w]
                ) > 0
              ) by (type)
            )
          )
        ||| % defaultFilters,

        cacheGetHits: |||
          sum(
            rate(
              django_cache_get_hits_total{
                %(default)s
              }[$__rate_interval]
            ) > 0
          ) by (namespace, job, backend)
        ||| % defaultFilters,
        cacheGetMisses: std.strReplace(queries.cacheGetHits, 'django_cache_get_hits_total', 'django_cache_get_misses_total'),
      };

      local panels = {

        requestVolumeStat:
          dashboardUtil.statPanel(
            'Request Volume',
            'reqps',
            queries.requestVolume,
            'The number of requests received per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        cacheHitrateStat:
          dashboardUtil.statPanel(
            'Cache Hitrate [30m]',
            'percentunit',
            queries.cacheHitrate,
            'The ratio of cache hits to total cache requests over the last 30 minutes. A higher hit rate indicates better cache performance.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        dbOpsStat:
          dashboardUtil.statPanel(
            'Database Ops',
            'ops',
            queries.dbOps,
            'The number of database operations (queries) executed per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        responseTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Responses',
            'reqps',
            [
              {
                expr: queries.response2xx,
                legend: '2xx',
              },
              {
                expr: queries.response3xx,
                legend: '3xx',
              },
              {
                expr: queries.response4xx,
                legend: '4xx',
              },
              {
                expr: queries.response5xx,
                legend: '5xx',
              },
            ],
            description='The number of HTTP responses sent per second, categorized by status code classes.',
            overrides=[
              tsOverride.byName.new('2xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('green')
              ),
              tsOverride.byName.new('3xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('blue')
              ),
              tsOverride.byName.new('4xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('yellow')
              ),
              tsOverride.byName.new('5xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('red')
              ),
            ],
            stack='percent'
          ),

        dbLatencyTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Database Latency',
            's',
            [
              {
                expr: queries.dbLatencyP50,
                legend: '50 - {{ vendor }}',
              },
              {
                expr: queries.dbLatencyP95,
                legend: '95 - {{ vendor }}',
              },
              {
                expr: queries.dbLatencyP99,
                legend: '99 - {{ vendor }}',
              },
              {
                expr: queries.dbLatencyP999,
                legend: '99.9 - {{ vendor }}',
              },
            ],
            description='The latency of database queries at various percentiles, grouped by database vendor. This helps identify performance issues and outliers in database response times.',
          ),

        dbConnectionsTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Database Connections',
            'short',
            queries.dbConnections,
            '{{ vendor }}',
            description='The number of new database connections established, grouped by database vendor. Monitoring connection trends can help identify potential bottlenecks or capacity issues.',
          ),

        migrationsAppliedStat:
          dashboardUtil.statPanel(
            'Migrations Applied',
            'short',
            queries.migrationsApplied,
            'The total number of database migrations that have been applied.',
          ),

        migrationsUnAppliedStat:
          dashboardUtil.statPanel(
            'Migrations Unapplied',
            'short',
            queries.migrationsUnapplied,
            'The total number of database migrations that are pending and have not yet been applied.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('red'),
            ]
          ),

        topDbErrors1wTable:
          dashboardUtil.tablePanel(
            'Top Database Errors (1w)',
            'short',
            queries.topDbErrors1w,
            description='A table displaying the top 10 most frequent database error types over the past week. This helps identify recurring issues that may need attention.',
            sortBy={
              name: 'Type',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    namespace: 'Namespace',
                    job: 'Job',
                    type: 'Type',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    type: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ]
          ),

        cacheGetTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Cache Get Operations',
            'ops',
            [
              {
                expr: queries.cacheGetHits,
                legend: 'Hit - {{ backend }}',
              },
              {
                expr: queries.cacheGetMisses,
                legend: 'Miss - {{ backend }}',
              },
            ],
            description='The number of cache get operations, categorized by hits and misses, grouped by cache backend. This helps assess cache performance and effectiveness.',
            stack='percent'
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.requestVolumeStat,
            panels.dbOpsStat,
            panels.cacheHitrateStat,
          ],
          panelWidth=8,
          panelHeight=4,
          startY=1,
        ) +
        grid.wrapPanels(
          [
            panels.responseTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=5,
        ) +
        [
          row.new('Database') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.migrationsAppliedStat,
            panels.migrationsUnAppliedStat,
          ],
          panelWidth=12,
          panelHeight=3,
          startY=12,
        ) +
        grid.wrapPanels(
          [
            panels.dbConnectionsTimeSeries,
            panels.dbLatencyTimeSeries,
          ],
          panelWidth=12,
          panelHeight=5,
          startY=15,
        ) +
        grid.wrapPanels(
          [
            panels.topDbErrors1wTable,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=20,
        ) +
        [
          row.new('Cache') +
          row.gridPos.withX(0) +
          row.gridPos.withY(28) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.cacheGetTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=29,
        );

      dashboardUtil.bypassDashboardValidation +
      dashboard.new(
        'Django / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache). %s' % dashboardUtil.dashboardDescriptionLink) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        dashboardUtil.dashboardLinks($._config)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        dashboardUtil.annotations($._config, defaultFilters)
      ),
  },
}
