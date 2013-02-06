/**
 * jquery.verticalfix.js
 * Copyright (c) 2013 redmine backlogs
 *
 * based on jquery.scrollfollow.js Copyright (c) 2008 Net Perspective (http://kitchen.net-perspective.com/)
 * original author R.A. Ray
 * Licensed under the MIT License (http://www.opensource.org/licenses/mit-license.php)
 *
 * @author Patrick Atamaniuk
 *
 * @projectDescription	jQuery plugin for vertically anchor an element as the user scrolls the page.
 * 
 * @version 1.0.0
 * 
 * @requires jquery.js (tested with 1.7)
 * 
 * @param delay			int - Time between the scroll and the beginning of the fixup in milliseconds
 * 								default: 0
 */(function(a){a.verticalFix=function(b,c){function d(){var c=parseInt(a(document).scrollTop());b.initialOffsetTop>=c?(b.css("position","absolute"),b.css("top",b.initialTop),b.css("left",0)):(b.css("position","fixed"),b.css("top",0),b.css({left:b.containerLeft-a(document).scrollLeft()}))}b=a(b),b.cont=b.parent(),b.initialOffsetTop=parseInt(b.offset().top),b.initialTop=parseInt(b.css("top"))||0,b.containerLeft=b.cont.position().left||0,a(window).scroll(function(){a.fn.verticalFix.interval=setTimeout(function(){d()},c.delay)}),a(window).resize(function(){a.fn.verticalFix.interval=setTimeout(function(){d()},c.delay)}),d()},a.fn.verticalFix=function(b){return b=b||{},b.delay=b.delay||0,this.each(function(){new a.verticalFix(this,b)}),this}})(jQuery);