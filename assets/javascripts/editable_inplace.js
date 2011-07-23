RB.EditableInplace = RB.Object.create(RB.Model, {

  displayEditor: function(editor){
    this.$.addClass("editing");
    editor.find(".editor").bind('keyup', this.handleKeyup).bind('keydown', this.handleKeydown).bind('keypress', this.handleKeypress);
    this.isEnter = false;
    this.isEscape = false;
  },

  getEditor: function(){
    // Create the model editor if it does not yet exist
    var editor = this.$.children(".editors").first();
    if(editor.length==0){
      editor = $( document.createElement("div") )
                 .addClass("editors")
                 .appendTo(this.$);
    }
    return editor;
  },

  handleKeydown: function(event) {
    this.isEnter = (event.which == 13);
    this.isEscape = (event.which == 27);
    return true;
  },
  handleKeypress: function(event) {
    this.isEnter = this.isEnter && (event.which == 13);
    this.isEscape = this.isEscape && (event.which == 27);
    return true;
  },
  handleKeyup: function(event) {
    j = $(this).parents('.model').first();
    that = j.data('this');

    var isEnter = this.isEnter;
    this.isEnter = false;
    var isEscape = this.isEscape;
    this.isEscape = false;

    switch(event.which) {
      case 13:
        if (isEnter) { that.saveEdits();
        } else {
          return true;
        }
        break;

      case 27:
        if (isEscape) { that.cancelEdit();     // ESC
        } else {
            return true;
        }
        break;

      default:
        return true;
    }
  }
});
