RB.TaskboardUpdater = RB.Object.create(RB.BoardUpdater, {

  processAllItems: function(data){
    var self = this;
    
    // Process tasks
    var items = RB.$(data).find('.task');
    items.each(function(i, v){
      self.processItem(v, false);
    });

    // Process impediments
    var items = RB.$(data).find('.impediment');
    items.each(function(i, v){
      self.processItem(v, true);
    });
  },
  
  processItem: function(html, isImpediment){
    var update = RB.Factory.initialize(isImpediment ? RB.Impediment : RB.Task, html);
    var target;
    var oldCellID = '';
    var newCell;
    var idPrefix = '#issue_';
    
    if(RB.$(idPrefix + update.getID()).length==0){
      target = update;                                     // Create a new item
    } else {
      target = RB.$(idPrefix + update.getID()).data('this');  // Re-use existing item
      target.refresh(update);
      oldCellID = target.$.parents('td').first().attr('id');
    }

    // Find the correct cell for the item
    newCell = isImpediment ? RB.$('#impcell_' + target.$.find('.meta .status_id').text()) : RB.$('#' + target.$.find('.meta .story_id').text() + '_' + target.$.find('.meta .status_id').text());

    // Prepend to the cell if it's not already there
    if(oldCellID != newCell.attr('id')){
      newCell.prepend(target.$);
    }

    target.$.effect("highlight", { easing: 'easeInExpo' }, 4000);
  },
  
  start: function(){
    this.params = 'only=tasks,impediments';    
    this.initialize();
  }

});
