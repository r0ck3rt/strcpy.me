$(document).ready(function(){
    
    /**
     * Responsive Navigation
     */ 
    $('#menu-toggle').on('click', function(e){

        $('.g-nav').slideToggle(200);

        $(document).one('click', function(){
            $('.g-nav').slideUp(200);
        });

        e.stopPropagation();
    });

    $('.g-nav').on('click', function(e){
        e.stopPropagation();
    });
    
    /*
    *  Header Bar
    */

    /*
    * Post Cover Resize
    */
    function postCover(img, container) {
        var imgWidth = img.width(),
            containerWidth = container.width(),
            imgHeight = img.height(),
            containerHeight = container.height();
        var isOk = false;
        if(imgHeight < containerHeight) {
            img.css({
                'width': 'auto',
                'height': '100%'
            });
            imgWidth = img.width(),
            containerWidth = container.width();
            var marginLeft = (imgWidth - containerWidth) / 2;
            img.css('margin-left', '-' + marginLeft + 'px');
            isOk = true;
        } else {
            var marginTop = (containerHeight - imgHeight) / 2;
            img.css('margin-top', marginTop + 'px');
            isOk = true;
        }

        if(isOk) {
            img.fadeIn();
            isOk = false;
        }
    }

    /**
     * The Post Navigator
     */
    $('.read-next-item section').each(function(){
        var _this = $(this),
            n = _this.height(),
            rn = $('.read-next-item').height();
        _this.css('margin-top', (rn-n)/2 + 'px');
        _this.fadeIn();
    });

    $('.read-next-item img').each(function(){
        var _this = $(this);
        postCover(_this, $('.read-next-item'));
    });

    /**
     * Search
     */  
    function Search() {
        var self = this,
            input = $('#search_input');
        result = $('.search_result');
        
        input.focus(function() {
            $('.icon-search').css('color', '#3199DB');
        });
    }
    new Search();
    
});
