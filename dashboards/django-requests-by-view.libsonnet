local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

local statPanel = g.panel.stat;
local timeSeriesPanel = g.panel.timeSeries;

// Stat
local stOptions = statPanel.options;
local stStandardOptions = statPanel.standardOptions;
local stQueryOptions = statPanel.queryOptions;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;
local tsOverride = tsStandardOptions.override;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: $._config.datasourceName,
          value: $._config.datasourceName,
        },
      },

    local clusterVariable =
      query.new(
        $._config.clusterLabel,
        'label_values(django_http_responses_total_by_status_view_method_total{}, cluster)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if $._config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(django_http_responses_total_by_status_view_method_total{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local jobVariable =
      query.new(
        'job',
        'label_values(django_http_responses_total_by_status_view_method_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}, job)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local defaultFilters = 'namespace=~"$namespace", job=~"$job"',

    local viewVariable =
      query.new(
        'view',
        'label_values(django_http_responses_total_by_status_view_method_total{%(clusterLabel)s="$cluster", %s, view!~"%s"}, view)' % [$._config.clusterLabel, defaultFilters, $._config.djangoIgnoredViews],
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('View') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local methodVariable =
      query.new(
        'method',
        'label_values(django_http_responses_total_by_status_view_method_total{%(clusterLabel)s="$cluster", %s, view=~"$view"}, method)' % [$._config.clusterLabel, defaultFilters],
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Method') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      clusterVariable,
      namespaceVariable,
      jobVariable,
      viewVariable,
      methodVariable,
    ],

    local requestSuccessRateQuery = |||
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            %(clusterLabel)s="$cluster",
            namespace=~"$namespace",
            job=~"$job",
            view="$view",
            method=~"$method",
            status!~"[4-5].*"
          }[1w]
        )
      ) /
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            %(clusterLabel)s="$cluster",
            namespace=~"$namespace",
            job=~"$job",
            view="$view",
            method=~"$method"
          }[1w]
        )
      )
    ||| % $._config,

    local requestSuccessRateStatPanel =
      statPanel.new(
        'Success Rate (non 4xx-5xx responses) [1w]',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestSuccessRateQuery,
        )
      ) +
      stStandardOptions.withUnit('percentunit') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.90) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.95) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(0.99) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local requestHttpExceptionsQuery = |||
      sum by (view) (
        increase(
          django_http_exceptions_total_by_view_total{
            %(clusterLabel)s="$cluster",
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
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestHttpExceptionsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(1) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(10) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(100) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local requestLatencyP50SummaryQuery = |||
      histogram_quantile(0.50,
        sum (
          rate (
            django_http_requests_latency_seconds_by_view_method_bucket {
              %(clusterLabel)s="$cluster",
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
      ) +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestLatencyP50SummaryQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('s') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(1000) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(2000) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local requestLatencyP95SummaryQuery = std.strReplace(requestLatencyP50SummaryQuery, '0.50', '0.95'),

    local requestLatencyP95SummaryStatPanel =
      statPanel.new(
        'Average Request Latency (P95) [1w]',
      ) +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestLatencyP95SummaryQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('s') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(2500) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(5000) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local requestQuery = |||
      round(
        sum(
          rate(
            django_http_requests_total_by_view_transport_method_total{
              %(clusterLabel)s="$cluster",
              namespace=~"$namespace",
              job=~"$job",
              view="$view"
            }[$__rate_interval]
          ) > 0
        ) by (job), 0.001
      )
    ||| % $._config,

    local requestTimeSeriesPanel =
      timeSeriesPanel.new(
        'Requests',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestQuery,
        ) +
        prometheus.withLegendFormat(
          'reqps'
        )
      ) +
      tsStandardOptions.withUnit('reqps') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local response2xxQuery = |||
      round(
        sum(
          rate(
            django_http_responses_total_by_status_view_method_total{
              %(clusterLabel)s="$cluster",
              namespace=~"$namespace",
              job=~"$job",
              view="$view",
              status=~"2.*",
            }[$__rate_interval]
          ) > 0
        ) by (job), 0.001
      )
    ||| % $._config,
    local response3xxQuery = std.strReplace(response2xxQuery, '2.*', '3.*'),
    local response4xxQuery = std.strReplace(response2xxQuery, '2.*', '4.*'),
    local response5xxQuery = std.strReplace(response2xxQuery, '2.*', '5.*'),

    local responseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Responses',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            response2xxQuery,
          ) +
          prometheus.withLegendFormat(
            '2xx'
          ),
          prometheus.new(
            '$datasource',
            response3xxQuery,
          ) +
          prometheus.withLegendFormat(
            '3xx'
          ),
          prometheus.new(
            '$datasource',
            response4xxQuery,
          ) +
          prometheus.withLegendFormat(
            '4xx'
          ),
          prometheus.new(
            '$datasource',
            response5xxQuery,
          ) +
          prometheus.withLegendFormat(
            '5xx'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('reqps') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
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
      ]) +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('percent') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local responseStatusCodesQuery = |||
      round(
        sum(
          rate(
            django_http_responses_total_by_status_view_method_total{
              %(clusterLabel)s="$cluster",
              namespace=~"$namespace",
              job=~"$job",
              view="$view",
              method=~"$method",
            }[$__rate_interval]
          ) > 0
        ) by (namespace, job, view, status, method), 0.001
      )
    ||| % $._config,


    local responseStatusCodesTimeSeriesPanel =
      timeSeriesPanel.new(
        'Responses Status Codes',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          responseStatusCodesQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ view }} / {{ status }} / {{ method }}',
        )
      ) +
      tsStandardOptions.withUnit('reqps') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local requestLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          irate(
            django_http_requests_latency_seconds_by_view_method_bucket{
              %(clusterLabel)s="$cluster",
              namespace=~"$namespace",
              job=~"$job",
              view="$view",
              method=~"$method"
            }[$__rate_interval]
          ) > 0
        ) by (view, le)
      )
    ||| % $._config,
    local requestLatencyP95Query = std.strReplace(requestLatencyP50Query, '0.50', '0.95'),
    local requestLatencyP99Query = std.strReplace(requestLatencyP50Query, '0.50', '0.99'),
    local requestLatencyP999Query = std.strReplace(requestLatencyP50Query, '0.50', '0.999'),

    local requestLatencyTimeSeriesPanel =
      timeSeriesPanel.new(
        'Request Latency',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            requestLatencyP50Query,
          ) +
          prometheus.withLegendFormat(
            '50 - {{ view }}',
          ),
          prometheus.new(
            '$datasource',
            requestLatencyP95Query,
          ) +
          prometheus.withLegendFormat(
            '95 - {{ view }}',
          ),
          prometheus.new(
            '$datasource',
            requestLatencyP99Query,
          ) +
          prometheus.withLegendFormat(
            '99 - {{ view }}',
          ),
          prometheus.new(
            '$datasource',
            requestLatencyP999Query,
          ) +
          prometheus.withLegendFormat(
            '99.9 - {{ view }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10) +
      tsCustom.withSpanNulls(false),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local requestResponseRow =
      row.new(
        title='Request & Responses'
      ),

    local latencyStatusCodesRow =
      row.new(
        title='Latency & Status Codes'
      ),

    'django-requests-by-view.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Django / Requests / By View',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on breaking down requests by view. It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).') +
      dashboard.withUid($._config.requestsByViewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('Django Dashboards', $._config.tags) +
          dashboard.link.link.options.withTargetBlank(true) +
          dashboard.link.link.options.withAsDropdown(true) +
          dashboard.link.link.options.withIncludeVars(true) +
          dashboard.link.link.options.withKeepTime(true),
        ]
      ) +
      dashboard.withPanels(
        [
          summaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            requestSuccessRateStatPanel,
            requestHttpExceptionsStatPanel,
            requestLatencyP50SummaryStatPanel,
            requestLatencyP95SummaryStatPanel,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          requestResponseRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            requestTimeSeriesPanel,
            responseTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          latencyStatusCodesRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            responseStatusCodesTimeSeriesPanel,
            requestLatencyTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=15
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
