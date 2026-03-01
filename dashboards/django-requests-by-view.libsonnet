local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboardUtil = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;
local query = dashboard.variable.query;

local timeSeriesPanel = g.panel.timeSeries;

// Timeseries
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsOverride = tsStandardOptions.override;

{
  local dashboardName = 'django-requests-by-view',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = dashboardUtil.variables($._config);

      local viewNoAll =
        defaultVariables.view +
        query.selectionOptions.withIncludeAll(false);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        viewNoAll,
        defaultVariables.method,
      ];

      local defaultFilters = dashboardUtil.filters($._config);
      local queries = {
        requestByMethod1h: |||
          sum(
            rate(
              django_http_requests_total_by_view_transport_method_total{
                %(defaultIgnoredViews)s
              }[1h]
            )
          ) by (method)
        ||| % defaultFilters,

        responseByStatusCode1h: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(defaultIgnoredViews)s,
                %(methodV)s
              }[1h]
            )
          ) by (status)
        ||| % defaultFilters,

        requestByView1h: |||
          sum(
            rate(
              django_http_requests_total_by_view_transport_method_total{
                %(defaultIgnoredViews)s,
                %(methodV)s
              }[1h]
            )
          ) by (view)
        ||| % defaultFilters,

        requestTotalRaw: |||
          round(
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(method)s
                }[$__rate_interval]
              ) > 0
            ) by (job), 0.001
          )
        ||| % defaultFilters,

        requestTotal: queries.requestTotalRaw,

        requestTotal1hAverage: |||
          avg_over_time(
            (
              sum(
                rate(
                  django_http_requests_total_by_view_transport_method_total{
                    %(method)s
                  }[$__rate_interval]
                )
              ) by (job)
            )[1h:]
          )
        ||| % defaultFilters,

        requestTotal1dAverage: |||
          avg_over_time(
            (
              sum(
                rate(
                  django_http_requests_total_by_view_transport_method_total{
                    %(method)s
                  }[$__rate_interval]
                )
              ) by (job)
            )[1d:]
          )
        ||| % defaultFilters,

        requestTotalVs1hAveragePercent: |||
          (%s / clamp_min(%s, 0.001)) * 100
        ||| % [queries.requestTotalRaw, queries.requestTotal1hAverage],

        requestTotalVs1dAveragePercent: |||
          (%s / clamp_min(%s, 0.001)) * 100
        ||| % [queries.requestTotalRaw, queries.requestTotal1dAverage],

        requestTotal1wAgo: |||
          round(
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(method)s
                }[$__rate_interval] offset 1w
              ) > 0
            ) by (job), 0.001
          )
        ||| % defaultFilters,

        requestLatencyTotalP50: |||
          histogram_quantile(0.50,
            sum(
              rate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(method)s
                }[$__rate_interval]
              )
            ) by (job, le)
          )
        ||| % defaultFilters,
        requestLatencyTotalP95: std.strReplace(queries.requestLatencyTotalP50, '0.50', '0.95'),
        requestLatencyTotalP99: std.strReplace(queries.requestLatencyTotalP50, '0.50', '0.99'),

        requestLatencyTotalP50_1wAgo: |||
          histogram_quantile(0.50,
            sum(
              rate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(method)s
                }[$__rate_interval] offset 1w
              )
            ) by (job, le)
          )
        ||| % defaultFilters,
        requestLatencyTotalP95_1wAgo: std.strReplace(queries.requestLatencyTotalP50_1wAgo, '0.50', '0.95'),
        requestLatencyTotalP99_1wAgo: std.strReplace(queries.requestLatencyTotalP50_1wAgo, '0.50', '0.99'),

        requestSuccessRate5xx: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(method)s,
                status!~"5.*"
              }[$__rate_interval]
            )
          ) /
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(method)s
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        requestSuccessRate4xx: |||
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(method)s,
                status!~"[4-5].*"
              }[$__rate_interval]
            )
          ) /
          sum(
            rate(
              django_http_responses_total_by_status_view_method_total{
                %(method)s
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        response2xx: |||
          round(
            sum(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(method)s,
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
                  %(method)s
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
                  %(method)s
                }[$__rate_interval]
              ) > 0
            ) by (view, le)
          )
        ||| % defaultFilters,
        requestLatencyP95Query: std.strReplace(queries.requestLatencyP50, '0.50', '0.95'),
        requestLatencyP99Query: std.strReplace(queries.requestLatencyP50, '0.50', '0.99'),
      };

      local panels = {
        requestTotalTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Request Total',
            'reqps',
            queries.requestTotal,
            legend='{{ job }}',
            description='Current request rate for the selected view and method.',
            stack='normal'
          ),

        latencyTotalTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Latency Total',
            's',
            [
              {
                expr: queries.requestLatencyTotalP50,
                legend: 'P50',
              },
              {
                expr: queries.requestLatencyTotalP95,
                legend: 'P95',
              },
              {
                expr: queries.requestLatencyTotalP99,
                legend: 'P99',
                exemplar: true,
              },
            ],
            description='Current request latency percentiles for the selected view and method.',
          ),

        requestTotal1wAgoTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Request Total (1 Week Ago)',
            'reqps',
            queries.requestTotal1wAgo,
            legend='{{ job }}',
            description='Request rate shifted by one week for baseline comparison.',
            stack='normal'
          ),

        latencyTotal1wAgoTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Latency Total (1 Week Ago)',
            's',
            [
              {
                expr: queries.requestLatencyTotalP50_1wAgo,
                legend: 'P50 (1w ago)',
              },
              {
                expr: queries.requestLatencyTotalP95_1wAgo,
                legend: 'P95 (1w ago)',
              },
              {
                expr: queries.requestLatencyTotalP99_1wAgo,
                legend: 'P99 (1w ago)',
                exemplar: true,
              },
            ],
            description='Latency percentiles shifted by one week for baseline comparison.',
          ),

        requestTotalVs1hAverageTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Request Rate vs 1-Hour Average',
            'percent',
            queries.requestTotalVs1hAveragePercent,
            legend='{{ job }}',
            description='Current request rate as a percentage of the trailing 1-hour average (100%% = same, 110%% = +10%%).'
          ),

        requestTotalVs1dAverageTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Request Rate vs 1-Day Average',
            'percent',
            queries.requestTotalVs1dAveragePercent,
            legend='{{ job }}',
            description='Current request rate as a percentage of the trailing 1-day average (100%% = same, 110%% = +10%%).'
          ),

        successRate5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Success Rate (Excluding Client Errors 4xx)',
            'percentunit',
            queries.requestSuccessRate5xx,
            legend='Success Rate',
            description='Success rate where only 5xx are treated as failures.',
            min=0,
            max=1,
          ),

        successRate4xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Success Rate (Including Client Errors 4xx)',
            'percentunit',
            queries.requestSuccessRate4xx,
            legend='Success Rate',
            description='Success rate where 4xx and 5xx are treated as failures.',
            min=0,
            max=1,
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
            description='Response rate split by status class for the selected view.',
            stack='percent',
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

        responseStatusCodesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Responses Status Codes',
            'reqps',
            queries.responseStatusCodes,
            legend='{{ status }} / {{ method }}',
            description='Detailed response rate by status code and method for the selected view.',
            stack='normal'
          ),

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
                expr: queries.requestLatencyP95Query,
                legend: 'P95',
              },
              {
                expr: queries.requestLatencyP99Query,
                legend: 'P99',
                exemplar: true,
              },
            ],
            description='Request latency percentiles for the selected view.',
          ),

        requestByMethod1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Request Distribution by Method [1h]',
            'reqps',
            queries.requestByMethod1h,
            '{{ method }}',
            description='Traffic split by HTTP method for the selected view over the last hour.',
          ),

        responseByStatusCode1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Response Distribution by Status Code [1h]',
            'reqps',
            queries.responseByStatusCode1h,
            '{{ status }}',
            description='Response split by exact status code over the last hour.',
          ),

        requestByView1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Request Distribution by View [1h]',
            'reqps',
            queries.requestByView1h,
            '{{ view }}',
            description='Traffic split by Django view over the last hour.',
          ),
      };

      local rows =
        [
          row.new('Summary [1h]') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.requestByView1hPieChart,
            panels.requestByMethod1hPieChart,
            panels.responseByStatusCode1hPieChart,
          ],
          panelWidth=8,
          panelHeight=5,
          startY=1
        ) +
        [
          row.new('View: $view / Method: $method') +
          row.gridPos.withX(0) +
          row.gridPos.withY(6) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withRepeat('view'),
        ] +
        grid.wrapPanels(
          [
            panels.requestTotalTimeSeries,
            panels.latencyTotalTimeSeries,
            panels.requestTotal1wAgoTimeSeries,
            panels.latencyTotal1wAgoTimeSeries,
            panels.successRate5xxTimeSeries,
            panels.successRate4xxTimeSeries,
            panels.requestTotalVs1dAverageTimeSeries,
            panels.requestTotalVs1hAverageTimeSeries,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=7
        );

      mixinUtils.dashboards.bypassDashboardValidation +
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
