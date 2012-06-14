/**************************************
  STORY
***************************************/
RB.Story = RB.Object.create(RB.Issue, RB.EditableInplace, {
  initialize: function(el){
    var j;  // This ensures that we use a local 'j' variable, not a global one.
    var self = this;
    
    this.$ = j = RB.$(el);
    this.el = el;
    
    // Associate this object with the element for later retrieval
    j.data('this', this);

    j.delegate('.editable', 'click', this.handleClick);
  },

  afterUpdate: function(data, textStatus, xhr){
    this.$.parents('.backlog').data('this').recalcVelocity();
  },

  afterCreate: function(data, textStatus, xhr){
    this.$.parents('.backlog').data('this').recalcVelocity();
  },

  beforeSave: function(){
    // Do nothing
  },
  
  editDialogTitle: function(){
    return "Story #" + this.getID();
  },

  editorDisplayed: function(editor){
    var tracker = editor.find('.tracker_id.editor');
    var status = editor.find('.status_id.editor');
    var self = this;

    this.setAllowedStatuses(tracker, status);
    tracker.change(function() { self.setAllowedStatuses(tracker, status) });
  },

  setAllowedStatuses: function(tracker, status) {
    var tracker_id = tracker.val();
    var user_status = this.$.find(".user_status").text();
    var status_id = status.val()

    // right after creation, no menu exists to pick from
    if (!status_id || status_id == '') { status_id = RB.constants.story_states['default']; }

    var states = RB.constants.story_states['transitions'][tracker_id][user_status][status_id];
    if (!states) { states = RB.constants.story_states['transitions'][tracker_id][user_status][RB.constants.story_states['transitions'][tracker_id][user_status]['default']]; }

    if (jQuery.inArray(status_id, states) == -1) { // a non-available state is currently selected, tracker has changed
      status_id = null;

      if (this.$.find('.tracker_id .v').text() == tracker_id) { // if we're switching back to the original tracker, select the original state
        status_id = this.$.find('.status_id .v').text();
      } else { // pick first available
        if (states.length != 0) {
          status_id = states[0];
        }
      }
    }

    status.empty();
    for (var i = 0; i < states.length; i++) {
      option = RB.$('<option/>');
      state = RB.constants.story_states['states'][states[i]];
      option.attr('value', states[i]).addClass(state.closed).text(state.name);
      if (states[i] == status_id) { option.attr('selected', 'selected'); }
      status.append(option);
    }
  },
  
  getPoints: function(){
    points = parseFloat( this.$.find('.story_points').first().text() );
    return ( isNaN(points) ? 0 : points );
  },

  getTracker: function(){
	return this.$.find('.tracker_id .t').text();
  },

  getType: function(){
    return "Story";
  },

  markIfClosed: function(){
    // Do nothing
  },
  
  newDialogTitle: function(){
    return "New Story";
  },

  saveDirectives: function(){
    var j = this.$;
    var nxt = this.$.next();
    var sprint_id = this.$.parents('.backlog').data('this').isSprintBacklog() ? 
                    this.$.parents('.backlog').data('this').getSprint().data('this').getID() : '';
        
    var data = "next=" + (nxt.length==1 ? this.$.next().data('this').getID() : '') +
               "&fixed_version_id=" + sprint_id;
    
    j.find('.editor').each(function() {
        var value = jQuery(this).val();  
        data += "&" + this.name + '=' + encodeURIComponent(value);
    });    
    
    if( this.isNew() ){
      var url = RB.urlFor( 'create_story' );
    } else {
      var url = RB.urlFor( 'update_story', { id: this.getID() } );
      data += "&_method=put"
    }
    
    return {
      url: url,
      data: data
    }
  },

  beforeSaveDragResult: function(){

  }
});
  
