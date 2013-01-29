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
    this.groupnames = ['#sprint_backlogs_container', '#product_backlog_container'];
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
        optEl: optEl,
        optGrpselector: selector
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
    this.updatePageLayout();
  },

  /**
   * check if either left or right pane is empty and then
   * expand the other pane to full width
   */
  updatePageLayout: function(showAll) {
    var i, groups={}, ct, grpname1, grpname2;
    grpname1 = this.groupnames[0];
    panel1 = RB.$(grpname1).parent();
    grpname2 = this.groupnames[1];
    panel2 = RB.$(grpname2).parent();
    panel1.show(); panel2.show();
    if (showAll) {
      panel1.width("50%");
      panel2.width("50%");
      return;
    }

    for (i in this.containers) {
      ct = this.containers[i];
      if (ct.el.is(':visible')) {
        groups[ct.optGrpselector] = true;
      }
    }

    if (!groups[grpname1]) { panel1.hide(); }
    if (!groups[grpname2]) { panel2.hide(); }
    panel1.width( groups[grpname2] ? "50%" : "100%");
    panel2.width( groups[grpname1] ? "50%" : "100%");
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
  },

  showSprintPanel: function() {
    this.updatePageLayout(true);
  }
});

RB.BacklogMultilineBtn = {
  main_class: 'rb-multilinesubject',

  initialize: function(el) {
    var me = this;
    me.main = RB.$('#main');
    if (RB.UserPreferences.get('rb_bl_multiline', true) == 'multiline') {
      me.main.addClass(me.main_class);
    }
    el.bind('click', function(e,u) {
      me.main.toggleClass(me.main_class);
      RB.UserPreferences.set('rb_bl_multiline',
        me.main.hasClass(me.main_class) ? 'multiline':'',
        true);
    });
  }
};
