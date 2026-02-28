local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboardUtil = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local tablePanel = g.panel.table;

// Stat
local stStandardOptions = statPanel.standardOptions;

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

        totalInsertRateStat:
          mixinUtils.dashboards.statPanel(
            'Total Insert Rate',
            'ops',
            queries.totalInsertRate,
            description='The total rate of model inserts (creates) across all models per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.001) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        totalUpdateRateStat:
          mixinUtils.dashboards.statPanel(
            'Total Update Rate',
            'ops',
            queries.totalUpdateRate,
            description='The total rate of model updates across all models per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('red'),
              stStandardOptions.threshold.step.withValue(0.001) +
              stStandardOptions.threshold.step.withColor('green'),
            ]
          ),

        totalDeleteRateStat:
          mixinUtils.dashboards.statPanel(
            'Total Delete Rate',
            'ops',
            queries.totalDeleteRate,
            description='The total rate of model deletes across all models per second.',
            steps=[
              stStandardOptions.threshold.step.withValue(0) +
              stStandardOptions.threshold.step.withColor('green'),
              stStandardOptions.threshold.step.withValue(0.001) +
              stStandardOptions.threshold.step.withColor('yellow'),
            ]
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
            panels.totalInsertRateStat,
            panels.totalUpdateRateStat,
            panels.totalDeleteRateStat,
          ],
          panelWidth=8,
          panelHeight=4,
          startY=1,
        ) +
        grid.wrapPanels(
          [
            panels.insertsByModelTimeSeries,
            panels.updatesByModelTimeSeries,
            panels.deletesByModelTimeSeries,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=5,
        ) +
        [
          row.new('Weekly Breakdown') +
          row.gridPos.withX(0) +
          row.gridPos.withY(29) +
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
          startY=30,
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
