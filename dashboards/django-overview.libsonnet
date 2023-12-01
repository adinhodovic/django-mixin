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
local tbQueryOptions = tablePanel.queryOptions;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data Source'),

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

    local variables = [
      datasourceVariable,
      namespaceVariable,
      jobVariable,
    ],

    local requestVolumeQuery = |||
      round(
        sum(
          rate(
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
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
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
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          cacheHitrateQuery,
        )
      ) +
      stStandardOptions.withUnit('percentunit') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local dbOpsQuery = |||
      sum (
        rate (
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
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          dbOpsQuery,
        )
      ) +
      stStandardOptions.withUnit('ops') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local response2xxQuery = |||
      round(
        sum(
          rate(
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

    local dbLatencyP50Query = |||
      histogram_quantile(0.50,
        sum(
          irate(
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

    local dbLatencyTimeSeriesPanel =
      timeSeriesPanel.new(
        'Database Latency',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            dbLatencyP50Query,
          ) +
          prometheus.withLegendFormat(
            '50 - {{ vendor }}',
          ),
          prometheus.new(
            '$datasource',
            dbLatencyP95Query,
          ) +
          prometheus.withLegendFormat(
            '95 - {{ vendor }}',
          ),
          prometheus.new(
            '$datasource',
            dbLatencyP99Query,
          ) +
          prometheus.withLegendFormat(
            '99 - {{ vendor }}',
          ),
          prometheus.new(
            '$datasource',
            dbLatencyP999Query,
          ) +
          prometheus.withLegendFormat(
            '99.9 - {{ vendor }}',
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

    local dbConnectionsQuery = |||
      round(
        sum(
          increase(
            django_db_new_connections_total{
              namespace=~"$namespace",
              job=~"$job",
            }[$__rate_interval]
          ) > 0
        ) by (namespace, job, vendor)
      )
    ||| % $._config,

    local dbConnectionsTimeSeriesPanel =
      timeSeriesPanel.new(
        'Database Connections',
      ) +
      tsQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          dbConnectionsQuery,
        ) +
        prometheus.withLegendFormat(
          '{{ vendor }}'
        )
      ) +
      tsStandardOptions.withUnit('short') +
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
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          migrationsAppliedQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
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
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          migrationsUnAppliedQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('red'),
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
      tablePanel.new(
        'Top Database Errors (1w)',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Type')
      ) +
      tbQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          topDbErrors1wQuery,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
      ) +
      tbQueryOptions.withTransformations([
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
      ]),

    local cacheGetHitsQuery = |||
      sum(
        rate(
          django_cache_get_hits_total{
            namespace=~"$namespace",
            job=~"$job",
          }[$__rate_interval]
        ) > 0
      ) by (namespace, job, backend)
    ||| % $._config,
    local cacheGetMissesQuery = std.strReplace(cacheGetHitsQuery, 'django_cache_get_hits_total', 'django_cache_get_misses_total'),

    local cacheGetTimeSeriesPanel =
      timeSeriesPanel.new(
        'Cache Get',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            cacheGetHitsQuery,
          ) +
          prometheus.withLegendFormat(
            'Hit - {{ backend }}',
          ),
          prometheus.new(
            '$datasource',
            cacheGetMissesQuery,
          ) +
          prometheus.withLegendFormat(
            'Miss - {{ backend }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('ops') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('percent') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

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
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Django / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache). It is created using the [Django-mixin](https://github.com/adinhodovic/django-mixin).') +
      dashboard.withUid($._config.overviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
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
          [requestVolumeStatPanel, dbOpsStatPanel, cacheHitrateStatPanel],
          panelWidth=8,
          panelHeight=4,
          startY=1
        ) +
        [
          responseTimeSeriesPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(5) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(6),
          dbRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          migrationsAppliedStatPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(12) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(3),
          migrationsUnAppliedStatPanel +
          tablePanel.gridPos.withX(6) +
          tablePanel.gridPos.withY(12) +
          tablePanel.gridPos.withW(6) +
          tablePanel.gridPos.withH(3),
          topDbErrors1wTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(15) +
          tablePanel.gridPos.withW(12) +
          tablePanel.gridPos.withH(9),
          dbConnectionsTimeSeriesPanel +
          tablePanel.gridPos.withX(12) +
          tablePanel.gridPos.withY(12) +
          tablePanel.gridPos.withW(12) +
          tablePanel.gridPos.withH(6),
          dbLatencyTimeSeriesPanel +
          tablePanel.gridPos.withX(12) +
          tablePanel.gridPos.withY(18) +
          tablePanel.gridPos.withW(12) +
          tablePanel.gridPos.withH(6),
          cacheRow +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(24) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(1),
          cacheGetTimeSeriesPanel +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(25) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(6),
        ]
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
