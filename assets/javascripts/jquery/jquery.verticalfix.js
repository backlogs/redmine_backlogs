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
 */

( function( $ ) {
	
	$.verticalFix = function ( box, options )
	{ 
		// Convert box into a jQuery object
		box = $( box );
		
		function ani()
		{		
			// The script runs on every scroll which really means many times during a scroll.
			// A bunch of values we need to determine where to animate to
			var pageScroll =  parseInt( $( document ).scrollTop() );
			
      // Don't fix until the top of the window is close enough to the top of the box
      if ( box.initialOffsetTop >= ( pageScroll ) ) {
        box.css('position', 'absolute');
        box.css('top', box.initialTop);
        box.css('left', 0);
      }
      else {
        box.css('position', 'fixed');
        box.css('top', 0);
        box.css({'left': box.containerLeft - $(document).scrollLeft() });
      }
		};
		
		// container for left positioning
    box.cont = box.parent();
		
		// Finds the default positioning of the box.
		box.initialOffsetTop =  parseInt( box.offset().top );
		box.initialTop = parseInt( box.css( 'top' ) ) || 0;
		box.containerLeft = box.cont.position().left || 0;
		
		// Animate the box when the page is scrolled
		$( window ).scroll( function () {
				$.fn.verticalFix.interval = setTimeout( function(){ ani();} , options.delay );
    });
		
		// Animate the box when the page is resized
		$( window ).resize( function () {
				$.fn.verticalFix.interval = setTimeout( function(){ ani();} , options.delay );
    });
		
		ani();
	};
	
	$.fn.verticalFix = function ( options ) {
		options = options || {};
		options.delay = options.delay || 0;
		
		this.each( function() 
			{
				new $.verticalFix( this, options );
			}
		);
		
		return this;
	};
})( jQuery );



