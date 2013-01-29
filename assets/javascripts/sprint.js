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

    if (RB.permissions.update_sprints) {
      j.delegate('.editable', 'click', this.handleClick);
    }
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
    var url;
    var data = j.find('.editor').serialize();

    if( this.isNew() ){
      url = RB.urlFor( 'create_sprint' );
    } else {
      url = RB.urlFor( 'update_sprint', { id: this.getID() } );
      data += "&_method=put";
    }

    return {
      url : url,
      data: data
    };
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
  },

  editorDisplayed: function(editor){
    var name = editor.find('.name.editor');
    name.width(Math.max(300, parseInt(name.attr('_rb_width'), 10)));
    var d = new Date();
    var now, start, end;
    start = editor.find('.sprint_start_date.editor');
    if (start.val()=='no start') {
      now = RB.$.datepicker.formatDate('yy-mm-dd', new Date());
      start.val(now);
    }
    end = editor.find('.effective_date.editor');
    if (end.val()=='no end') {
      now = new Date();
      now.setDate(now.getDate() + 14);
      now = RB.$.datepicker.formatDate('yy-mm-dd', now);
      end.val(now);
    }
  }
});
