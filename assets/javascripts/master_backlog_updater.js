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
    var update = RB.Factory.initialize(RB.Story, html),
        target,
        oldParent,
        stories;
    
    if(RB.$('#story_' + update.getID()).length===0){
      target = update;                                      // Create a new item
    } else {
      target = RB.$('#story_' + update.getID()).data('this');  // Re-use existing item
      oldParent = RB.$('#story_' + update.getID()).parents(".backlog").first().data('this');
      target.refresh(update);
    }

    // Position the story properly in the backlog
    var higher_item = null,
        previous = update.$.find(".higher_item_id").text(),
        fixed_version_id = target.$.find(".fixed_version_id").text(),
        release_id = target.$.find(".release_id").text();

    //find the correct container
    if (fixed_version_id !== '') { //sprint
      stories = RB.$('#stories-for-' + fixed_version_id);
    }
    else if (release_id !== '') { //release
      stories = RB.$('#stories-for-release-' + release_id);
    }
    else { //backlog
      stories = RB.$('#stories-for-product-backlog');
    }
    // put after higher_item (FIXME name is confusing) or at top
    if (previous.length) {
      higher_item = stories.find('#story_' + previous);
    }
    if (higher_item && higher_item.length) { //FIXME not having found higher item means a) we are first OR b) the backend gave us one which is not in this backlog OR not in the current scope (other project? other tracker?)
      target.$.insertAfter(higher_item);
    }
    else {
      stories.first().prepend(target.$);
    }

    //update tooltip
    RB.util.refreshToolTip(target);

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
