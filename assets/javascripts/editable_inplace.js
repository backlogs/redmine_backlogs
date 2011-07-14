RB.EditableInplace = RB.Object.create(RB.Model, {

  displayEditor: function(editor){
    this.$.addClass("editing");
    editor.find(".editor").bind('keyup', this.handleKeyup).bind('keydown', this.handleKeydown).bind('keypress', this.handleKeypress);
    this.isEnter = false;
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
    return true;
  },
  handleKeypress: function(event) {
    this.isEnter = this.isEnter && (event.which == 13);
    return true;
  },
  handleKeyup: function(event) {
    j = $(this).parents('.model').first();
    that = j.data('this');

    var isEnter = this.isEnter;
    this.isEnter = false;

    switch(event.which) {
      case 13:
        if (isEnter) { that.saveEdits();
        } else {
          return true;
        }
        break;

      case 27:
        that.cancelEdit();     // ESC
        break;

      default:
        return true;
    }
  }
});
