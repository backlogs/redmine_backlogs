/**************************************
  IMPEDIMENT
***************************************/

RB.Impediment = RB.Object.create(RB.Task, {
  
  initialize: function(el){
    var j;  // This ensures that we use a local 'j' variable, not a global one.
    
    this.$ = j = RB.$(el);
    this.el = el;
    
    j.addClass("impediment"); // If node is based on #task_template, it doesn't have the impediment class yet
    
    // Associate this object with the element for later retrieval
    j.data('this', this);
    
    if (RB.permissions.update_impediments) {
      j.delegate('.editable', 'click', this.handleClick);
    }
  },
  
  // Override saveDirectives of RB.Task
  saveDirectives: function(){
    var url;
    var j = this.$;
    var nxt = this.$.next();
    var statusID = j.parents('td').first().attr('id').split("_")[1];
      
    var data = j.find('.editor').serialize() +
               "&is_impediment=true" +
               "&fixed_version_id=" + RB.constants['sprint_id'] +
               "&status_id=" + statusID +
               "&next=" + (nxt.length==1 ? nxt.data('this').getID() : '') +
               (this.isNew() ? "" : "&id=" + j.children('.id').text());

    if( this.isNew() ){
      url = RB.urlFor('create_impediment');
    } else {
      url = RB.urlFor('update_impediment', { id: this.getID() });
      data += "&_method=put";
    }
        
    return {
      url: url,
      data: data
    };
  }

});
