$.qtipMakeOptions = function(container, ajax) {
    var options = {
        content: {
            text: container.children('div.tooltip_text')
        },
        position: {
            my: 'left top',
            at: 'center rigth',
            target: 'mouse',
            viewport: RB.$(window), // Keep it on-screen at all times if possible
            adjust: {
              x: 10,
              y: -2,
              method: 'shift shift'
            }
        },
        hide: {
           fixed: true // Helps to prevent the tooltip from hiding ocassionally when tracking!
        },
        style: {
            classes: 'qtip-light qtip-shadow'
        }
    };
    if (ajax) {
      var id = container.children('.id .v').text();
      options['content'] = {
              text: '<div class="tooltip_text">Loading...</div>',
              ajax: {
                url: RB.urlFor('show_tooltip', {id: id}),
                type: 'GET',
                data: { project_id: RB.constants.project_id }, //to satisfy before_filter and authorize
                once: true
              }
            };
    }
    return options;
}

$(function($) {
  RB.util.initToolTip();
});
