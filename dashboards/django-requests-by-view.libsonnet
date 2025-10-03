local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboardUtil = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local timeSeriesPanel = g.panel.timeSeries;

// Stat
local stStandardOptions = statPanel.standardOptions;

// Timeseries
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsOverride = tsStandardOptions.override;

{
  local dashboardName = 'django-requests-by-view',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = dashboardUtil.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.viewSingle,
        defaultVariables.method,
      ];

      local defaultFilters = dashboardUtil.filters($._config);
      local queries = {
        requestSuccessRate: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(methodSingle)s,
                status!~"[4-5].*"
              }[1w]
            )
          ) /
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(methodSingle)s
              }[1w]
            )
          )
        ||| % defaultFilters,

        requestHttpExceptions: |||
          sum by (view) (
            increase(
              django_http_exceptions_total_by_view_total{
                %(viewSingle)s
              }[1w]
            ) > 0
          )
        ||| % defaultFilters,

        requestLatencyP50Summary: |||
          histogram_quantile(0.50,
            sum (
              rate (
                django_http_requests_latency_seconds_by_view_method_bucket {
                  %(methodSingle)s
                }[$__range]
              )
            ) by (job, le)
          )
        ||| % defaultFilters,

        requestLatencyP95Summary: std.strReplace(queries.requestLatencyP50Summary, '0.50', '0.95'),

        request: |||
          round(
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(viewSingle)s
                }[$__rate_interval]
              ) > 0
            ) by (job), 0.001
          )
        ||| % defaultFilters,

        response2xx: |||
          round(
            sum(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(viewSingle)s,
                  status=~"2.*",
                }[$__rate_interval]
              ) > 0
            ) by (job), 0.001
          )
        ||| % defaultFilters,
        response3xx: std.strReplace(queries.response2xx, '2.*', '3.*'),
        response4xx: std.strReplace(queries.response2xx, '2.*', '4.*'),
        response5xx: std.strReplace(queries.response2xx, '2.*', '5.*'),

        responseStatusCodes: |||
          round(
            sum(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(methodSingle)s
                }[$__rate_interval]
              ) > 0
            ) by (namespace, job, view, status, method), 0.001
          )
        ||| % defaultFilters,

        requestLatencyP50: |||
          histogram_quantile(0.50,
            sum(
              irate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(methodSingle)s
                }[$__rate_interval]
              ) > 0
            ) by (view, le)
          )
        ||| % defaultFilters,
        requestLatencyP95Query: std.strReplace(queries.requestLatencyP50, '0.50', '0.95'),
        requestLatencyP99Query: std.strReplace(queries.requestLatencyP50, '0.50', '0.99'),
        requestLatencyP999Query: std.strReplace(queries.requestLatencyP50, '0.50', '0.999'),
      };

      local panels = {
        requestSuccessRateStat:
          dashboardUtil.statPanel(
            'Success Rate (non 4xx-5xx responses) [1w]',
            'percentunit',
            queries.requestSuccessRate,
            description='The percentage of successful requests (non 4xx-5xx responses) over the last week. A low success rate may indicate issues with the application or server configuration.',
            steps=[
              stStandardOptions.threshold.step.withValue(0.90) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.95) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(0.99) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        requestHttpExceptionsStat:
          dashboardUtil.statPanel(
            'HTTP Exceptions [1w]',
            'short',
            queries.requestHttpExceptions,
            description='The total number of HTTP exceptions (5xx responses) over the last week. A high number of exceptions may indicate issues with the application or server configuration.',
            steps=[
              stStandardOptions.threshold.step.withValue(1) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(10) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(100) +
              stStandardOptions.threshold.step.withColor('red'),
            ],
          ),

        requestLatencyP50SummaryStat:
          dashboardUtil.statPanel(
            'Average Request Latency (P50) [1w]',
            's',
            queries.requestLatencyP50Summary,
            description='The 50th percentile (median) of request latency over the last week. This metric indicates that 50% of requests were served in this time or less.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(1000) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(2000) +
              stStandardOptions.threshold.step.withColor('red'),
            ],
          ),

        requestLatencyP95SummaryStat:
          dashboardUtil.statPanel(
            'Average Request Latency (P95) [1w]',
            's',
            queries.requestLatencyP95Summary,
            description='The 95th percentile of request latency over the last week. This metric indicates that 95% of requests were served in this time or less.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(2500) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(5000) +
              stStandardOptions.threshold.step.withColor('red'),
            ]
          ),

        requestTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Requests',
            'reqps',
            queries.request,
            'reqps',
            description='The total number of requests received by the Django application, broken down by view. This metric helps to understand the traffic patterns and load on different views within the application.',
            stack='normal'
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
            description='The total number of responses sent by the Django application, broken down by status code class (2xx, 3xx, 4xx, 5xx). This metric helps to understand the success and failure rates of requests handled by the application.',
            stack='percent',
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
            ]
          ),

        responseStatusCodesTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Responses Status Codes',
            'reqps',
            queries.responseStatusCodes,
            '{{ view }} / {{ status }} / {{ method }}',
            description='The total number of responses sent by the Django application, broken down by status code, view, and method. This metric provides a detailed view of the response patterns for different views and methods within the application.',
            stack='normal'
          ),

        requestLatencyTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Request Latency',
            's',
            [
              {
                expr: queries.requestLatencyP50,
                legend: '50 - {{ view }}',
              },
              {
                expr: queries.requestLatencyP95Query,
                legend: '95 - {{ view }}',
              },
              {
                expr: queries.requestLatencyP99Query,
                legend: '99 - {{ view }}',
              },
              {
                expr: queries.requestLatencyP999Query,
                legend: '99.9 - {{ view }}',
              },
            ],
            description='The request latency percentiles (50th, 95th, 99th, and 99.9th) for the Django application, broken down by view. This metric helps to understand the performance and responsiveness of different views within the application.',
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
        grid.makeGrid(
          [
            panels.requestSuccessRateStat,
            panels.requestHttpExceptionsStat,
            panels.requestLatencyP50SummaryStat,
            panels.requestLatencyP95SummaryStat,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          row.new('Request & Responses') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.requestTimeSeries,
            panels.responseTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          row.new('Latency & Status Codes') +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.responseStatusCodesTimeSeries,
            panels.requestLatencyTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=15
        );

      dashboardUtil.bypassDashboardValidation +
      dashboard.new(
        'Django / Requests / By View',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on breaking down requests by view. %s' % dashboardUtil.dashboardDescriptionLink) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
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
