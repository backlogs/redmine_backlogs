/***************************************
  RELEASE
***************************************/

RB.Release = RB.Object.create(RB.Sprint, {
  update_permission: 'update_releases',
  create_url: 'create_release',
  update_url: 'update_release',

  getType: function(){
    return "Release";
  },

  editorDisplayed: function(editor){
    var name = editor.find('.name.editor');
    name.width(Math.max(300, parseInt(name.attr('_rb_width'), 10)));
    var d = new Date();
    var now, start, end;
    start = editor.find('.release_start_date.editor');
    if (start.val()=='no start') {
      now = RB.$.datepicker.formatDate('yy-mm-dd', new Date());
      start.val(now);
    }
    end = editor.find('.end_date.editor');
    if (end.val()=='no end') {
      now = new Date();
      now.setDate(now.getDate() + 14);
      now = RB.$.datepicker.formatDate('yy-mm-dd', now);
      end.val(now);
    }
  }
});
