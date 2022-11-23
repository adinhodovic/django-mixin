{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'django',
        rules: [
          {
            alert: 'DjangoTaskFailed',
            expr: |||
              increase(django_task_failed_total{%(djangoSelector)s}[%(taskInterval)s]) > 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'A Django task has failed to complete.',
              description: 'The task {{ $labels.name }} failed to complete.',
            },
          },
          {
            alert: 'DjangoWorkerDown',
            expr: |||
              django_worker_up{%(djangoSelector)s} == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'A Django worker is offline.',
              description: 'The Django worker {{ $labels.hostname }} is offline.',
            },
          },
        ],
      },
    ],
  },
}
