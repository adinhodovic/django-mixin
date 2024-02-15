local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;

{
  a: grid.makeGrid(
    [
      statPanel.new(
        'stat',
      ),
    ],
    panelWidth=6,
    panelHeight=5,
    startY=0
  ) + grid.makeGrid(
    [
      statPanel.new(
        'stat',
      ),
    ],
    panelWidth=6,
    panelHeight=5,
    startY=5
  ),
}
