/***************************************
  SPRINT
***************************************/

RB.Sprint = RB.Object.create(RB.Model, RB.EditableInplace, {

  initialize: function(el){
    var j;  // This ensures that we use a local 'j' variable, not a global one.
    var self = this;
    
    this.$ = j = RB.$(el);
    this.el = el;
    
    // Associate this object with the element for later retrieval
    j.data('this', this);

    j.find(".editable").bind('mouseup', this.handleClick);
    
    jQuery('#sprint_backlogs_container')
        .find('div.backlog')
        .each(function() {
            var countItems = jQuery(this).find('ul.ui-sortable > li');
            var ul = jQuery(this).find('ul.ui-sortable');
            if (countItems.length == 0) {
                ul.html('<li style="font-style:italic;text-align:center" class="empty_list_item">List is empty</li>');
            }
        });
  },

  beforeSave: function(){
    // Do nothing
  },

  getType: function(){
    return "Sprint";
  },

  markIfClosed: function(){
    // Do nothing
  },

  refreshed: function(){
    // We have to do this since .live() does not work for some reason
    j.find(".editable").bind('mouseup', this.handleClick);
  },

  saveDirectives: function(){
    var j = this.$;

    var data = j.find('.editor').serialize();

    if( this.isNew() ){
      var url = RB.urlFor( 'create_sprint' );
    } else {
      var url = RB.urlFor( 'update_sprint', { id: this.getID() } );
      data += "&_method=put"
    }

    return {
      url : url,
      data: data
    }
  },

  beforeSaveDragResult: function(){
    // Do nothing
  },

  getBacklog: function(){
    return RB.$(this.el).parents(".backlog").first();
  },

  afterCreate: function(data, textStatus, xhr){
    this.getBacklog().data('this').drawMenu();
    jQuery(this.$).parent()
                  .parent()
                  .find('ul.ui-sortable')
                  .html('<li style="font-style:italic;text-align:center" class="empty_list_item">List is empty</li>')
  },

  afterUpdate: function(data, textStatus, xhr){
    this.getBacklog().data('this').drawMenu();
  }
});
