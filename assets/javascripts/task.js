/**************************************
  TASK
***************************************/

RB.Task = RB.Object.create(RB.Issue, {
  
  initialize: function(el){
    var j;  // This ensures that we use a local 'j' variable, not a global one.
    
    this.$ = j = RB.$(el);
    this.el = el;
    
    j.addClass("task"); // If node is based on #task_template, it doesn't have the story class yet
    
    // Associate this object with the element for later retrieval
    j.data('this', this);
    
    j.find(".editable").live('mouseup', this.handleClick);
  },

  beforeSave: function(){
    var c = this.$.find('select.assigned_to_id').children(':selected').attr('color');
    this.$.css('background-color', c);
    this.$.css('background', '-webkit-gradient(linear, left top, left bottom, from(#eee), to('+c+'))');
    this.$.css('background', '-moz-linear-gradient(top, #eee, '+c+')');
    this.$.css('filter', 'progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr=#eeeeee,EndColorStr='+c+')');
  },
  
  editorDisplayed: function(dialog){
    dialog_bgcolor=this.$.css('background-color');
    dialog_bg=this.$.css('background');
    if(dialog_bgcolor=='initial'||dialog_bgcolor=='rgba(0, 0, 0, 0)'||dialog_bgcolor=='transparent'){
      // Chrome could not handling background-color css when use -webkit-gradient.
      if((dialog_bg!=null)&&(dialog_bg!='')){
        dialog.parents('.ui-dialog').css('background', dialog_bg);      
      } else {
        dialog.parents('.ui-dialog').css('background', '-webkit-gradient(linear, left top, left bottom, from(#eee), to(#aaa))');
        dialog.parents('.ui-dialog').css('background', '-moz-linear-gradient(top, #eee, #aaa)');
        dialog.parents('.ui-dialog').css('filter', 'progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr=#eeeeee,EndColorStr=#aaaaaa)');
      }
    } else {
      dialog.parents('.ui-dialog').css('background-color', dialog_bgcolor);
    }
  },

  getType: function(){
    return "Task";
  },

  markIfClosed: function(){
    if(this.$.parents('td').first().hasClass('closed')){
      this.$.addClass('closed');
    } else {
      this.$.removeClass('closed');
    }
  },

  saveDirectives: function(){
    var j = this.$;
    var nxt = this.$.next();
    var cellID = j.parents('td').first().attr('id').split("_");

    var data = j.find('.editor').serialize() +
               "&parent_issue_id=" + cellID[0] +
               "&status_id=" + cellID[1] +
               "&next=" + (nxt.length==1 ? nxt.data('this').getID() : '') +
               (this.isNew() ? "" : "&id=" + j.children('.id').text());

    if( this.isNew() ){
      var url = RB.urlFor( 'create_task' );
    } else {
      var url = RB.urlFor( 'update_task', { id: this.getID() } );
      data += "&_method=put"
    }
    
    return {
      url: url,
      data: data
    }
  },

  beforeSaveDragResult: function(){
    if(this.$.parents('td').first().hasClass('closed')){
      // This is only for the purpose of making the Remaining Hours reset
      // instantaneously after dragging to a closed status. The server should
      // still make sure to reset the value to be sure.
      this.$.children('.remaining_hours.editor').val('');
      this.$.children('.remaining_hours.editable').text('');
    }
  }
  
});
