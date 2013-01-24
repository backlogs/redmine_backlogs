/***********************************************************/
/*                    LiveFilter Plugin                    */
/*                      Version: 1.2                       */
/*                      Mike Merritt                       */
/*             	   Updated: Apr 15th, 2010                 */
/***********************************************************/

(function($){
	$.fn.liveFilter = function (aType) {
		
		// Determine what we are going to be filtering.
		var filterTarget = $(this);
		var child;
		if ($(this).is('ul')) {
			child = 'li';
		} else if ($(this).is('ol')) {
			child = 'li';
		} else if ($(this).is('table')) {
			child = 'tbody tr';
		}
		
		// Declare variables
		var hide;
		var show;
		var filter;
        
        var getPlaceholder = function() {
            
        }    
            
		
		// Input element event
		$('input.filter').keyup(function() {
			
			// Grab the filter value
			filter = $(this).val();
			
			// Grab the ones we need to hide and the ones we need to show
			hide = $(filterTarget).find(child + ':not(:Contains("' + filter + '"))');
			show = $(filterTarget).find(child + ':Contains("' + filter + '")')
			
			// Animate the items we are hiding and showing
			if ( aType == 'basic' ) {
				hide.hide();
				show.show();
			} else if ( aType == 'slide' ) {
				hide.slideUp(500);
				show.slideDown(500);
			} else if ( aType == 'fade' ) {
				hide.fadeOut(400);
				show.fadeIn(400);
			}
			
		});		
		
		// Custom expression for case insensitive contains()
		$.expr[':'].Contains = function(a,i,m){
		    return $(a).text().toLowerCase().indexOf(m[3].toLowerCase())>=0;
		}; 

	}

})(jQuery);
