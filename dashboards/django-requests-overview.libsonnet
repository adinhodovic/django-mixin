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
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'django-requests-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = dashboardUtil.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.view,
        defaultVariables.method,
      ];

      local defaultFilters = dashboardUtil.filters($._config);
      local queries = {

        requestVolume: |||
          round(
            sum(
              rate(
                django_http_requests_total_by_view_transport_method_total{
                  %(method)s
                }[$__rate_interval]
              )
            ), 0.001
          )
        ||| % defaultFilters,

        requestSuccessRate: |||
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
                %(method)s,
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        requestBytesP95: |||
          histogram_quantile(0.95,
            sum (
              rate (
                django_http_requests_body_total_bytes_bucket {
                  %(default)s
                }[$__rate_interval]
              )
            ) by (job, le)
          )
        ||| % defaultFilters,

        requestLatencyP95Summary: |||
          histogram_quantile(0.95,
            sum (
              irate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(view)s
                }[$__rate_interval]
              )
            ) by (job, le)
          )
        ||| % defaultFilters,

        apiResponse2xx: |||
          round(
            sum(
              rate(
                django_http_responses_total_by_status_view_method_total{
                  %(method)s,
                  status=~"2.*",
                  view!~"%(adminViewRegex)s",
                }[$__rate_interval]
              ) > 0
            ) by (namespace, job, view), 0.001
          )
        ||| % defaultFilters,
        apiResponse4xx: std.strReplace(queries.apiResponse2xx, '2.*', '4.*'),
        apiResponse5xx: std.strReplace(queries.apiResponse2xx, '2.*', '5.*'),

        apiRequestLatencyP50: |||
          histogram_quantile(0.50,
            sum(
              rate(
                django_http_requests_latency_seconds_by_view_method_bucket{
                  %(method)s,
                  view!~"%(adminViewRegex)s"
                }[1h]
              ) > 0
            ) by (namespace, job, view, le)
          )
        ||| % defaultFilters,
        apiRequestLatencyP95: std.strReplace(queries.apiRequestLatencyP50, '0.50', '0.95'),
        apiRequestLatencyP99: std.strReplace(queries.apiRequestLatencyP50, '0.50', '0.99'),

        adminResponse2xx: std.strReplace(queries.apiResponse2xx, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
        adminResponse4xx: std.strReplace(queries.apiResponse4xx, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
        adminResponse5xx: std.strReplace(queries.apiResponse5xx, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),

        adminRequestLatencyP50: std.strReplace(queries.apiRequestLatencyP50, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
        adminRequestLatencyP95: std.strReplace(queries.apiRequestLatencyP95, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
        adminRequestLatencyP99: std.strReplace(queries.apiRequestLatencyP99, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),

        topHttpExceptionsByView1w: |||
          round(
            topk(10,
              sum by (namespace, job, view) (
                increase(
                  django_http_exceptions_total_by_view_total{
                    %(defaultIgnoredViews)s
                  }[1w]
                ) > 0
              )
            )
          )
        ||| % defaultFilters,

        topHttpExceptionsByType1w: |||
          round(
            topk(10,
              sum(
                increase(
                  django_http_exceptions_total_by_type_total{
                    %(default)s
                  }[1w]
                ) > 0
              ) by (namespace, job, type)
            )
          )
        ||| % defaultFilters,

        topResponseByView1w: |||
          round(
            topk(10,
              sum(
                increase(
                  django_http_responses_total_by_status_view_method_total{
                    %(defaultIgnoredViews)s
                  }[1w]
                ) > 0
              ) by (namespace, job, view)
            )
          )
        ||| % defaultFilters,

        topTemplates1w: |||
          topk(10,
            round(
              sum(
                increase(
                  django_http_responses_total_by_templatename_total{
                    %(default)s,
                    templatename!~"%(djangoIgnoredTemplates)s"
                  }[1w]
                ) > 0
              ) by (namespace, job, templatename)
            )
          )
        ||| % defaultFilters,
      };

      local panels = {

        requestVolumeStat:
          dashboardUtil.statPanel(
            'Request Volume',
            'reqps',
            queries.requestVolume,
          ),

        requestSuccessRateStat:
          dashboardUtil.statPanel(
            'Success Rate (non 4-5xx responses)',
            'percentunit',
            queries.requestSuccessRate,
            mappings=[
              stStandardOptions.threshold.step.withValue(0.90) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.95) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(0.99) +
              stStandardOptions.threshold.step.withColor('green'),
            ],
          ),

        requestBytesStat:
          dashboardUtil.statPanel(
            'Request Body Size (P95)',
            'decbytes',
            queries.requestBytesP95,
            description='95th percentile of request body size',
            mappings=[
              stStandardOptions.threshold.step.withValue(0.1) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.2) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(0.3) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        requestLatencyP95SummaryStat:
          dashboardUtil.statPanel(
            'Request Latency (P95)',
            's',
            queries.requestLatencyP95Summary,
            description='95th percentile of request latency',
            mappings=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(2500) +
              stStandardOptions.threshold.step.withColor('yellow'),
              stStandardOptions.threshold.step.withValue(5000) +
              stStandardOptions.threshold.step.withColor('red'),
            ],
          ),

        apiResponseTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'API & Other Views Response Status',
            'reqps',
            [
              {
                expr: queries.apiResponse2xx,
                legend: '{{ view }} / 2xx',
                color: 'green',
              },
              {
                expr: queries.apiResponse4xx,
                legend: '{{ view }} / 4xx',
                color: 'yellow',
              },
              {
                expr: queries.apiResponse5xx,
                legend: '{{ view }} / 5xx',
                color: 'red',
              },
            ],
            stack='normal',
            description='Response status codes for API and other views (non-admin)',
            overrides=[
              tsOverride.byName.new('2xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('green')
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
          ),

        apiRequestLatencyTable:
          dashboardUtil.tablePanel(
            'API & Other Views Request Latency [1h]',
            'dtdurations',
            [
              {
                expr: queries.apiRequestLatencyP50,
                legend: 'P50 Latency',
              },
              {
                expr: queries.apiRequestLatencyP95,
                legend: 'P95 Latency',
              },
              {
                expr: queries.apiRequestLatencyP99,
                legend: 'P99 Latency',
              },
            ],
            sortBy={
              name: 'P50 Latency',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
                    view: 'View',
                    'Value #A': 'P50 Latency',
                    'Value #B': 'P95 Latency',
                    'Value #C': 'P99 Latency',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    view: 2,
                    'Value #A': 3,
                    'Value #B': 4,
                    'Value #C': 5,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('View') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To View') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    '/d/%s?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.dashboardIds['django-requests-by-view']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ],
          ),

        adminResponseTimeSeries:
          dashboardUtil.timeSeriesPanel(
            'Admin Views Response Status',
            'reqps',
            [
              {
                expr: queries.adminResponse2xx,
                legend: '{{ view }} / 2xx',
              },
              {
                expr: queries.adminResponse4xx,
                legend: '{{ view }} / 4xx',
              },
              {
                expr: queries.adminResponse5xx,
                legend: '{{ view }} / 5xx',
              },
            ],
            stack='normal',
            description='Response status codes for admin views',
            overrides=[
              tsOverride.byName.new('2xx') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('green')
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

        adminRequestLatencyTable:
          dashboardUtil.tablePanel(
            'Admin Views Request Latency [1h]',
            'dtdurations',
            [
              {
                expr: queries.adminRequestLatencyP50,
                legend: 'P50 Latency',
              },
              {
                expr: queries.adminRequestLatencyP95,
                legend: 'P95 Latency',
              },
              {
                expr: queries.adminRequestLatencyP99,
                legend: 'P99 Latency',
              },
            ],
            sortBy={
              name: 'P50 Latency',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
                    view: 'View',
                    'Value #A': 'P50 Latency',
                    'Value #B': 'P95 Latency',
                    'Value #C': 'P99 Latency',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    view: 2,
                    'Value #A': 3,
                    'Value #B': 4,
                    'Value #C': 5,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('View') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To View') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    '/d/%s?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.dashboardIds['django-requests-by-view']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ],
          ),

        topHttpExceptionsByView1wTable:
          dashboardUtil.tablePanel(
            'Top Exceptions by View (1w)',
            'short',
            queries.topHttpExceptionsByView1w,
            sortBy={
              name: 'Value',
              desc: true,
            },
            description='Top 10 views that raised exceptions in the last 7 days',
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
                    view: 'View',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    view: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('View') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To View') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    '/d/%s?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.dashboardIds['django-requests-by-view']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ]
          ),

        topHttpExceptionsByType1wTable:
          dashboardUtil.tablePanel(
            'Top Exceptions by Type (1w)',
            'short',
            queries.topHttpExceptionsByType1w,
            sortBy={
              name: 'Value',
              desc: true,
            },
            description='Top 10 exception types that were raised in the last 7 days',
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
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
            ],
          ),

        topResponseByView1wTable:
          dashboardUtil.tablePanel(
            'Top Responses by View (1w)',
            'short',
            queries.topResponseByView1w,
            sortBy={
              name: 'Value',
              desc: true,
            },
            description='Top 10 views by number of responses in the last 7 days',
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
                    view: 'View',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    view: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('View') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To View') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    '/d/%s?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.dashboardIds['django-requests-by-view']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ],
          ),

        topTemplates1wTable:
          dashboardUtil.tablePanel(
            'Top Templates (1w)',
            'short',
            queries.topTemplates1w,
            description='Top 10 templates rendered in the last 7 days',
            sortBy={
              name: 'Value',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    namespace: 'Namespace',
                    templatename: 'Template Name',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    templatename: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ]
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
            panels.requestSuccessRateStat,
            panels.requestLatencyP95SummaryStat,
            panels.requestBytesStat,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1,
        ) +
        [
          row.new('API Views & Other') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.apiResponseTimeSeries,
            panels.apiRequestLatencyTable,
          ],
          panelWidth=12,
          panelHeight=10,
          startY=6,
        ) +
        [
          row.new('Admin Views') +
          row.gridPos.withX(0) +
          row.gridPos.withY(16) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.adminResponseTimeSeries,
            panels.adminRequestLatencyTable,
          ],
          panelWidth=12,
          panelHeight=10,
          startY=17,
        ) +
        [
          row.new('Weekly Breakdown') +
          row.gridPos.withX(0) +
          row.gridPos.withY(26) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.topHttpExceptionsByView1wTable,
            panels.topHttpExceptionsByType1wTable,
            panels.topResponseByView1wTable,
            panels.topTemplates1wTable,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=27,
        );

      dashboardUtil.bypassDashboardValidation +
      dashboard.new(
        'Django / Requests / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on giving a overview for requests. %s' % dashboardUtil.dashboardDescriptionLink) +
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
