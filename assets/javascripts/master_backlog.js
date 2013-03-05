// Initialize the backlogs after DOM is loaded
RB.$(function() {
  // Initialize each backlog
  RB.BacklogOptionsInstance = RB.Factory.initialize(RB.BacklogOptions, this);
  RB.Factory.initialize(RB.BacklogMultilineBtn, RB.$('#multiline'));
  RB.$('.backlog').each(function(index){
    RB.Factory.initialize(RB.Backlog, this);
  });
  // RB.$("#project_info").bind('click', function(){ RB.$("#velocity").dialog({ modal: true, title: "Project Info"}); });
  RB.BacklogsUpdater.start();

  // Workaround for IE7
  if(RB.$.browser.msie && RB.$.browser.version <= 7){
    var z = 2000;
    RB.$('.backlog, .header').each(function(){
      RB.$(this).css('z-index', z);
      z--;
    });
  }

  // hold down alt when clicking an issue id to open it in the current tab
  RB.$('#backlogs_container').delegate('li.story > .id a', 'click', function(e) {
    if (e.shiftKey) {
      location.href = this.href;
      return false;
    }
  });

  // show closed sprints
  RB.$('#show_completed_sprints').click(function(e) {
    e.preventDefault();
    RB.$('#closed_sprint_backlogs_container').
      html('Loading...').
      show().
      load(RB.routes.closed_sprints, function(){ //success callback
        var csbc = RB.$('#closed_sprint_backlogs_container');
        if (!RB.$.trim(csbc.html())) csbc.html(RB.constants.locale._('No data to show'));
        else RB.util.initToolTip(); //refreshToolTip requires a model scope.
      });
    RB.$('#show_completed_sprints').hide();
  });
});
