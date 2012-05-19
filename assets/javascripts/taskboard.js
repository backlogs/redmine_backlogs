/***************************************
  TASKBOARD
***************************************/

RB.Taskboard = RB.Object.create(RB.Model, {
    
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
    RB.$("#col_width input").bind('keyup', function(e){ if(e.which==13) self.updateColWidths() });

    var tasks_lists = j.find("#tasks .list");
    if (!tasks_lists || !tasks_lists.length) {
      alert("There are no task states. Please check the workflow of your tasks tracker in the administration section.");
      return;
    }
    // Initialize task lists
    tasks_lists.sortable({ 
      connectWith: '#tasks .list', 
      placeholder: 'placeholder',
      start: self.dragStart,
      stop: self.dragStop,
      update: self.dragComplete
    });

    // Initialize each task in the board
    j.find('.task').each(function(index){
      var task = RB.Factory.initialize(RB.Task, this); // 'this' refers to an element with class="task"
    });

    // Add handler for .add_new click
    j.find('#tasks .add_new').bind('mouseup', self.handleAddNewTaskClick);


    // Initialize impediment lists
    j.find("#impediments .list").sortable({ 
      connectWith: '#impediments .list', 
      placeholder: 'placeholder',
      start: self.dragStart,
      stop: self.dragStop,
      update: self.dragComplete
    });

    // Initialize each task in the board
    j.find('.impediment').each(function(index){
      var task = RB.Factory.initialize(RB.Impediment, this); // 'this' refers to an element with class="impediment"
    });

    // Add handler for .add_new click
    j.find('#impediments .add_new').bind('mouseup', self.handleAddNewImpedimentClick);
  },
  
  dragComplete: function(event, ui) {
    var isDropTarget = (ui.sender==null); // Handler is triggered for source and target. Thus the need to check.

    if(isDropTarget){
      ui.item.data('this').saveDragResult();
    }    
  },
  
  dragStart: function(event, ui){ 
    if (jQuery.support.noCloneEvent){
      ui.item.addClass("dragging");
    } else {
      // for IE
      ui.item.addClass("dragging");      
      ui.item.draggable('enabled');
    }
  },
  
  dragStop: function(event, ui){ 
    if (jQuery.support.noCloneEvent){
      ui.item.removeClass("dragging");
    } else {
      // for IE
      ui.item.draggable('disable');
      ui.item.removeClass("dragging");      
    }
  },

  handleAddNewImpedimentClick: function(event){
    var row = RB.$(this).parents("tr").first();
    RB.$('#taskboard').data('this').newImpediment(row);
  },
  
  handleAddNewTaskClick: function(event){
    var row = RB.$(this).parents("tr").first();
    RB.$('#taskboard').data('this').newTask(row);
  },

  loadColWidthPreference: function(){
    var w = RB.UserPreferences.get('taskboardColWidth');
    if(w==null){
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
    var w = parseInt(RB.$("#col_width input").val());
    if(w==null || isNaN(w)){
      w = this.defaultColWidth;
    }
    RB.$("#col_width input").val(w)
    RB.UserPreferences.set('taskboardColWidth', w);
    RB.$(".swimlane").width(this.colWidthUnit * w).css('min-width', this.colWidthUnit * w);
  }
});

jQuery(document).ready(function(){
  jQuery("#board_header").scrollFollow({
    speed: 100,
    offset: 0
  });
});
