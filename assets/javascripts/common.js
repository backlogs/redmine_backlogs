if(RB==null){
  var RB = {};
}

if (RB.$ == null) { RB.$ = jQuery.noConflict(); }

RB.Object = {
  // Douglas Crockford's technique for object extension
  // http://javascript.crockford.com/prototypal.html
  create: function(){
    function F(){}
    F.prototype = arguments[0];
    obj = new F();

    // Add all the other arguments as mixins that
    // 'write over' any existing methods
    for (var i=1; i<arguments.length; i++) {
      var methods = arguments[i];
      if (typeof methods == 'object'){
        for(methodName in methods) obj[methodName] = methods[methodName];
      }
    }
    return obj;
  }  
}


// Object factory for redmine_backlogs
RB.Factory = RB.Object.create({
  
  initialize: function(objType, el){
    obj = RB.Object.create(objType);
    obj.initialize(el);
    return obj;
  }  
  
});

// Utilities
RB.Dialog = RB.Object.create({
  msg: function(msg){
    dialog = RB.$('#msgBox').size()==0 ? RB.$(document.createElement('div')).attr('id', 'msgBox').appendTo('body') : RB.$('#msgBox');
    dialog.html(msg);
    dialog.dialog({ title: 'Backlogs Plugin',
                    buttons: { "OK": function() { RB.$(this).dialog("close"); } },
                    modal: true
                 });
  },
  
  notice: function(msg){
    if(typeof console != "undefined" && console != null) console.log(msg);
  }
});

RB.ajaxQueue = new Array()
RB.ajaxOngoing = false;

RB.ajax = function(options){
  RB.ajaxQueue.push(options);
  if(!RB.ajaxOngoing){ RB.processAjaxQueue(); }
}

RB.processAjaxQueue = function(){
  var options = RB.ajaxQueue.shift();

  if(options!=null){
    RB.ajaxOngoing = true;
    RB.$.ajax(options);
  }
}

RB.$(document).ajaxComplete(function(event, xhr, settings){
  RB.ajaxOngoing = false;
  RB.processAjaxQueue();
});

// Modify the ajax request before being sent to the server
RB.$(document).ajaxSend(function(event, request, settings) {
  settings.data = settings.data || "";

  if (settings.data.indexOf("project_id=") == -1) {
    settings.data += (settings.data ? "&" : "") + "project_id=" + RB.constants.project_id;
  }

  if(RB.constants.protect_against_forgery){
      settings.data += "&" + RB.constants.request_forgery_protection_token + "=" + encodeURIComponent(RB.constants.form_authenticity_token);
  }
});

// Abstract the user preference from the rest of the RB objects
// so that we can change the underlying implementation as needed
RB.UserPreferences = RB.Object.create({
  get: function(key){
    return RB.$.cookie(key);
  },
  
  set: function(key, value){
    RB.$.cookie(key, value, { expires: 365 * 10 });
  }
});
