{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'django',
        rules: [
          {
            alert: 'CeleryTaskFailed',
            expr: |||
              increase(django_task_failed_total{%(djangoSelector)s}[%(taskInterval)s]) > 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'A Celery task has failed to complete.',
              description: 'The task {{ $labels.name }} failed to complete.',
            },
          },
          {
            alert: 'CeleryWorkerDown',
            expr: |||
              django_worker_up{%(djangoSelector)s} == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'A Celery worker is offline.',
              description: 'The Celery worker {{ $labels.hostname }} is offline.',
            },
          },
        ],
      },
    ],
  },
}
