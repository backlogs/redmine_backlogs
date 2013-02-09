/***************************************
  TASKBOARD
***************************************/

RB.Taskboard = RB.Object.create({
    
  initialize: function(el){
    var j = RB.$(el);
    var self = this; // So we can bind the event handlers to this object
    
    self.$ = j;
    self.el = el;
    
    // Associate this object with the element for later retrieval
    j.data('this', self);

    // Initialize column widths
    self.colWidthUnit = RB.$(".swimlane").width();
    self.defaultColWidth = 2;
    self.loadColWidthPreference();
    self.updateColWidths();
    RB.$("#col_width input").bind('keyup', function(e){ if(e.which==13) self.updateColWidths(); });

    //initialize mouse handling for drop handling
    j.bind('mousedown.taskboard', function(e) { return self.onMouseDown(e); });
    j.bind('mouseup.taskboard', function(e) { return self.onMouseUp(e); });

    // Initialize task lists, restricting drop to the story
    var tasks_lists =j.find('.story-swimlane');
    if (!tasks_lists || !tasks_lists.length) {
      alert("There are no task states. Please check the workflow of your tasks tracker in the administration section.");
      return;
    }

    var sortableOpts = {
      placeholder: 'placeholder',
      distance: 3,
      helper: 'clone', //workaround firefox15+ bug where drag-stop triggers click
      start: self.dragStart,
      stop: function(e, ui) {return self.dragStop(e, ui);},
      update: self.dragComplete
      //revert: true, //this interferes with capybara test timings. This braindead stupid jquery-ui issues dragStop after all animations are finished, no way to save the drag result while animation is in progress.
      //scroll: true
    };

    //initialize the cells (td) as sortable
    if (RB.permissions.update_tasks) {
      j.find('.story-swimlane .list').sortable(RB.$.extend({
        connectWith: '.story-swimlane .list'
        }, sortableOpts));
    }

    // Initialize each task in the board
    j.find('.task').each(function(index){
      var task = RB.Factory.initialize(RB.Task, this); // 'this' refers to an element with class="task"
    });

    // Add handler for .add_new click
    if (RB.permissions.create_tasks) {
      j.find('#tasks .add_new').bind('click', self.handleAddNewTaskClick);
    }


    // Initialize impediment lists
    if (RB.permissions.update_impediments) {
      j.find("#impediments .list").sortable(RB.$.extend({
        connectWith: '#impediments .list'
      }, sortableOpts));
    }

    // Initialize each impediment in the board
    j.find('.impediment').each(function(index){
      var task = RB.Factory.initialize(RB.Impediment, this); // 'this' refers to an element with class="impediment"
    });

    // Add handler for .add_new click
    if (RB.permissions.create_impediments) {
      j.find('#impediments .add_new').bind('click', self.handleAddNewImpedimentClick);
    }
  },
  
  onMouseUp: function(e) {
      //re-enable all cells deferred
      setTimeout(function(){
        RB.$(':ui-sortable').sortable('enable');
      }, 10);
  },
  /**
   * can drop when:
   *  RB.constants.task_states.transitions['+c+a ???'][from_state_id][to_state_id] is acceptable
   *
   *  and target story can accept this task:
   *    story and task are same project
   *    or task is in a subproject of story? and redmine cross-project relationships are ok
   */
  onMouseDown: function(e) {
    // find the dragged target
    var el = RB.$(e.target).parents('.model.issue'); // .task or .impediment
    if (!el.length) return; //click elsewhere

    var status_id = el.find('.meta .status_id').text();
    var user_status = el.find('.meta .user_status').text();
    var tracker_id = el.find('.meta .tracker_id').text();
    var old_project_id = el.find('.meta .project_id').text();

    //disable non-droppable cells
    RB.$('.ui-sortable').each(function() {
      var new_project_id = this.getAttribute('-rb-project-id');
      // check for project
      //sharing, restrictive case: only allow same-project story-task relationship
      if (new_project_id != old_project_id) {
        RB.$(this).sortable('disable');
        return;
      }

      // check for status
      var new_status_id = this.getAttribute('-rb-status-id');
      // allow dragging to same status to prevent weird behavior
      // if one tries drag into another story but same status.
      if (new_status_id == status_id) { return; }

      var states = RB.constants.task_states['transitions'][tracker_id][user_status][status_id];
      if (!states) { states = RB.constants.task_states['transitions'][tracker_id][user_status][RB.constants.task_states['transitions'][tracker_id][user_status]['default']]; }
      if (RB.$.inArray(String(new_status_id), states) < 0) {
        //workflow does not allow this user to put the issue into this new state.
        RB.$(this).sortable('disable');
        return;
      }

    }); //each

    el = RB.$(e.target).parents('.list'); // .task or .impediment
    if (el && el.length) el.sortable('refresh');
  },
  
  dragComplete: function(event, ui) {
    if (!ui.sender) { // Handler is triggered for source and target. Thus the need to check.
      ui.item.data('this').saveDragResult();
    }    
  },

  dragStart: function(event, ui){ 
    if (RB.$.support.noCloneEvent){
      ui.item.addClass("dragging");
    } else {
      // for IE
      ui.item.addClass("dragging");      
      ui.item.draggable('enabled');
    }
  },
  
  dragStop: function(event, ui){ 
    this.onMouseUp(event);
    if (RB.$.support.noCloneEvent){
      ui.item.removeClass("dragging");
    } else {
      // for IE
      ui.item.draggable('disable');
      ui.item.removeClass("dragging");      
    }
  },

  handleAddNewImpedimentClick: function(event){
    if (event.button > 1) return;
    var row = RB.$(this).parents("tr").first();
    RB.$('#taskboard').data('this').newImpediment(row);
  },
  
  handleAddNewTaskClick: function(event){
    if (event.button > 1) return;
    var row = RB.$(this).parents("tr").first();
    RB.$('#taskboard').data('this').newTask(row);
  },

  loadColWidthPreference: function(){
    var w = RB.UserPreferences.get('taskboardColWidth');
    if (!w) { // 0, null, undefined.
      w = this.defaultColWidth;
      RB.UserPreferences.set('taskboardColWidth', w);
    }
    RB.$("#col_width input").val(w);
  },

  newImpediment: function(row){
    var impediment = RB.$('#impediment_template').children().first().clone();
    row.find(".list").first().prepend(impediment);
    var o = RB.Factory.initialize(RB.Impediment, impediment);
    o.edit();
  },
        
  newTask: function(row){
    var task = RB.$('#task_template').children().first().clone();
    row.find(".list").first().prepend(task);
    var o = RB.Factory.initialize(RB.Task, task);
    o.edit();
  },
  
  updateColWidths: function(){
    var w = parseInt(RB.$("#col_width input").val(), 10);
    if (!w || isNaN(w)) { // 0,null,undefined,NaN.
      w = this.defaultColWidth;
    }
    RB.$("#col_width input").val(w);
    RB.UserPreferences.set('taskboardColWidth', w);
    RB.$(".swimlane").width(this.colWidthUnit * w).css('min-width', this.colWidthUnit * w);
  }
});

