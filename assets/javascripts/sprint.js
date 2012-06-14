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

    j.delegate('.editable', 'click', this.handleClick);
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
    // Do nothing
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
  },

  afterUpdate: function(data, textStatus, xhr){
    this.getBacklog().data('this').drawMenu();
  }
});
