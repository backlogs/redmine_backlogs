$.qtipMakeOptions = function(container) {
    return {
        content: {
            text: container.attr('title')
        },
        position: {
            target: 'mouse',
            adjust: {
                x: 10,
                y: 10
            }
        },
	style : {
	    width : 500  			
	}
    }
}

$(function() {
    $('div.story_tooltip').each(function(el) {
        var _ = $(this);
        _.qtip($.qtipMakeOptions(_));
    });
});
