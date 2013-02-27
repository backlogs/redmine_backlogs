/* pure mixin. use along with Model */
RB.EditableInplace = RB.Object.create({

  displayEditor: function(editor){
    var self = this;

    editor.find('textarea').attr('cols', '5');
    editor.find('textarea').attr('rows', '3');
    this.$.addClass("editing");
    editor.find(".editor").bind('keydown', this.handleKeydown).bind('keypress', this.handleKeypress);

    //TODO: get localized Save and Cancel text
    var saveText = 'Save',
        cancelText = 'Cancel';
    RB.$('<div class="edit-actions"/>').
      append(
        RB.$('<a href="#" class="save"/>').text(saveText).
          click(function(e) {
            e.preventDefault();
            self.saveEdits();
          })).
      append(
        RB.$('<a href="#" class="cancel"/>').text(cancelText).
          click(function(e) {
            e.preventDefault();
            self.cancelEdit();
          })).
      appendTo(editor);

    if (!editor.find('div.clearfix')) {
        editor.append('<div class="clearfix"></div>');
    }
  },

  getEditor: function(){
    // Create the model editor if it does not yet exist
    var editor = this.$.children(".editors").first();
    if (!editor.length){
      var clearfix = this.$.find('div.clearfix');
      if (clearfix.length) { //put editor before story clearfix
        editor = RB.$(document.createElement("div")).addClass("editors").insertBefore(clearfix);
      }
      else { // sprint title has no clearfix
        editor = RB.$(document.createElement("div")).addClass("editors").appendTo(this.$);
      }
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
      that.cancelEdit(that);
    } else {
      return true;
    }
  }
});
