/***************************************
  MODEL FIXME: rename this to EDITABLE
  Common methods for sprint, issue,
  story, task, and impediment
  mostly about editing these.
***************************************/

RB.Model = RB.Object.create({

  initialize: function(el){
    this.$ = RB.$(el);
    this.el = el;
  },

  afterCreate: function(data, textStatus, xhr){
    // Do nothing. Child objects may optionally override this
  },

  afterSave: function(data, textStatus, xhr){
    var isNew = this.isNew();
    var result = RB.Factory.initialize(RB.Model, data);
    this.unmarkSaving();
    this.refresh(result);
    if(isNew){
      this.$.attr('id', result.$.attr('id'));
      this.afterCreate(data, textStatus, xhr);
    } else {
      this.afterUpdate(data, textStatus, xhr);
    }
  },
  
  afterUpdate: function(data, textStatus, xhr){
    // Do nothing. Child objects may optionally override this
  },

  beforeSave: function(){
    // Do nothing. Child objects may or may not override this method
  },

  cancelEdit: function(obj){
    this.endEdit();
    if (typeof obj == 'undefined') {
        obj = this;
    }
    obj.$.find('.editors').remove();
    if(this.isNew()){
      this.$.hide('blind');
    }
  },
  
  close: function(){
    this.$.addClass('closed');
  },

  copyFromDialog: function(){
    var editors = (!this.$.find(".editors").length) ? RB.$(document.createElement("div")).addClass("editors").appendTo(this.$) : this.$.find(".editors").first();
    editors.html("");
    editors.append(RB.$("#" + this.getType().toLowerCase() + "_editor").children(".editor"));
    this.saveEdits();
  },

  displayEditor: function(editor){
    var pos = this.$.offset();
    var self = this;
    
    editor.dialog({
      buttons: {
        "Cancel" : function(){ self.cancelEdit(); RB.$(this).dialog("close"); },
        "OK" : function(){ self.copyFromDialog(); RB.$(this).dialog("close"); }
      },
      close: function(event, ui){ if(event.which==27) self.cancelEdit(); },
      dialogClass: self.getType().toLowerCase() + '_editor_dialog rb_editor_dialog',
      modal: true,
      position: [pos.left - RB.$(document).scrollLeft(), pos.top - RB.$(document).scrollTop()],
      resizable: false,
      title: (this.isNew() ? this.newDialogTitle() : this.editDialogTitle())
    });
    editor.find(".editor").first().focus();
  },

  edit: function(){
    var editor = this.getEditor();
    
    // 'this' can change below depending on the context.
    var self = this;
    
    this.$.find('.editable').each(function(index){
      var field = RB.$(this);
      var fieldType = field.attr('fieldtype') ? field.attr('fieldtype') : 'input';
      var fieldName = field.attr('fieldname');
      var fieldLabel = field.attr('fieldlabel');
      var input;
      
      RB.$(document.createElement("label")).text(fieldLabel).appendTo(editor);
      input = fieldType=='select' ? RB.$('#' + fieldName + '_options').clone(true) : RB.$(document.createElement(fieldType));
      input.removeAttr('id');
      input.attr('name', fieldName);
      input.addClass(fieldName);
      input.addClass('editor');
      input.removeClass('template');
      input.removeClass('helper');
      input.attr('_rb_width', field.width());
      // Add a date picker if field is a date field
      if (field.hasClass("date")){
        input.datepicker({ changeMonth: true,
                           changeYear: true,
                           closeText: 'Close',
                           dateFormat: 'yy-mm-dd', 
                           firstDay: 1,
                           onClose: function(){ RB.$(this).focus(); },
                           selectOtherMonths: true,
                           showAnim:'',
                           showButtonPanel: true,
                           showOtherMonths: true
                       });
        // So that we won't need a datepicker button to re-show it
        input.bind('mouseup', function(event){ RB.$(this).datepicker("show"); });
      }
      
      // Copy the value in the field to the input element
      value = ( fieldType=='select' ? field.children('.v').first().text() : RB.$.trim(field.text()) );
      input.val(value);
      
      // Record in the model's root element which input field had the last focus. We will
      // use this information inside RB.Model.refresh() to determine where to return the
      // focus after the element has been refreshed with info from the server.
      input.focus( function(){ self.$.data('focus', RB.$(this).attr('name')); } ).
            blur( function(){ self.$.data('focus', ''); } );
      
      input.appendTo(editor);
    });

    this.displayEditor(editor);
    this.editorDisplayed(editor);
    return editor;
  },
  
  // Override this method to change the dialog title
  editDialogTitle: function(){
    return "Edit " + this.getType();
  },
  
  editorDisplayed: function(editor){
    // Do nothing. Child objects may override this.
  },
  
  endEdit: function(){
    this.$.removeClass('editing');
  },
  
  error: function(xhr, textStatus, error){
    this.markError();

    var msg = null;
    try { msg = RB.$(xhr.responseText).find('.errors').html(); } catch (err) { msg = null; }
    if (!msg) { msg = xhr.responseText.match(/<h1>[\s\S]*?<\/pre>/i); }
    if (!msg) { msg = xhr.responseText.match(/<h1>[\s\S]*?<\/h1>/i); }
    if (!msg) { msg = xhr.responseText; }
    if (msg instanceof Array) { msg = msg[0]; }
    if (!msg || !msg.length) {
      msg = 'an error occured, please check the server logs (' + xhr.statusText + ')';
      RB.Dialog.notice(xhr.statusText + ': ' + xhr.responseText);
    }
    msg = msg.replace(/<h1>/ig, '<b>').replace(/<\/h1>/ig, '</b>: ').replace(/<\/?pre>/ig, '');
    RB.Dialog.msg(msg);
    this.processError(xhr, textStatus, error);
  },
  
  getEditor: function(){
    // Create the model editor if it does not yet exist
    var editor_id = this.getType().toLowerCase() + "_editor";
    var editor = RB.$("#" + editor_id).html("");
    if(!editor.length){
      editor = RB.$( document.createElement("div") ).
                 attr('id', editor_id).
                 addClass('rb_editor').
                 appendTo("body");
    }
    return editor;
  },
  
  getID: function(){
    return this.$.find('.id .v').text();
  },
  
  getType: function(){
    throw "Child objects must override getType()";
  },
    
  handleClick: function(event){
    if(event.button !== 0) return; // only respond to left click
    var field = RB.$(this);
    var model = field.parents('.model').first().data('this');
    var j = model.$;
    if(!j.hasClass('editing') && !j.hasClass('dragging') && !RB.$(event.target).hasClass('prevent_edit')){
      var editor = model.edit();
      editor.find('.' + RB.$(event.currentTarget).attr('fieldname') + '.editor').focus();
    }
  },

  handleSelect: function(event){
    var j = RB.$(this);
    var self = j.data('this');

    if(!RB.$(event.target).hasClass('editable') && 
       !RB.$(event.target).hasClass('checkbox') &&
       !j.hasClass('editing') &&
       event.target.tagName!='A' &&
       !j.hasClass('dragging')){
      self.setSelection(!self.isSelected());
    }
  },

  isClosed: function(){
    return this.$.hasClass('closed');
  },
  
  isNew: function(){
    return !(this.getID());
  },

  markError: function(){
    this.$.addClass('error');
  },
  
  markIfClosed: function(){
    throw "Child objects must override markIfClosed()";
  },
  
  markSaving: function(){
    this.$.addClass('saving');
  },

  // Override this method to change the dialog title
  newDialogTitle: function(){
    return "New " + this.getType();
  },
    
  open: function(){
    this.$.removeClass('closed');
  },

  processError: function(x,t,e){
    // Do nothing. Feel free to override
  },

  refresh: function(obj){
    this.$.html(obj.$.html());
    this.$[0].className = obj.$[0].className; //this.$.attr('class', obj.$.attr('class'));
    if(obj.isClosed()){
      this.close();
    } else {
      this.open();
    }
    this.refreshed();
  },
  
  refreshed: function(){
    // Override as needed
  },

  saveDirectives: function(){
    throw "Child object must implement saveDirectives()";
  },

  saveEdits: function(){
    var j = this.$;
    var self = this;
    var editors = j.find('.editor');
    
    // Copy the values from the fields to the proper html elements
    editors.each(function(index){
      editor = RB.$(this);
      fieldName = editor.attr('name');
      if(this.type.match(/select/)){
        j.children('div.' + fieldName).children('.v').text(editor.val());
        j.children('div.' + fieldName).children('.t').text(editor.children(':selected').text());
      // } else if(this.type.match(/textarea/)){
      //   this.setValue('div.' + fieldName + ' .textile', editors[ii].value);
      //   this.setValue('div.' + fieldName + ' .html', '-- will be displayed after save --');
      } else {
        j.children('div.' + fieldName).text(editor.val());
      }
    });

    // Mark the issue as closed if so
    self.markIfClosed();

    // Get the save directives.
    var saveDir = self.saveDirectives();

    self.beforeSave();

    self.unmarkError();
    self.markSaving();
    
    RB.ajax({
       type: "POST",
       url: saveDir.url,
       data: saveDir.data,
       success: function(d, t, x){
          self.afterSave(d,t,x);
          self.refreshTooltip(self);
       },
       error : function(x,t,e){ self.error(x,t,e); }
    });

    self.endEdit();
    self.$.find('.editors').remove();
  },

  refreshTooltip: function(model) {
    if (typeof RB.$.qtipMakeOptions != 'function') {
        return;
    }
    if (typeof model == 'undefined') {
        model = this;
    }
    RB.util.refreshToolTip(model);
  },
  
  unmarkError: function(){
    this.$.removeClass('error');
  },
  
  unmarkSaving: function(){
    this.$.removeClass('saving');
  }
});
