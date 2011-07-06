/******************************************
  BACKLOG
  A backlog is a visual representation of
  a sprint and its stories. It's is not a
  sprint. Imagine it this way: a sprint is
  a start and end date, and a set of 
  objectives. A backlog is something you
  would draw up on the board or a spread-
  sheet (or in Redmine Backlogs!) to 
  visualize the sprint.
******************************************/

RB.Backlog = RB.Object.create({
    
  initialize: function(el){
    var j;  // This ensures that we use a local 'j' variable, not a global one.
    var self = this;
    
    this.$ = j = $(el);
    this.el = el;

    // Associate this object with the element for later retrieval
    j.data('this', this);

    // Make the list sortable
    list = this.getList();
    list.sortable({ connectWith: '.stories',
                    placeholder: 'placeholder',
                    forcePlaceholderSize: true,
                    dropOnEmpty: true,
                    start: this.dragStart,
                    receive: this.dragReceive,
                    stop: this.dragStop,
                    beforeStop: this.dragBeforeStop,
                    update: function(e,u){ self.dragComplete(e, u) }
                    });

    // Observe menu items
    j.find('.new_story').bind('mouseup', this.handleMenuClick);
    j.find('.show_burndown_chart').bind('click', function(ev){ self.showBurndownChart(ev) }); // capture 'click' instead of 'mouseup' so we can preventDefault();

    if(this.isSprintBacklog()){
      sprint = RB.Factory.initialize(RB.Sprint, this.getSprint());
    }

    this.drawMenu();

    // Initialize each item in the backlog
    this.getStories().each(function(index){
      story = RB.Factory.initialize(RB.Story, this); // 'this' refers to an element with class="story"
    });
    
    if (this.isSprintBacklog()) this.recalcVelocity();
    
    // Handle New Story clicks
    j.find('.add_new_story').bind('mouseup', self.handleNewStoryClick);
    // Handle New Sprint clicks
    j.find('.add_new_sprint').bind('mouseup', self.handleNewSprintClick);
  },

  afterCreate: function(data, textStatus, xhr){
    this.drawMenu();
  },

  afterUpdate: function(data, textStatus, xhr){
    this.drawMenu();
  },

  drawMenu: function()
  {
    var menu = this.$.find('ul.items');
    var id = null;
    if (this.isSprintBacklog()) {
      id = this.getSprint().data('this').getID();
    }
    if (id == '') { return; } // template sprint

    RB.ajax({
      url: RB.routes.backlog_menu,
      data: (id ? { sprint_id: id } : {}),
      dataType: 'json',
      success   : function(data,t,x) {
        menu.empty() 
        for (var i = 0; i < data.length; i++) {
          li = $('<li class="item"><a href="#"></a></li>');
          $('a', li).attr('href', data[i].url).text(data[i].label);
          if (data[i].class) { $('a', li).attr('class', data[i].class); }
          menu.append(li);
        }
      },
    });
  },
  
  dragComplete: function(event, ui) {
    var isDropTarget = (ui.sender==null);

    // jQuery triggers dragComplete of source and target. 
    // Thus we have to check here. Otherwise, the story
    // would be saved twice.
    if(isDropTarget && ui.item.data('drag-state') == 'dragging'){
      RB.Dialog.notice('saving story');
      ui.item.data('this').saveDragResult();
    }

    this.recalcVelocity();
    this.drawMenu();
  },
  
  dragReceive: function(event, ui) {
    if (ui.item.data('drag-state') != 'dragging') {
      $(ui.sender).sortable('cancel');
    }
  },

  dragStart: function(event, ui) {
    ui.item.addClass("dragging");
    ui.item.data('drag-state', 'dragging');
    // disable invalid drag targets
    //$('#stories-for-117').sortable('disable');
  },
  
  dragBeforeStop: function(event, ui){ 
    // determine valid drop
    ui.item.data('drag-state', 'cancel');

    // RB.Dialog.notice('from: ' + $(ui.sender).attr('id'));
      
    // var to = ui.item.parents('.backlog').data('this').isSprintBacklog() ? ui.item.parents('.backlog').data('this').getSprint().data('this').getID() : 'product backlog';
    // RB.Dialog.notice('to: ' + to);
  },

  dragStop: function(event, ui) { 
    ui.item.removeClass("dragging");  

    // enable all backlogs as drop targets
    $('.stories').sortable('enable');
  },
  
  getSprint: function(){
    return $(this.el).find(".model.sprint").first();
  },
    
  getStories: function(){
    return this.getList().children(".story");
  },

  getList: function(){
    return this.$.children(".stories").first();
  },

  handleNewStoryClick: function(event){
    event.preventDefault();
    $(this).parents('.backlog').data('this').newStory();
  },

  handleNewSprintClick: function(event){
    event.preventDefault();
    $(this).parents('.backlog').data('this').newSprint();
  },

  isSprintBacklog: function(){
    return $(this.el).find('.sprint').length == 1; // return true if backlog has an element with class="sprint"
  },
    
  newStory: function(){
    var story = $('#story_template').children().first().clone();
    
    this.getList().prepend(story);
    o = RB.Factory.initialize(RB.Story, story[0]);
    o.edit();
    story.find('.editor' ).first().focus();
  },
  
  newSprint: function(){
    var sprint_backlog = $('#sprint_template').children().first().clone();

    $("*#sprint_backlogs_container").append(sprint_backlog);
    o = RB.Factory.initialize(RB.Backlog, sprint_backlog);
    o.edit();
    sprint_backlog.find('.editor' ).first().focus();
  },

  recalcVelocity: function(){
    if( !this.isSprintBacklog() ) return true;
    total = 0;
    this.getStories().each(function(index){
      total += $(this).data('this').getPoints();
    });
    this.$.children('.header').children('.velocity').text(total);
  },

  showBurndownChart: function(event){
    event.preventDefault();
    if($("#charts").length==0){
      $( document.createElement("div") ).attr('id', "charts").appendTo("body");
    }
    $('#charts').html( "<div class='loading'>Loading data...</div>");
    $('#charts').load( RB.urlFor('show_burndown_chart', { id: this.getSprint().data('this').getID() }) );
    $('#charts').dialog({ 
                          buttons: { "Close": function() { $(this).dialog("close") } },
                          height: 790,
                          modal: true, 
                          title: 'Charts', 
                          width: 710 
                       });
  }
});
