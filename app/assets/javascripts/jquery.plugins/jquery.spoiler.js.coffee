(($) ->
  $.fn.extend
    spoiler: ->
      @each ->
        $root = $(@)
        return unless $root.hasClass('unprocessed')
        $root.removeClass('unprocessed')

        $label = $root.children('label')
        $content = $label.next()

        $root.on 'spoiler:open', ->
          $label.click()

        $label.on 'click', (e) ->
          return if e.target != $label[0] && !$(@).closest($label).exists()

          $label.hide()
          $content.css(display: 'inline')

          $content.find('.b-prgrph').each ->
            $content.addClass 'no-cursor'
            $(@)
              .addClass('inner-prgrph')
              .removeClass('b-prgrph')
              .wrap('<div class="b-spoiler_prgrph"></div>')

          # хак для корректной работы галерей аниме внутри спойлеров
          $content.find('.align-posters').trigger('spoiler:opened')
          $content.find(".#{DynamicElements.CuttedCovers.CLASS_NAME}").each ->
            $(@).data(DynamicElements.CuttedCovers.CLASS_NAME)?.inject_css()

        $content.on 'click', (e) ->
          if e.target != $content[0] && $(e.target).parent()[0] != $content[0] &&
              !$(e.target).hasClass('inner-prgrph')
            return

          $label.css(display: 'inline')
          $content.hide()
) jQuery
