RB.EditableInplace = RB.Object.create(RB.Model, {

  displayEditor: function(editor){
    this.$.addClass("editing");
    editor.find(".editor").bind('keydown', this.handleKeydown).bind('keypress', this.handleKeypress);
  },

  getEditor: function(){
    // Create the model editor if it does not yet exist
    var editor = this.$.children(".editors").first();
    if(editor.length==0){
      editor = RB.$( document.createElement("div") )
                 .addClass("editors")
                 .appendTo(this.$);
    }
    return editor;
  },

  handleKeypress: function(event) {
    // handle keys on keypress instead of keyup, so IME will not fire enter.
    // https://github.com/ether/pad/pull/168
    if(event.which == 13){
      j = RB.$(this).parents('.model').first();
      that = j.data('this');
      that.saveEdits();
    } else {
      return true;
    }
  },

  handleKeydown: function(event) {
    // handle escape key on keydown, since it doesn't fire keypress on chrome/safari
    // http://stackoverflow.com/questions/3901063/jquerys-keypress-doesnt-work-for-some-keys-in-chrome-how-to-work-around
    if(event.which == 27){
      j = RB.$(this).parents('.model').first();
      that = j.data('this');
      that.cancelEdit();
    } else {
      return true;
    }
  }
});
