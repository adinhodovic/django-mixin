local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  dashboardDescriptionLink: mixinUtils.dashboards.dashboardDescriptionLink(
    'Django-mixin',
    'https://github.com/adinhodovic/django-mixin'
  ),

  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    namespace: 'namespace="$namespace"',
    job: 'job=~"$job"',
    viewV: 'view="$view"',
    viewVMulti: 'view=~"$view"',
    ignoredViews: 'view!~"%(djangoIgnoredViews)s"' % config,
    methodV: 'method=~"$method"',
    modelV: 'model=~"$model"',
    adminViewRegex: config.adminViewRegex,
    djangoIgnoredViews: config.djangoIgnoredViews,
    djangoIgnoredTemplates: config.djangoIgnoredTemplates,

    // Django
    base: |||
      %(cluster)s,
      %(namespace)s,
      %(job)s
    ||| % this,

    default: |||
      %(cluster)s,
      %(namespace)s,
      %(job)s
    ||| % this,

    view: |||
      %(base)s,
      %(viewVMulti)s,
      %(ignoredViews)s
    ||| % this,

    defaultIgnoredViews: |||
      %(base)s,
      %(ignoredViews)s
    ||| % this,

    viewSingle: |||
      %(base)s,
      %(viewV)s,
      %(ignoredViews)s
    ||| % this,

    method: |||
      %(view)s,
      %(methodV)s
    ||| % this,

    methodSingle: |||
      %(viewSingle)s,
      %(methodV)s
    ||| % this,

    model: |||
      %(base)s,
      %(modelV)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new('cluster') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.clusterLabel,
        'django_http_responses_total_by_status_view_method_total{}',
      ) +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      query.withSort() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    modelCluster:
      query.new('cluster') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.clusterLabel,
        'django_model_inserts_total{}',
      ) +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      query.withSort() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    namespace:
      query.new(
        'namespace',
        'label_values(django_http_responses_total_by_status_view_method_total{%(cluster)s}, namespace)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    modelNamespace:
      query.new(
        'namespace',
        'label_values(django_model_inserts_total{%(cluster)s}, namespace)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    job:
      query.new(
        'job',
        'label_values(django_http_responses_total_by_status_view_method_total{%(cluster)s, %(namespace)s}, job)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    modelJob:
      query.new(
        'job',
        'label_values(django_model_inserts_total{%(cluster)s, %(namespace)s}, job)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    view:
      query.new(
        'view',
        'label_values(django_http_responses_total_by_status_view_method_total{%(cluster)s, %(namespace)s, %(job)s, %(ignoredViews)s}, view)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('View') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    viewSingle:
      this.view +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false),

    method:
      query.new(
        'method',
        'label_values(django_http_responses_total_by_status_view_method_total{%(cluster)s, %(namespace)s, %(job)s, %(viewVMulti)s}, method)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Method') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    model:
      query.new(
        'model',
        'label_values(django_model_inserts_total{%(cluster)s, %(namespace)s, %(job)s}, model)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Model') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },

  annotations(config, filters):: mixinUtils.dashboards.annotations(config, filters),

  dashboardLinks(config):: mixinUtils.dashboards.dashboardLinks('Django', config, dropdown=true, includeVars=true),
}
