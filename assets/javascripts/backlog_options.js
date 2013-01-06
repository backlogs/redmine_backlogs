RB.BacklogOptions = RB.Object.create({
  containers: {},

  initialize: function(el) {
    var me = this,
      _ = RB.constants.locale._;

    // prepare container
    RB.$('#toolbar').
      append( RB.$('<div class="tb_mnu_btn" />').
              append( (me.el = RB.$('<select class="view_options_menu" />') )));

    // load hidden sprint ids from cookie
    var hidden = this.loadState();

    // iterate through visible backlogs
    this._init_backlogs('#sprint_backlogs_container', _('Sprints'), hidden);
    this._init_backlogs('#product_backlog_container', _('Backlogs'), hidden);

    // render the selection dialog
    me.el.multiselect({
      noneSelectedText: _("View options"),
      selectedText: _("View options")+ " (#)",
      checkAll: function() { me.onCheckAll(); },
      uncheckAll: function() { me.onUnCheckAll(); },
      optgrouptoggle: function(e, o) { me.onOptgroupToggle(e, o); },
      click: function(e, o) { me.onClick(e, o); }
    });
    // refresh user interface
    this.updateUI();
  },

  _init_backlogs: function(selector, label, hidden) {
    var me = this,
      optgrp;
    me.el.append( optgrp = RB.$('<optgroup label="'+label+'" />'));
    RB.$(selector+' .backlog').each(function() { //now this binds to .backlog dom node
      var id, name, container, checked, selected, optEl;
      // get the backlog id
      id = RB.$(this).find('.headertext').attr('id');
      if (id === "") return; //skip sprint edit template
      if (id === undefined) id = 'product_backlog';

      name = RB.$(this).find('.headertext .name').text();
      container = RB.$(this).find('.headertext').parents('.backlog');
      // set the selected state to the option
      checked = false;
      selected = '';
      if (RB.$.inArray(id, hidden) == -1) {
         selected = ' selected="selected"';
         checked = true;
      }

      // add the option for current backlog
      optgrp.append( (optEl = RB.$('<option value = "'+id+'"'+selected+'>'+name+'</option>') ));
      // track states and containers in order to easily update them later
      me.containers[id] = {
        el:container,
        checked: checked,
        optEl: optEl
      };
    });
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

  onOptgroupToggle: function(e, ui) {
    for (var i=0; i<ui.inputs.length; i++) {
      var id = ui.inputs[i].value;
      if (this.containers[id]) this.containers[id].checked = ui.checked;
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
