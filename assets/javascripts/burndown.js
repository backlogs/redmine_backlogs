if (RB == null) { var RB = {}; }
if (RB.burndown == null) { RB.burndown = {options: {}, charts: {}}; }

RB.burndown.options.disabled_series = function() {
  var disabled = RB.UserPreferences.get('disabled_burndown_series');
  if (!disabled) { return ''; }
  return disabled;
}
RB.burndown.options.show_legend = function() {
  var legend = RB.UserPreferences.get('burndown_show_legend');
  if (!legend) { return 'sw'; }
  return legend;
}

RB.burndown.initialize = function() {
  for (id in RB.burndown.charts) {
    chart = RB.burndown.charts[id];
    if (!chart.chart) { chart.chart = $.jqplot('burndown_' + id, chart.series, chart.options); }
  }

  RB.burndown.redraw();
}

RB.burndown.redraw = function() {
  var disabled = RB.burndown.options.disabled_series();
  var legend = RB.burndown.options.show_legend();

  for (id in RB.burndown.charts) {
    chart = RB.burndown.charts[id];
    if (!chart.chart) { continue; }

    for (name in chart.position) {
      pos = chart.position[name];
      chart.options.series[pos].show = (disabled.indexOf('=' + name + '=') == -1);
    }

    if (legend == 'off') {
      chart.options.legend.show = false;
    } else {
      chart.options.legend.show = (chart.mode == 'full');
      chart.options.legend.location = legend;
    }

    chart.chart.replot();
  }
}

RB.burndown.change_legend = function(rb) {
  RB.UserPreferences.set('burndown_show_legend', rb.value);
  RB.burndown.redraw();
}

RB.burndown.change_series = function(cb) {
  var disabled = RB.burndown.options.disabled_series();
  var series = cb.value;

  disabled = disabled.replace('=' + series + '=', '=');
  if (!cb.checked) { disabled += (series + '='); }
  if (!(disabled =~ /^=/)) { disabled = ('=' + disabled); }
  if (!(disabled =~ /=$/)) { disabled += '='; }
  RB.UserPreferences.set('disabled_burndown_series', disabled);
  RB.burndown.redraw();
}

RB.burndown.configure = function() {
  var disabled = RB.burndown.options.disabled_series().split('=');
  var cb;
  for (i in disabled) {
    cb = $('#burndown_series_' + disabled[i]);
    if (cb) { cb.attr('checked', false); }
  }

  var legend = RB.burndown.options.show_legend();
  $('#burndown_legend_' + legend).attr('checked', true);
}
