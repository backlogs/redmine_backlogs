if (typeof RB.burndown == "undefined") { RB.burndown = {options: {}, charts: {}}; }

RB.burndown.options.disabled_series = function(new_value) {
  if (new_value === undefined) {
    var v = RB.UserPreferences.get('disabled_burndown_series', true) || '';
    return v.split(',');
  } else {
    RB.UserPreferences.set('disabled_burndown_series', new_value.join(','), true);
    return new_value;
  }
};
RB.burndown.options.show_legend = function() {
  var legend = RB.UserPreferences.get('burndown_show_legend', true);
  if (!legend) { return 'sw'; }
  return legend;
};

RB.burndown.initialize = function() {
  var id, chart;
  for (id in RB.burndown.charts) {
    chart = RB.burndown.charts[id];
    if (chart.mode != 'full') {
      chart.options.axes.xaxis.show=false;
      chart.options.axes.xaxis.showTicks=false;
      chart.options.axes.y2axis.show=false;
      chart.options.axes.y3axis.show=false;
      chart.options.axes.yaxis.showLabel=false;
      chart.options.axes.y2axis.showLabel=false;
    }
    if (!chart.chart) {
      RB.$('#burndown_' + id).empty();
      chart.chart = RB.$.jqplot('burndown_' + id, chart.series, chart.options);
    }
  }

  RB.burndown.redraw();
};

RB.burndown.redraw = function() {
  var name, pos, id, chart;
  var disabled = RB.burndown.options.disabled_series();
  var legend = RB.burndown.options.show_legend();
  for (id in RB.burndown.charts) {
    chart = RB.burndown.charts[id];
    if (!chart.chart) { continue; }

    for (name in chart.position) {
      pos = chart.position[name];
      chart.chart.series[pos].show = (RB.$.inArray(name, disabled) == -1);
    }

    if (legend == 'off') {
      chart.chart.legend.show = false;
    } else {
      chart.chart.legend.show = (chart.mode == 'full');
      if (!chart.chart.legend.location_override) {
        chart.chart.legend.location = legend;
      }
      else
      {
        chart.chart.legend.location = chart.chart.legend.location_override;
      }
    }

    chart.chart.replot();
  }
};

RB.burndown.change_legend = function(rb) {
  RB.UserPreferences.set('burndown_show_legend', rb.value, true);
  RB.burndown.redraw();
};

RB.burndown.change_series = function(cb) {
  var disabled = RB.burndown.options.disabled_series();

  var i = RB.$.inArray(cb.value, disabled);
  if (i != -1) { disabled.splice(i, 1); }
  if (!cb.checked) { disabled.push(cb.value); }
  RB.burndown.options.disabled_series(disabled);
  RB.burndown.redraw();
};

RB.burndown.configure = function() {
  var disabled = RB.burndown.options.disabled_series();
  var cb;

  RB.$.each(disabled, function(index, value) {
    //here we get some weird expression error in jquery 1.6 as well as in 1.7
    try {
    var cb = RB.$('#burndown_series_' + value);
    if (cb) { cb.attr('checked', false); }
    } catch(e) {/*FIXME jquery Uncaught Syntax error, unrecognized expression: "*/}
  });

  var legend = RB.burndown.options.show_legend();
  RB.$('#burndown_legend_' + legend).attr('checked', true);
};
