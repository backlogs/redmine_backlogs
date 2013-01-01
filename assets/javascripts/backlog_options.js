RB.BacklogOptions = RB.Object.create({
  containers: {},

  initialize: function(el) {
    var me = this,
      _ = RB.constants.locale._;

    RB.$('#toolbar').append('<div class="tb_mnu_btn"><select class="view_options_menu"></select></div>');
    me.el = RB.$(".view_options_menu");

    var hidden = this.loadState();
    RB.$('.backlog').each(function() { //now this binds to .backlog dom node
      var id = RB.$(this).find('.headertext').attr('id');
      if (id === "") return; //skip sprint edit template
      if (id === undefined) id = 'product_backlog';
      var name = RB.$(this).find('.headertext .name').text();
      var container = RB.$(this).find('.headertext').parents('.backlog');
      var checked = false;
      var selected = '';
      if (RB.$.inArray(id, hidden) == -1) {
         selected = ' selected="selected"';
         checked = true;
      }

      me.el.append('<option value = "'+id+'"'+selected+'>'+name+'</option>');
      me.containers[id] = {
        el:container,
        checked: checked,
        optEl: me.el.children('option').last()
      };
    });
    console.log("XXX", this.containers);
    me.el.multiselect({
      //selectedText: _("View options"),
      noneSelectedText: _("View options"),
      checkAll: function() { me.onCheckAll(); },
      uncheckAll: function() { me.onUnCheckAll(); },
      click: function(e, o) { me.onClick(e, o); }
    });
    this.updateUI();
  },

  updateUI: function() {
    for (var i in this.containers) {
      if (this.containers[i].checked) {
        this.containers[i].el.show();
      } else {
        this.containers[i].el.hide();
      }
    }
    this.saveState();
  },

  onCheckAll: function() {
    for (var i in this.containers) {
      this.containers[i].checked = true;
    }
    this.updateUI();
  },

  onUnCheckAll: function() {
    for (var i in this.containers) {
      this.containers[i].checked = false;
    }
    this.updateUI();
  },

  onClick: function(e, ui) {
    if (!this.containers[ui.value]) return;
    this.containers[ui.value].checked = ui.checked;
    this.updateUI();
  },

  saveState: function() {
    var hidden=[], i;
    for (i in this.containers) {
      if (!this.containers[i].checked) { hidden.push(i); }
    }
    RB.UserPreferences.set('master_bl_viewoptions', hidden.join(','));
  },

  loadState: function() {
    var hidden = RB.UserPreferences.get('master_bl_viewoptions') || '';
    hidden = hidden.split(',');
    if (!hidden) {
      return [];
    }
    return hidden;
  }
});
