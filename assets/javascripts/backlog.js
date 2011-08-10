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
    
    this.$ = j = RB.$(el);
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
                    stop: this.dragStop,
                    update: function(e,u){ self.dragComplete(e, u) }
                    });

    if(this.isSprintBacklog()){
      sprint = RB.Factory.initialize(RB.Sprint, this.getSprint());
    }

    this.drawMenu();

    // Initialize each item in the backlog
    this.getStories().each(function(index){
      story = RB.Factory.initialize(RB.Story, this); // 'this' refers to an element with class="story"
    });
    
    if (this.isSprintBacklog()) this.recalcVelocity();
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
    var self = this;
    if (this.isSprintBacklog()) {
      id = this.getSprint().data('this').getID();
    }
    if (id == '') { return; } // template sprint

    RB.ajax({
      url: RB.routes.backlog_menu,
      data: (id ? { sprint_id: id } : {}),
      dataType: 'json',
      success   : function(data,t,x) {
        menu.empty();
        if (data) {
          for (var i = 0; i < data.length; i++) {
            li = RB.$('<li class="item"><a href="#"></a></li>');
            RB.$('a', li).attr('href', data[i].url).text(data[i].label);
            if (data[i].classname) { RB.$('a', li).attr('class', data[i].classname); }
            menu.append(li);
          }
        }
        menu.find('.add_new_story').bind('mouseup', self.handleNewStoryClick);
        menu.find('.add_new_sprint').bind('mouseup', self.handleNewSprintClick);
        // capture 'click' instead of 'mouseup' so we can preventDefault();
        menu.find('.show_burndown_chart').bind('click', function(ev){ self.showBurndownChart(ev) });
      }
    });
  },
  
  dragComplete: function(event, ui) {
    var isDropTarget = (ui.sender==null);

    // jQuery triggers dragComplete of source and target. 
    // Thus we have to check here. Otherwise, the story
    // would be saved twice.
    if(isDropTarget){
      ui.item.data('this').saveDragResult();
    }

    this.recalcVelocity();
    this.drawMenu();
  },
  
  dragStart: function(event, ui){ 
    ui.item.addClass("dragging");
  },
  
  dragStop: function(event, ui){ 
    ui.item.removeClass("dragging");  
  },
  
  getSprint: function(){
    return RB.$(this.el).find(".model.sprint").first();
  },
    
  getStories: function(){
    return this.getList().children(".story");
  },

  getList: function(){
    return this.$.children(".stories").first();
  },

  handleNewStoryClick: function(event){
    event.preventDefault();
    RB.$(this).parents('.backlog').data('this').newStory();
  },

  handleNewSprintClick: function(event){
    event.preventDefault();
    RB.$(this).parents('.backlog').data('this').newSprint();
  },

  isSprintBacklog: function(){
    return RB.$(this.el).find('.sprint').length == 1; // return true if backlog has an element with class="sprint"
  },
    
  newStory: function() {
    var story = RB.$('#story_template').children().first().clone();
    
    this.getList().prepend(story);
    o = RB.Factory.initialize(RB.Story, story[0]);
    o.edit();
    story.find('.editor' ).first().focus();
    RB.$('html,body').animate({
        scrollTop: story.find('.editor').first().offset().top-100
        }, 200);
  },
  
  newSprint: function(){
    var sprint_backlog = RB.$('#sprint_template').children().first().clone();

    RB.$("*#sprint_backlogs_container").append(sprint_backlog);
    o = RB.Factory.initialize(RB.Backlog, sprint_backlog);
    o.edit();
    sprint_backlog.find('.editor' ).first().focus();
    RB.$('html,body').animate({
        scrollTop: sprint_backlog.find('.editor').first().offset().top
        }, 200);
  },

  recalcVelocity: function(){
    if( !this.isSprintBacklog() ) return true;
    total = 0;
    this.getStories().each(function(index){
      total += RB.$(this).data('this').getPoints();
    });
    this.$.children('.header').children('.velocity').text(total);
  },

  showBurndownChart: function(event){
    event.preventDefault();
    if(RB.$("#charts").length==0){
      RB.$( document.createElement("div") ).attr('id', "charts").appendTo("body");
    }
    RB.$('#charts').html( "<div class='loading'>Loading data...</div>");
    RB.$('#charts').load( RB.urlFor('show_burndown_chart', { id: this.getSprint().data('this').getID() }) );
    RB.$('#charts').dialog({ 
                          buttons: { "Close": function() { RB.$('#charts').dialog("close") } },
                          height: 590,
                          modal: true, 
                          title: 'Charts', 
                          width: 710 
                       });
  }
});
