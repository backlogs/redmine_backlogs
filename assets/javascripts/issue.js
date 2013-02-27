/**************************************
  ISSUE
***************************************/
RB.Issue = RB.Object.create(RB.Model, {
  
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
