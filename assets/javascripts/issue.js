/**************************************
  ISSUE
***************************************/
RB.Issue = RB.Object.create(RB.Model, {
  
  initialize: function(el){
    var j;
    this.$ = j = RB.$(el);
    this.el = el;
  },
  
  beforeSaveDragResult: function(){
    // Do nothing
  },
  
  getType: function(){
    return "Issue";
  },

  saveDragResult: function(){
    this.beforeSaveDragResult();
    if(!this.$.hasClass('editing')) this.saveEdits();
  }
});
