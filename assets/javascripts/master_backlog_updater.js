RB.BacklogsUpdater = RB.Object.create(RB.BoardUpdater, {
  processAllItems: function(data){
    var self = this;

    // Process all stories
    var items = RB.$(data).find('#stories .story');
    items.each(function(i, v){
      try {
        self.processItem(v, false);
      } catch(e) {
//        console.log("BacklogsUpdater.processAllItems exception", e);
      }
    });
  },

  processItem: function(html){
    var update = RB.Factory.initialize(RB.Story, html);
    var target;
    var oldParent;
    var stories;
    
    if(RB.$('#story_' + update.getID()).length===0){
      target = update;                                      // Create a new item
    } else {
      target = RB.$('#story_' + update.getID()).data('this');  // Re-use existing item
      oldParent = RB.$('#story_' + update.getID()).parents(".backlog").first().data('this');
      target.refresh(update);
    }

    // Position the story properly in the backlog
    var previous = update.$.find(".higher_item_id").text();
    if(previous.length > 0){
      target.$.insertAfter( RB.$('#story_' + previous) );
    } else {
      if(target.$.find(".fixed_version_id").text().length===0){
        // Story belongs to the product backlog
        stories = RB.$('#product_backlog_container .backlog .stories');
      } else {
        // Story belongs to a sprint backlog
        stories = RB.$('#sprint_' + target.$.find(".fixed_version_id").text()).siblings(".stories").first();
      }
      stories.prepend(target.$);
    }

    var _ = target.$.find('div.story_tooltip');
    _.qtip(RB.$.qtipMakeOptions(_));

    if(oldParent) { //catch null and undefined
        oldParent.recalcVelocity();
    }
    if (target.$.parents && target.$.parents(".backlog")) {
      target.$.parents(".backlog").first().data('this').recalcVelocity();
    }

    // Retain edit mode and focus if user was editing the
    // story before an update was received from the server    
    if(target.$.hasClass('editing')) {
        target.edit();
    }

    if(target.$.data('focus') && target.$.data('focus').length>0) { //need to catch null and undefined.
        target.$.find("*[name=" + target.$.data('focus') + "]").focus();
    }
        
    target.$.effect("highlight", { easing: 'easeInExpo' }, 4000);
  },

  start: function(){
    this.params     = 'only=stories';
    this.initialize();
  }

});
