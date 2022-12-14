# Prometheus Monitoring Mixin for Django

A set of Grafana dashboards and Prometheus alerts for Django.

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config.
To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards

1. Generate the config files and deploy them yourself
2. Use jsonnet to deploy this mixin along with Prometheus and Grafana
3. Use prometheus-operator to deploy this mixin

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you
must install some tools:

```sh
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
brew install jsonnet
```

Then, grab the mixin and its dependencies:

```sh
git clone https://github.com/danihodovic/django-exporter
cd django-exporter/django-mixin
jb install
```

Finally, build the mixin:

```sh
make prometheus-alerts.yaml
make dashboards_out
```

The `prometheus-alerts.yaml` file then need to passed
to your Prometheus server, and the files in `dashboards_out` need to be imported
into you Grafana server.  The exact details will depending on how you deploy your
monitoring stack.

## Alerts

The mixin follows the [monitoring-mixins guidelines](https://github.com/monitoring-mixins/docs#guidelines-for-alert-names-labels-and-annotations) for alerts.

### Dashboard Previews

A dashboard that monitors Django which focuses on giving a overview for the system (requests, db, cache).

![django-overview](images/django-overview.png)

A dashboard that monitors Django which focuses on giving a overview for requests.

![django-requests-overview](images/django-requests-overview.png)

A dashboard that monitors Django which focuses on breaking down requests by view.

![django-requests-by-view](images/django-requests-by-view.png)
