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
local tablePanel = g.panel.table;

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

// Table
local tbOptions = tablePanel.options;
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source'),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(django_http_responses_total_by_status_view_method_total{}, namespace)'
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
        'label_values(django_http_responses_total_by_status_view_method_total{namespace=~"$namespace"}, job)'
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
        'label_values(django_http_responses_total_by_status_view_method_total{%s, view!~"%s"}, view)' % [defaultFilters, $._config.djangoIgnoredViews],
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('View') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local methodVariable =
      query.new(
        'method',
        'label_values(django_http_responses_total_by_status_view_method_total{%s, view=~"$view"}, method)' % defaultFilters,
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
      namespaceVariable,
      jobVariable,
      viewVariable,
      methodVariable,
    ],

    local requestVolumeQuery = |||
      round(
        sum(
          rate(
            django_http_requests_total_by_view_transport_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view=~"$view",
              view!~"%(djangoIgnoredViews)s",
              method=~"$method"
            }[$__rate_interval]
          )
        ), 0.001
      )
    ||| % $._config,

    local requestVolumeStatPanel =
      statPanel.new(
        'Request Volume',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestVolumeQuery,
        )
      ) +
      stStandardOptions.withUnit('reqps') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.001) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local requestSuccessRateQuery = |||
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            namespace=~"$namespace",
            job=~"$job",
            view=~"$view",
            view!~"%(djangoIgnoredViews)s",
            method=~"$method",
            status!~"[4-5].*"
          }[$__rate_interval]
        )
      ) /
      sum(
        rate(
          django_http_responses_total_by_status_view_method_total{
            namespace=~"$namespace",
            job=~"$job",
            view=~"$view",
            view!~"%(djangoIgnoredViews)s",
            method=~"$method"
          }[$__rate_interval]
        )
      )
    ||| % $._config,

    local requestSuccessRateStatPanel =
      statPanel.new(
        'Success Rate (non 4-5xx responses)',
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

    local requestBytesP95Query = |||
      histogram_quantile(0.95,
        sum (
          rate (
              django_http_requests_body_total_bytes_bucket {
                namespace=~"$namespace",
                job=~"$job",
              }[$__rate_interval]
          )
        ) by (job, le)
      )
    ||| % $._config,

    local requestBytesStatPanel =
      statPanel.new(
        'Request Body Size (P95)',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestBytesP95Query,
        )
      ) +
      stStandardOptions.withUnit('decbytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.2) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(0.3) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local requestLatencyP95SummaryQuery = |||
      histogram_quantile(0.95,
        sum (
          irate(
            django_http_requests_latency_seconds_by_view_method_bucket{
              namespace=~"$namespace",
              job=~"$job",
              view!~"%(djangoIgnoredViews)s",
            }[$__rate_interval]
          )
        ) by (job, le)
      )
    ||| % $._config,

    local requestLatencyP95SummaryStatPanel =
      statPanel.new(
        'Request Latency (P95)',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          requestLatencyP95SummaryQuery,
        )
      ) +
      stStandardOptions.withUnit('s') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(2500) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(5000) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local apiResponse2xxQuery = |||
      round(
        sum(
          rate(
            django_http_responses_total_by_status_view_method_total{
              namespace=~"$namespace",
              job=~"$job",
              view=~"$view",
              view!~"%(djangoIgnoredViews)s",
              method=~"$method",
              status=~"2.*",
              view!~"%(adminViewRegex)s",
            }[$__rate_interval]
          ) > 0
        ) by (namespace, job, view), 0.001
      )
    ||| % $._config,
    local apiResponse4xxQuery = std.strReplace(apiResponse2xxQuery, '2.*', '4.*'),
    local apiResponse5xxQuery = std.strReplace(apiResponse2xxQuery, '2.*', '5.*'),

    local apiResponseTimeSeriesPanel =
      timeSeriesPanel.new(
        'API & Other Views Response Status',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            apiResponse2xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 2xx'
          ),
          prometheus.new(
            '$datasource',
            apiResponse4xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 4xx'
          ),
          prometheus.new(
            '$datasource',
            apiResponse5xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 5xx'
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
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local apiRequestLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          rate(
            django_http_requests_latency_seconds_by_view_method_bucket{
              namespace=~"$namespace",
              job=~"$job",
              view=~"$view",
              view!~"%(djangoIgnoredViews)s|",
              view!~"%(adminViewRegex)s",
              method=~"$method"
            }[$__rate_interval]
          ) > 0
        ) by (namespace, job, view, le)
      )
    ||| % $._config,
    local apiRequestLatencyP95Query = std.strReplace(apiRequestLatencyP50Query, '0.50', '0.95'),
    local apiRequestLatencyP99Query = std.strReplace(apiRequestLatencyP50Query, '0.50', '0.99'),

    local apiRequestLatencyTable =
      tablePanel.new(
        'API & Other Views Request Latency',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('P50 Latency') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('dtdurations') +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            apiRequestLatencyP50Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            apiRequestLatencyP95Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            apiRequestLatencyP99Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
        ]
      ) +
      tbQueryOptions.withTransformations([
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
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('View') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To View') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/django-requests-by-view?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.requestsByViewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local adminResponse2xxQuery = std.strReplace(apiResponse2xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminResponse4xxQuery = std.strReplace(apiResponse4xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminResponse5xxQuery = std.strReplace(apiResponse5xxQuery, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),

    local adminResponseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Admin Views Response Status',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            adminResponse2xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 2xx'
          ),
          prometheus.new(
            '$datasource',
            adminResponse4xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 4xx'
          ),
          prometheus.new(
            '$datasource',
            adminResponse5xxQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ view }} / 5xx'
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
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local adminRequestLatencyP50Query = std.strReplace(apiRequestLatencyP50Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminRequestLatencyP95Query = std.strReplace(apiRequestLatencyP95Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),
    local adminRequestLatencyP99Query = std.strReplace(apiRequestLatencyP99Query, 'view!~"%s"' % $._config.adminViewRegex, 'view=~"%s"' % $._config.adminViewRegex),

    local adminRequestLatencyTable =
      tablePanel.new(
        'Admin Request Latency',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('P50 Latency') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('dtdurations') +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            adminRequestLatencyP50Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            adminRequestLatencyP95Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            adminRequestLatencyP99Query,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
        ]
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.withTransformations([
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
        ]),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('View') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To View') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/django-requests-by-view?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.requestsByViewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local topHttpExceptionsByView1wQuery = |||
      round(
        topk(10,
          sum by (namespace, job, view) (
            increase(
              django_http_exceptions_total_by_view_total{
                namespace=~"$namespace",
                job=~"$job",
                view!~"%(djangoIgnoredViews)s",
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,

    local topHttpExceptionsByView1wTable =
      tablePanel.new(
        'Top Exceptions by View (1w)',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Value') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('short') +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          topHttpExceptionsByView1wQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true),
      ) +
      tbQueryOptions.withTransformations([
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
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('View') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To View') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/django-requests-by-view?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.requestsByViewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local topHttpExceptionsByType1wQuery = |||
      round(
        topk(10,
          sum by (namespace, job, type) (
            increase(
              django_http_exceptions_total_by_type_total{
                namespace=~"$namespace",
                job=~"$job",
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,

    local topHttpExceptionsByType1wTable =
      tablePanel.new(
        'Top Exceptions by Type (1w)',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Value') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('short') +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          topHttpExceptionsByType1wQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true),
      ) +
      tbQueryOptions.withTransformations([
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
      ]),

    local topResponseByView1wQuery = |||
      round(
        topk(10,
          sum by (namespace, job, view) (
            increase(
              django_http_responses_total_by_status_view_method_total{
                namespace=~"$namespace",
                job=~"$job",
                view!~"%(djangoIgnoredViews)s",
                method=~"$method"
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,

    local topResponseByView1wTable =
      tablePanel.new(
        'Top Responses By View (1w)',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Value') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('short') +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          topResponseByView1wQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true),
      ) +
      tbQueryOptions.withTransformations([
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
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('View') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To View') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/django-requests-by-view?var-namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-view=${__data.fields.View}' % $._config.requestsByViewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local topTemplates1wQuery = |||
      topk(10,
        round(
          sum by (namespace, job, templatename) (
            increase(
              django_http_responses_total_by_templatename_total{
                namespace=~"$namespace",
                job=~"$job",
                templatename!~"%(djangoIgnoredTemplates)s"
              }[1w]
            ) > 0
          )
        )
      )
    ||| % $._config,

    local topTemplates1wTable =
      tablePanel.new(
        'Top Templates (1w)',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Value') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('short') +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          topTemplates1wQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true),
      ) +
      tbQueryOptions.withTransformations([
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
      ]),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local adminViewRow =
      row.new(
        title='Admin Views'
      ),

    local apiViewRow =
      row.new(
        title='API Views & Other'
      ),

    local weeklyBreakdownRow =
      row.new(
        title='Weekly Breakdown',
      ),

    'django-requests-overview.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Django / Requests / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on giving a overview for requests. It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).') +
      dashboard.withUid($._config.requestsOverviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-1h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('Django Dashboards', $._config.tags) +
          dashboard.link.link.options.withTargetBlank(true),
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
          [requestVolumeStatPanel, requestSuccessRateStatPanel, requestLatencyP95SummaryStatPanel, requestBytesStatPanel],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          apiViewRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [apiResponseTimeSeriesPanel, apiRequestLatencyTable],
          panelWidth=12,
          panelHeight=10,
          startY=6
        ) +
        [
          adminViewRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(16) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [adminResponseTimeSeriesPanel, adminRequestLatencyTable],
          panelWidth=12,
          panelHeight=10,
          startY=17
        ) +
        [
          weeklyBreakdownRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(26) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [topHttpExceptionsByView1wTable, topHttpExceptionsByType1wTable, topResponseByView1wTable, topTemplates1wTable],
          panelWidth=12,
          panelHeight=8,
          startY=27
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
