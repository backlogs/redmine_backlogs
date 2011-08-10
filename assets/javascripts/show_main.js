// Initialize everything after DOM is loaded
RB.$(function() {  
  var board = RB.Factory.initialize(RB.Taskboard, RB.$('#taskboard'));
  RB.TaskboardUpdater.start();

  // Capture 'click' instead of 'mouseup' so we can preventDefault();
  RB.$('#show_charts').bind('click', RB.showCharts);
  
  RB.$('#assigned_to_id_options').bind('change', function(){
    RB.$(this).parents('.ui-dialog').css('background-color', RB.$(this).children(':selected').attr('color'));
  });
});

RB.showCharts = function(event){
  event.preventDefault();
  if(RB.$("#charts").length==0){
    RB.$( document.createElement("div") ).attr('id', "charts").appendTo("body");
  }
  RB.$('#charts').html( "<div class='loading'>Loading data...</div>");
  RB.$('#charts').load( RB.urlFor('show_burndown_chart', { id: RB.constants.sprint_id }) );
  RB.$('#charts').dialog({ 
                        buttons: { "Close": function() { RB.$(this).dialog("close") } },
                        height: 590,
                        modal: true, 
                        title: 'Charts', 
                        width: 710 
                     });
}
