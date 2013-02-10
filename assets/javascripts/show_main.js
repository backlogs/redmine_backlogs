// Initialize everything after DOM is loaded
RB.$(function() {  
  var board = RB.Factory.initialize(RB.Taskboard, RB.$('#taskboard'));
  RB.TaskboardUpdater.start();

  // Capture 'click' instead of 'mouseup' so we can preventDefault();
  RB.$('#show_charts').bind('click', RB.showCharts);
  
  RB.$('#assigned_to_id_options').bind('change', function(){
    c = RB.$(this).children(':selected').attr('color');
    c_light = RB.$(this).children(':selected').attr('color_light');
    if(c==undefined){
      c = "#AAAAAA";
      c_light = "#E0E0E0";
    }
    RB.$(this).parents('.ui-dialog').css('background-color', c);
    RB.$(this).parents('.ui-dialog').css('background', '-webkit-gradient(linear, left top, left bottom, from('+c_light+'), to('+c+'))');
    RB.$(this).parents('.ui-dialog').css('background', '-moz-linear-gradient(top, '+c_light+', '+c+')');    
    RB.$(this).parents('.ui-dialog').css('filter', 'progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr='+c_light+',EndColorStr='+c+')');
  });

  // hold down alt when clicking an issue id to open it in the current tab
  RB.$('#taskboard').delegate('.id a', 'click', function(e) {
    if (e.shiftKey) {
      location.href = this.href;
      return false;
    }
  });

  /* make taskbord swimlane header floating */
  RB.$("#board_header").verticalFix({
    delay: 50
  });

  /* private mode/userfilter dropdown*/
  RB.UserFilter.initialize();

});

RB.showCharts = function(event){
  event.preventDefault();
  if(!RB.$("#charts").length){
    RB.$( document.createElement("div") ).attr('id', "charts").appendTo("body");
  }
  RB.$('#charts').html( "<div class='loading'>Loading data...</div>");
  RB.$('#charts').load( RB.urlFor('show_burndown_embedded', { id: RB.constants.sprint_id }) );
  RB.$('#charts').dialog({ 
                        buttons: { "Close": function() { RB.$(this).dialog("close"); } },
                        height: 590,
                        modal: true, 
                        title: 'Charts', 
                        width: 710 
                     });
};
