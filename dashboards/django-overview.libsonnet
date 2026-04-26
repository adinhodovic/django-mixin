local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
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

        requestSuccessRateExcluding5xx: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(defaultIgnoredViews)s,
                status!~"5.*"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(defaultIgnoredViews)s
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        requestSuccessRateIncluding4xx: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(defaultIgnoredViews)s,
                status!~"[4-5].*"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(defaultIgnoredViews)s
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        requestLatencyP50: |||
          histogram_quantile(0.50,
            sum(
              rate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(defaultIgnoredViews)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % defaultFilters,
        requestLatencyP95: std.strReplace(queries.requestLatencyP50, '0.50', '0.95'),
        requestLatencyP99: std.strReplace(queries.requestLatencyP50, '0.50', '0.99'),

        requestHttpExceptions1h: |||
          round(
            sum(
              increase(
                django_http_exceptions_total_by_view_total{
                  %(defaultIgnoredViews)s
                }[1h]
              )
            ), 0.001
          )
        ||| % defaultFilters,

        requestByMethod1h: |||
          sum(
            rate(
              django_http_requests_total_by_view_transport_method_total{
                %(defaultIgnoredViews)s
              }[1h]
            )
          ) by (method)
        ||| % defaultFilters,

        responseByStatusClass1h: |||
          sum by (status_class) (
            label_replace(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(defaultIgnoredViews)s
                }[1h]
              ),
              "status_class",
              "${1}xx",
              "status",
              "([0-9]).*"
            )
          )
        ||| % defaultFilters,

        requestByView1h: |||
          topk(10,
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(defaultIgnoredViews)s
                }[1h]
              )
            ) by (view)
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

        dbOpsByVendor1h: |||
          sum(
            rate(
              django_db_execute_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, vendor)
        ||| % defaultFilters,

        dbNewConnectionErrors: |||
          sum(
            rate(
              django_db_new_connection_errors_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, vendor)
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
              rate(
                django_db_query_duration_seconds_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (vendor, namespace, job, le)
          )
        ||| % defaultFilters,
        dbLatencyP95: std.strReplace(queries.dbLatencyP50, '0.50', '0.95'),
        dbLatencyP99: std.strReplace(queries.dbLatencyP50, '0.50', '0.99'),

        dbConnections: |||
          round(
            sum(
              rate(
                django_db_new_connections_total{
                  %(default)s
                }[$__rate_interval]
              )
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
                )
              ) by (namespace, job, type)
            )
          )
        ||| % defaultFilters,

        cacheGetHits: |||
          sum(
            rate(
              django_cache_get_hits_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, backend)
        ||| % defaultFilters,
        cacheGetMisses: std.strReplace(queries.cacheGetHits, 'django_cache_get_hits_total', 'django_cache_get_misses_total'),
        cacheGetFailures: std.strReplace(queries.cacheGetHits, 'django_cache_get_hits_total', 'django_cache_get_fail_total'),
        cacheHitRateByBackend: |||
          sum(
            rate(
              django_cache_get_hits_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, backend)
          /
          sum(
            rate(
              django_cache_get_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (namespace, job, backend)
        ||| % defaultFilters,
      };

      local panels = {

        requestVolumeStat:
          mixinUtils.dashboards.statPanel(
            'Request Volume',
            'reqps',
            queries.requestVolume,
            description='The number of requests received per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        cacheHitrateStat:
          mixinUtils.dashboards.statPanel(
            'Cache Hitrate [30m]',
            'percentunit',
            queries.cacheHitrate,
            description='The ratio of cache hits to total cache requests over the last 30 minutes. A higher hit rate indicates better cache performance.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        requestSuccessRateExcluding5xxStat:
          mixinUtils.dashboards.statPanel(
            'Success Rate (Excluding 4xx)',
            'percentunit',
            queries.requestSuccessRateExcluding5xx,
            description='Request success rate that treats client-side 4xx responses as successful. Drops usually point to Django, dependency, or infrastructure failures.',
            steps=[
              stStandardOptions.threshold.step.withValue(0.90) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.95) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(0.99) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        requestSuccessRateIncluding4xxStat:
          mixinUtils.dashboards.statPanel(
            'Success Rate (Including 4xx)',
            'percentunit',
            queries.requestSuccessRateIncluding4xx,
            description='Strict request success rate that counts both 4xx and 5xx responses as failures. Use this as an end-user health signal.',
            steps=[
              stStandardOptions.threshold.step.withValue(0.90) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.95) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(0.99) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        requestLatencyP95Stat:
          mixinUtils.dashboards.statPanel(
            'Request Latency (P95)',
            's',
            queries.requestLatencyP95,
            description='95th percentile Django request latency across the selected namespace and job.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(1) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(3) +
              stStandardOptions.threshold.step.withColor('red'),
            ],
          ),

        requestHttpExceptions1hStat:
          mixinUtils.dashboards.statPanel(
            'HTTP Exceptions [1h]',
            'short',
            queries.requestHttpExceptions1h,
            description='Total Django HTTP exceptions over the last hour. Non-zero values indicate views raising exceptions before normal response handling.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(1) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(10) +
              stStandardOptions.threshold.step.withColor('red'),
            ],
          ),

        dbOpsStat:
          mixinUtils.dashboards.statPanel(
            'Database Ops',
            'ops',
            queries.dbOps,
            description='The number of database operations (queries) executed per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        responseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
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
            stack='percent'
          ) +
          tsStandardOptions.withOverrides([
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
          ]),

        requestLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Request Latency',
            's',
            [
              {
                expr: queries.requestLatencyP50,
                legend: 'P50',
              },
              {
                expr: queries.requestLatencyP95,
                legend: 'P95',
              },
              {
                expr: queries.requestLatencyP99,
                legend: 'P99',
                exemplar: true,
              },
            ],
            description='Django request latency percentiles. Watch P95/P99 for slow views or dependency bottlenecks that are hidden by median latency.',
          ),

        requestByMethod1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Request Distribution by Method [1h]',
            'reqps',
            queries.requestByMethod1h,
            '{{ method }}',
            description='Traffic split by HTTP method over the last hour. Unexpected method mix changes can indicate client or routing changes.',
          ),

        responseByStatusClass1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Response Distribution by Status Class [1h]',
            'reqps',
            queries.responseByStatusClass1h,
            '{{ status_class }}',
            description='Response split by status code class over the last hour. Use this to quickly spot elevated 4xx or 5xx traffic.',
          ),

        requestByView1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Top View Traffic Share [1h]',
            'reqps',
            queries.requestByView1h,
            '{{ view }}',
            description='Top Django views by request volume over the last hour.',
          ),

        dbLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
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
            ],
            description='The latency of database queries at various percentiles, grouped by database vendor. This helps identify performance issues and outliers in database response times.',
          ),

        dbConnectionsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Database Connections',
            'short',
            queries.dbConnections,
            legend='{{ vendor }}',
            description='The number of new database connections established, grouped by database vendor. Monitoring connection trends can help identify potential bottlenecks or capacity issues.',
          ),

        migrationsAppliedStat:
          mixinUtils.dashboards.statPanel(
            'Migrations Applied',
            'short',
            queries.migrationsApplied,
            description='The total number of database migrations that have been applied.',
          ),

        migrationsUnAppliedStat:
          mixinUtils.dashboards.statPanel(
            'Migrations Unapplied',
            'short',
            queries.migrationsUnapplied,
            description='The total number of database migrations that are pending and have not yet been applied.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('red'),
            ]
          ),

        topDbErrors1wTable:
          mixinUtils.dashboards.tablePanel(
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

        dbOpsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Database Operations',
            'ops',
            queries.dbOpsByVendor1h,
            '{{ vendor }}',
            description='Database query operation rate by vendor. Use this with latency and connection panels to spot load-driven database regressions.',
            stack='normal'
          ),

        dbNewConnectionErrorsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Database New Connection Errors',
            'ops',
            queries.dbNewConnectionErrors,
            '{{ vendor }}',
            description='Rate of failed database connection attempts by vendor. Non-zero values usually indicate database availability, credentials, network, or pool exhaustion issues.',
            stack='normal'
          ),

        cacheGetTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Cache Operations',
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
              {
                expr: queries.cacheGetFailures,
                legend: 'Fail - {{ backend }}',
              },
            ],
            description='Cache get operation rate by backend, split into hits, misses, and failures. Rising misses can explain increased database load; failures indicate cache backend or client errors.',
            stack='normal'
          ),

        cacheHitRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Cache Hit Rate',
            'percentunit',
            queries.cacheHitRateByBackend,
            '{{ backend }}',
            description='Cache hit rate by backend. Lower values mean more cache lookups are falling through to downstream work such as database queries.',
            min=0,
            max=1
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
            panels.requestSuccessRateExcluding5xxStat,
            panels.requestSuccessRateIncluding4xxStat,
            panels.requestLatencyP95Stat,
            panels.dbOpsStat,
            panels.cacheHitrateStat,
          ],
          panelWidth=4,
          panelHeight=3,
          startY=1,
        ) +
        grid.wrapPanels(
          [
            panels.requestByMethod1hPieChart,
            panels.responseByStatusClass1hPieChart,
            panels.requestByView1hPieChart,
          ],
          panelWidth=8,
          panelHeight=6,
          startY=4,
        ) +
        [
          row.new('Requests') +
          row.gridPos.withX(0) +
          row.gridPos.withY(10) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.responseTimeSeries,
            panels.requestLatencyTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=11,
        ) +
        [
          row.new('Database') +
          row.gridPos.withX(0) +
          row.gridPos.withY(19) +
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
          startY=20,
        ) +
        grid.wrapPanels(
          [
            panels.dbConnectionsTimeSeries,
            panels.dbLatencyTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=23,
        ) +
        grid.wrapPanels(
          [
            panels.dbOpsTimeSeries,
            panels.dbNewConnectionErrorsTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=31,
        ) +
        grid.wrapPanels(
          [
            panels.topDbErrors1wTable,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=39,
        ) +
        [
          row.new('Cache') +
          row.gridPos.withX(0) +
          row.gridPos.withY(47) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.cacheGetTimeSeries,
            panels.cacheHitRateTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=48,
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Django / Overview',
      ) +
      dashboard.withDescription('A landing dashboard for Django services with request health, latency, database activity, cache effectiveness, and drill-down links into high-traffic views. Use it to spot application-wide regressions before moving into the request, view, or model dashboards. %s' % dashboardUtil.dashboardDescriptionLink) +
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
