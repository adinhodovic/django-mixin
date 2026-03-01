local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboardUtil = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbQueryOptions = tablePanel.queryOptions;

{
  local dashboardName = 'django-model-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = dashboardUtil.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.modelCluster,
        defaultVariables.modelNamespace,
        defaultVariables.modelJob,
        defaultVariables.model,
      ];

      local defaultFilters = dashboardUtil.filters($._config);
      local queries = {
        totalInsertRate: |||
          round(
            sum(
              rate(
                django_model_inserts_total{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (namespace, job), 0.001
          )
        ||| % defaultFilters,

        totalUpdateRate: |||
          round(
            sum(
              rate(
                django_model_updates_total{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (namespace, job), 0.001
          )
        ||| % defaultFilters,

        totalDeleteRate: |||
          round(
            sum(
              rate(
                django_model_deletes_total{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (namespace, job), 0.001
          )
        ||| % defaultFilters,

        operationDistribution1h: |||
          sum by (operation) (
            label_replace(
              rate(
                django_model_inserts_total{
                  %(default)s
                }[1h]
              ),
              "operation",
              "insert",
              "__name__",
              ".*"
            )
            or
            label_replace(
              rate(
                django_model_updates_total{
                  %(default)s
                }[1h]
              ),
              "operation",
              "update",
              "__name__",
              ".*"
            )
            or
            label_replace(
              rate(
                django_model_deletes_total{
                  %(default)s
                }[1h]
              ),
              "operation",
              "delete",
              "__name__",
              ".*"
            )
          )
        ||| % defaultFilters,

        insertsByModel1h: |||
          topk(20,
            sum(
              rate(
                django_model_inserts_total{
                  %(default)s
                }[1h]
              )
            ) by (model)
          )
        ||| % defaultFilters,

        updatesByModel1h: |||
          topk(20,
            sum(
              rate(
                django_model_updates_total{
                  %(default)s
                }[1h]
              )
            ) by (model)
          )
        ||| % defaultFilters,

        deletesByModel1h: |||
          topk(20,
            sum(
              rate(
                django_model_deletes_total{
                  %(default)s
                }[1h]
              )
            ) by (model)
          )
        ||| % defaultFilters,

        insertsByModel: |||
          round(
            sum(
              rate(
                django_model_inserts_total{
                  %(model)s
                }[$__rate_interval]
              )
            ) by (namespace, job, model), 0.001
          )
        ||| % defaultFilters,

        updatesByModel: |||
          round(
            sum(
              rate(
                django_model_updates_total{
                  %(model)s
                }[$__rate_interval]
              )
            ) by (namespace, job, model), 0.001
          )
        ||| % defaultFilters,

        deletesByModel: |||
          round(
            sum(
              rate(
                django_model_deletes_total{
                  %(model)s
                }[$__rate_interval]
              )
            ) by (namespace, job, model), 0.001
          )
        ||| % defaultFilters,

        topInserts1w: |||
          round(
            topk(10,
              sum(
                increase(
                  django_model_inserts_total{
                    %(default)s
                  }[1w]
                ) > 0
              ) by (namespace, job, model)
            )
          )
        ||| % defaultFilters,

        topUpdates1w: std.strReplace(queries.topInserts1w, 'django_model_inserts_total', 'django_model_updates_total'),
        topDeletes1w: std.strReplace(queries.topInserts1w, 'django_model_inserts_total', 'django_model_deletes_total'),
      };

      local panels = {
        operationDistribution1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Distribution by Inserts / Updates / Deletes [1h]',
            'ops',
            queries.operationDistribution1h,
            '{{ operation }}',
            description='Write operation distribution over the last hour.',
          ),

        insertsByModel1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Inserts Distribution by Model [1h]',
            'ops',
            queries.insertsByModel1h,
            '{{ model }}',
            description='Insert rate share by model over the last hour.',
          ),

        updatesByModel1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Updates Distribution by Model [1h]',
            'ops',
            queries.updatesByModel1h,
            '{{ model }}',
            description='Update rate share by model over the last hour.',
          ),

        deletesByModel1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Deletes Distribution by Model [1h]',
            'ops',
            queries.deletesByModel1h,
            '{{ model }}',
            description='Delete rate share by model over the last hour.',
          ),

        insertsByModelTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Inserts by Model',
            'ops',
            queries.insertsByModel,
            legend='{{ model }}',
            description='The rate of inserts (creates) per second, grouped by model.',
            stack='normal'
          ),

        updatesByModelTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Updates by Model',
            'ops',
            queries.updatesByModel,
            legend='{{ model }}',
            description='The rate of updates per second, grouped by model.',
            stack='normal'
          ),

        deletesByModelTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Deletes by Model',
            'ops',
            queries.deletesByModel,
            legend='{{ model }}',
            description='The rate of deletes per second, grouped by model.',
            stack='normal'
          ),

        topInserts1wTable:
          mixinUtils.dashboards.tablePanel(
            'Top Models by Inserts (1w)',
            'short',
            queries.topInserts1w,
            description='Top 10 models by number of inserts over the past week.',
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
                    namespace: 'Namespace',
                    job: 'Job',
                    model: 'Model',
                    Value: 'Inserts',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    model: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ]
          ),

        topUpdates1wTable:
          mixinUtils.dashboards.tablePanel(
            'Top Models by Updates (1w)',
            'short',
            queries.topUpdates1w,
            description='Top 10 models by number of updates over the past week.',
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
                    namespace: 'Namespace',
                    job: 'Job',
                    model: 'Model',
                    Value: 'Updates',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    model: 2,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ]
          ),

        topDeletes1wTable:
          mixinUtils.dashboards.tablePanel(
            'Top Models by Deletes (1w)',
            'short',
            queries.topDeletes1w,
            description='Top 10 models by number of deletes over the past week.',
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
                    namespace: 'Namespace',
                    job: 'Job',
                    model: 'Model',
                    Value: 'Deletes',
                  },
                  indexByName: {
                    namespace: 0,
                    job: 1,
                    model: 2,
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
            panels.operationDistribution1hPieChart,
            panels.insertsByModel1hPieChart,
            panels.updatesByModel1hPieChart,
            panels.deletesByModel1hPieChart,
          ],
          panelWidth=6,
          panelHeight=5,
          startY=1,
        ) +
        [
          row.new('Timelines') +
          row.gridPos.withX(0) +
          row.gridPos.withY(6) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.insertsByModelTimeSeries,
            panels.updatesByModelTimeSeries,
            panels.deletesByModelTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=7,
        ) +
        [
          row.new('Weekly Breakdown') +
          row.gridPos.withX(0) +
          row.gridPos.withY(25) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.topInserts1wTable,
            panels.topUpdates1wTable,
            panels.topDeletes1wTable,
          ],
          panelWidth=8,
          panelHeight=8,
          startY=26,
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Django / Models / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Django model operations (inserts, updates, deletes) using ExportModelOperationsMixin. %s' % dashboardUtil.dashboardDescriptionLink) +
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
