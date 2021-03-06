csrf = require 'helpers/csrf'
I18N_KEY = 'frontend.lib.jquery_shiki_file'

(($) ->
  defaults =
    maxfiles: 150
    progress: null
    input: null

  global_lock = false

  $.fn.extend
    shikiFile: (opts) ->
      @each ->

        options = $.extend {}, defaults, opts
        $node = $ @

        # плейсхолдер того места, куда будет класться файл
        $placeholder = null

        # прогресс-бар
        $progress_container = $(options.progress)
        $progress_bar = $progress_container.children()

        $input = $(options.input)
        # выбор файла в инпуте - триггер файлдропа
        $input.change ->
          if @files.length > 0
            $node.trigger 'drop', [@files]

        csrf_tokens = csrf()
        $node.filedrop
          #fallback_id: 'upload_button',    # an identifier of a standard file input element
          url: $node.data('upload_url'),   # upload handler, handles each file separately
          paramname: 'image',      # POST parameter name used on serverside to reference file
          data: csrf_tokens.post,
          headers: csrf_tokens.headers,
          error: (err, file) ->
            switch err
              when 'TooManyFiles'
                $.flash alert: I18n.t("#{I18N_KEY}.too_many_files", count: options.maxfiles)

              when 'FileTooLarge'
                $.flash alert: I18n.t("#{I18N_KEY}.too_large_file")

              when 'Unprocessable Entity'
                $.flash alert: I18n.t("#{I18N_KEY}.please_try_again_later")

              #when 'BrowserNotSupported'
              else
                $.flash alert: I18n.t("#{I18N_KEY}.browser_not_supported")

            global_lock = false

          maxfiles: options.maxfiles,
          maxfilesize: 4, # max file size in MBs
          queuefiles: 1
          refresh: 50

          beforeEach: (file) ->
            #$progress_bar.width '0%'
            filename = file.name
            filesize = Math.ceil(file.size / 10) / 100
            $progress_bar.html(
              I18n.t "#{I18N_KEY}.loading_file",
                filename: filename,
                filesize: filesize
            )

          drop: ->
            return false if global_lock
            global_lock = true
            $node.trigger 'upload:before'
            $(document.body).trigger 'dragleave'

            $progress_container.addClass 'active'

          afterAll: ->
            $node.trigger 'upload:after'
            global_lock = false

            $progress_container.removeClass 'active'
            delay(250).then -> $progress_bar.width '0%'

          docOver: (e) ->
            return if $node.data('placeholder_displayed') || !$node.is(':visible')

            $node.data placeholder_displayed: true

            height = $node.outerHeight()
            width = $node.outerWidth()
            text =
              if global_lock
                I18n.t("#{I18N_KEY}.wait_till_loaded")
              else
                I18n.t("#{I18N_KEY}.drop_pictures_here")
            cls = if global_lock then 'disallowed' else 'allowed'

            $placeholder = $("<div data-text='#{text}' class='b-dropzone-drag_placeholder #{cls}' style='width:#{width}px!important;height:#{height}px;line-height:#{Math.max(height, 75)}px;'></div>")
              .css(opacity: 0)
              .on('drop', (e) -> $node.trigger e)
              .on('dragenter', -> $(@).addClass 'hovered')
              .on('dragleave', -> $(@).removeClass 'hovered')
              .insertBefore($node)

            delay().then -> $placeholder.css opacity: 0.75

          docLeave: (e) ->
            return unless $node.data 'placeholder_displayed'

            $placeholder = $node.parent()
              .find('.b-dropzone-drag_placeholder')
              .css(opacity: 0)

            delay(350).then -> $placeholder.remove()
            $node.data placeholder_displayed: false

          uploadStarted: (i, file, len) ->
            $node.trigger 'upload:started', i
            #$.cursorMessage()
            #$progress_bar.html 'загрузка файла...'

          uploadFinished: (i, file, response, time) ->
            if Object.isString(response) || 'error' of response
              $node.trigger 'upload:failed', [response, i]
              alert =
                if Object.isString(response)
                  I18n.t("#{I18N_KEY}.please_try_again_later")
                else
                  response.error
              $.flash alert: alert
            else
              $node.trigger 'upload:success', [response, i]
            #$.hideCursorMessage()

          progressUpdated: (i, file, progress) ->
            if progress > 85 || i > 0
              #$progress_bar.html 'загрузка на картинкохостинг...'
              $progress_bar.width '100%'
            else
              $progress_bar.width progress+'%'
)(jQuery)
