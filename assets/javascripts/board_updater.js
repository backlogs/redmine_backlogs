/***************************************
  BOARD UPDATER
  Base object that is extended by
  board-type-specific updaters
***************************************/

RB.BoardUpdater = RB.Object.create({
  
  initialize: function(){
    var self = this;
 
    RB.$('#refresh').bind('click', function(e,u){ self.handleRefreshClick(e,u); });
    RB.$('#disable_autorefresh').bind('click', function(e,u){ self.handleDisableAutorefreshClick(e,u); });

    this.loadPreferences();
    this.pollWait = RB.constants.autorefresh_wait;
    this.poll();
  },

  adjustPollWait: function(itemsReceived){
    itemsReceived = (itemsReceived==null) ? 0 : itemsReceived;
    
    if(itemsReceived==0 && this.pollWait < 300000 && !RB.$('body').hasClass('no_autorefresh')){
      this.pollWait += 250;
    } else {
      this.pollWait = RB.constants.autorefresh_wait;
    }
  },

  getData: function(){
    var self = this;

    RB.ajax({
      type      : "GET",
      url       : RB.urlFor('show_updated_items', { id: RB.constants.project_id} ) + '?' + self.params,
      data      : { 
                    since : RB.$('#last_updated').text()
                  },
      beforeSend: function(){ RB.$('body').addClass('loading');  },
      success   : function(d,t,x){ self.processData(d,t,x);  },
      error     : function(){ self.processError(); }
    });
  },

  handleDisableAutorefreshClick: function(event, ui){
    RB.$('body').toggleClass('no_autorefresh');
    RB.UserPreferences.set('autorefresh', !RB.$('body').hasClass('no_autorefresh'));
    if(!RB.$('body').hasClass('no_autorefresh')){
      this.pollWait = RB.constants.autorefresh_wait;
      this.poll();
    }
    this.updateAutorefreshText();
  },

  handleRefreshClick: function(event, ui){
    this.getData();
  },

  loadPreferences: function(){
    var ar = RB.UserPreferences.get('autorefresh')=="true";

    if(ar){
      RB.$('body').removeClass('no_autorefresh');
    } else {
      RB.$('body').addClass('no_autorefresh');
    }
    this.updateAutorefreshText();
  },

  poll: function() {
    if(!RB.$('body').hasClass('no_autorefresh')){
      var self = this;
      setTimeout(function(){ self.getData(); }, self.pollWait);
    } else {
      return false;
    }
  },

  processAllItems: function(){
    throw "RB.BoardUpdater.processAllItems() was not overriden by child object";
  },

  processData: function(data, textStatus, xhr){
    var self = this, latest_update;

    RB.$('body').removeClass('loading');

    latest_update = RB.$(data).find('#last_updated').text();
    if(latest_update.length > 0) {
        RB.$('#last_updated').text(latest_update);
    }

    self.processAllItems(data);
    self.adjustPollWait(RB.$(data).children(":not(.meta)").length);
    self.poll();
  },
  
  processError: function(){
    this.adjustPollWait(0); 
    this.poll();
  },

  updateAutorefreshText: function(){
    if(RB.$('body').hasClass('no_autorefresh')){
      RB.$('#disable_autorefresh').text('Enable Auto-refresh');
    } else {
      RB.$('#disable_autorefresh').text('Disable Auto-refresh');
    }
  }
});
