/***************************************
  BOARD UPDATER
  Base object that is extended by
  board-type-specific updaters
***************************************/

RB.BoardUpdater = RB.Object.create({
  
  initialize: function(){
    var self = this;
    
    $('#refresh').bind('click', function(e,u){ self.handleRefreshClick(e,u) });
    $('#disable_autorefresh').bind('click', function(e,u){ self.handleDisableAutorefreshClick(e,u) });
    $('#enable_autorefresh').bind('click', function(e,u){ self.handleEnableAutorefreshClick(e,u) });
    
    this.loadPreferences();
    this.pollWait = 1000;
    this.poll()
  },

  adjustPollWait: function(itemsReceived){
    itemsReceived = (itemsReceived==null) ? 0 : itemsReceived;
    
    if(itemsReceived==0 && this.pollWait < 300000 && !$('body').hasClass('no_autorefresh')){
      this.pollWait += 250;
    } else {
      this.pollWait = 1000;
    }
  },

  getData: function(){
    var self = this;

    RB.ajax({
      type      : "GET",
      url       : RB.urlFor('show_updated_items', { id: RB.constants.project_id} ) + '?' + self.params,
      data      : { 
                    since : $('#last_updated').text()
                  },
      beforeSend: function(){ $('body').addClass('loading')  },
      success   : function(d,t,x){ self.processData(d,t,x)  },
      error     : function(){ self.processError() }
    });
  },

  handleDisableAutorefreshClick: function(event, ui){
    $('body').addClass('no_autorefresh');
    RB.UserPreferences.set('autorefresh', !$('body').hasClass('no_autorefresh'));
    if(!$('body').hasClass('no_autorefresh')){
      this.pollWait = 1000;
      this.poll();
    }
  },

  handleEnableAutorefreshClick: function(event, ui){
    $('body').removeClass('no_autorefresh');
    RB.UserPreferences.set('autorefresh', !$('body').hasClass('no_autorefresh'));
  },

  handleRefreshClick: function(event, ui){
    this.getData();
  },

  loadPreferences: function(){
    var ar = RB.UserPreferences.get('autorefresh')=="true";

    if(ar){
      $('body').removeClass('no_autorefresh');
    } else {
      $('body').addClass('no_autorefresh');
    }
  },

  poll: function() {
    if(!$('body').hasClass('no_autorefresh')){
      var self = this;
      setTimeout(function(){ self.getData() }, self.pollWait);
    } else {
      return false;
    }
  },

  processAllItems: function(){
    throw "RB.BoardUpdater.processAllItems() was not overriden by child object";
  },

  processData: function(data, textStatus, xhr){
    var self = this;

    $('body').removeClass('loading');

    var latest_update = $(data).find('#last_updated').text();
    if(latest_update.length > 0) $('#last_updated').text(latest_update);

    self.processAllItems(data);
    self.adjustPollWait($(data).children(":not(.meta)").length);
    self.poll();
  },
  
  processError: function(){
    this.adjustPollWait(0); 
    this.poll();
  }
});