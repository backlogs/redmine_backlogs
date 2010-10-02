// Initialize the backlogs after DOM is loaded
$(function() {
  // Initialize each backlog
  $('.backlog').each(function(index){
    backlog = RB.Factory.initialize(RB.Backlog, this); // 'this' refers to an element with class="backlog"
  });
  
  $("#new_sprint").bind('click', RB.MasterBacklog.newSprintBacklog)
  // $("#project_info").bind('click', function(){ $("#velocity").dialog({ modal: true, title: "Project Info"}); });
  
  RB.BacklogsUpdater.start();

  // Workaround for IE7
  if($.browser.msie && $.browser.version <= 7){
    var z = 2000;
    $('.backlog, .header').each(function(){
      $(this).css('z-index', z);
      z--;
    });
  }
});

RB.MasterBacklog = RB.Object.create({
  
  newSprintBacklog: function(){
    var backlog = $('#sprint_backlog_template').children().first().clone();
    var sprint = backlog.find(".sprint").first();

    $("#sprint_backlogs_container").prepend(backlog);
    o = RB.Factory.initialize(RB.Sprint, sprint);
    o.edit();
    
    // For some reason, focus() doesn't work in Chrome without the delay
    setTimeout(function(){ sprint.find('.editor')[0].focus() }, 50);
  }
  
});