RB.UserFilter = RB.Object.create({
  initialize: function() {
    var me = this,
      _ = RB.constants.locale._;
    me.el = RB.$(".userfilter");
    me.el.multiselect({
      selectedText: _("Filter tasks"),
      noneSelectedText: _("Filter tasks: my tasks"),
      checkAllText: _("All tasks"),
      uncheckAllText: _("My tasks"),
      checkAll: function() { me.updateUI(); },
      uncheckAll: function() { me.onUnCheckAll(); },
      click: function() { me.updateUI(); }
    });
    me.el.multiselect('checkAll');
  },

  /* uncheck all users but check the current user, so we get a private mode button */
  onUnCheckAll: function() {
    var uid = RB.$("#userid").text();
    this.el.multiselect("widget").find(":checkbox[value='"+uid+"']").each(function() {this.checked = true;} );
    this.updateUI();
  },

  updateUI: function() {
    this.updateTasks();
    this.updateStories();
  },

  updateTasks: function() {
    var me = this;
    RB.$(".task").each(function() {
      var task_ownerid = null;
      try{
        task_ownerid = RB.$(".assigned_to_id .v", this).text();
      } catch(e){ return; }
      if (!task_ownerid || me.el.multiselect("widget").find(":checkbox[value='"+task_ownerid+"']").is(':checked')) {
        RB.$(this).show();
      }else {
        RB.$(this).hide();
      }
    });
  },

  updateStories: function() {
    //Check if all stories should be visible even if not used
    var showUnusedStories = this.el.multiselect("widget").find(":checkbox[value='s']").is(':checked');

    //Parse through all the stories and hide the ones not used
    RB.$('.story').each(function() {
      var sprintInfo = RB.$(this).children('.id').children('a')[0];
      var storyID = sprintInfo.innerHTML;

      RB.$(this).closest('tr').show();
      var hasVisTasks = 0;
      var hasTasks = 0;  // Keep track if a story has tasks (visible or not)

      //Parse each task in the story and see if any tasks are not hidden
      RB.$("#tasks [id^="+storyID+"_]").each(function(){
        RB.$(this).children().each(function(){
          hasTasks = 1;
          if (RB.$(this).is(':visible'))
            hasVisTasks = 1;
        });
      });

      //Hide or show story row based on if any tasks are visible
      if (hasVisTasks || (showUnusedStories && !hasTasks))
        RB.$(this).closest('tr').show();
      else
        RB.$(this).closest('tr').hide();
    });
   }
});

