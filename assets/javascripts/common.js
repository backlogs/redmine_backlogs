var RB = RB || {}; // declare namespace

/* It is utterly important that this script comes AFTER any 3rd party jquery plugins */
if (!RB.$) {
  RB.$ = jQuery.noConflict(true);//completely restore redmines jquery
  if (!window.$) { // restore $ to redmine original (jquery 2.1+ or prototype 2.0) or make it jquery if not a redmine view.
    $ = RB.$;
  }
  //global jQuery is not available anymore.
  if (!window.jQuery) { // restore jQuery to redmine if it was jQuery in the first place (2.1+) or use backlogs (2.0)
    jQuery = $ || RB.$; // this can mask errors of uncleanly written plugins (jqplot) but will allow redmine to function for such cases.
  }
}

RB.Object = {
  // Douglas Crockford's technique for object extension
  // http://javascript.crockford.com/prototypal.html
  create: function(){
    function F(){}
    F.prototype = arguments[0];
    var obj = new F();

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
};


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
    var dialog = !RB.$('#msgBox').length ? RB.$('<div id="msgBox" />').appendTo('body') : RB.$('#msgBox');
    dialog.html(msg);
    dialog.dialog({ title: 'Backlogs Plugin',
                    buttons: { "OK": function() { RB.$(this).dialog("close"); } },
                    modal: true
                 });
  },
  
  notice: function(msg){
    if(window.console && typeof console.log == "function") console.log(msg);
  }
});

RB.ajaxQueue = new Array();
RB.ajaxOngoing = false;

RB.ajax = function(options){
  //normalize passed option data: converts from object or array in $.serializeArray format
  options.data = options.data || "";
  if (typeof options.data != "string") {
    options.data = RB.$.param(options.data);
  }

  // add auto-parameter: project_id and csrf
  if (options.data.indexOf("project_id=") == -1) {
    options.data += (options.data ? "&" : "") + "project_id=" + RB.constants.project_id;
  }
  if(RB.constants.protect_against_forgery){
    options.data += "&" + RB.constants.request_forgery_protection_token +
                    "=" + encodeURIComponent(RB.constants.form_authenticity_token); 
  }

  RB.ajaxQueue.push(options);
  if(!RB.ajaxOngoing){ RB.processAjaxQueue(); }
};

RB.processAjaxQueue = function(){
  var options = RB.ajaxQueue.shift();

  if(options){
    RB.ajaxOngoing = true;
    RB.$.ajax(options).
      always(function() {
      /**
       * callback: after success or fail.
       * maintain queue state and requeue next request.
       * Beware: we do not use arguments here, 
       * the signature depends on success/fail of the request. That is just braindead.
       */
        RB.ajaxOngoing = false;
        RB.processAjaxQueue();
      });
  }
};

// Abstract the user preference from the rest of the RB objects
// so that we can change the underlying implementation as needed
RB.UserPreferences = RB.Object.create({
  get: function(key, global){
    var path = RB.urlFor('home')+'rb';
    try {
      if (global) return RB.$.cookie(key, undefined, {path: path});
      return RB.$.cookie(key);
    } catch(e) { return null; }
  },
  
  set: function(key, value, global){
    if (global) {
      var path = RB.urlFor('home')+'rb';
      RB.$.cookie(key, value, { expires: 365 * 10, path: path });
    }
    else {
      RB.$.cookie(key, value, { expires: 365 * 10 });
    }
  }
});

RB.util = {
  initToolTip: function() {
    RB.$('div.story_tooltip').each(function(el) {
        var _ = RB.$(this);
        _.qtip(RB.$.qtipMakeOptions(_));
    });
    RB.$('div.story_tooltip_ajax').each(function(el) {
        var _ = RB.$(this);
        _.qtip(RB.$.qtipMakeOptions(_, true));
    });
  },

  refreshToolTip: function(scope) {
    scope.$.find('div.story_tooltip').each(function(el) {
        var _ = RB.$(this);
        _.qtip(RB.$.qtipMakeOptions(_));
    });
    scope.$.find('div.story_tooltip_ajax').each(function(el) {
        var _ = RB.$(this);
        _.qtip(RB.$.qtipMakeOptions(_, true));
    });
  }
}
