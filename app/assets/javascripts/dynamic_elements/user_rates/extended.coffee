using 'DynamicElements.UserRates'
class DynamicElements.UserRates.Extended extends DynamicElements.UserRates.Button
  EXTENDED_TEMPLATE = 'templates/user_rates/extended'
  SCORE_TEMPLATE = 'templates/user_rates/score'

  initialize: ->
    @entry = @$root.data('entry')
    @form_html = null

    @on 'click', '.cancel', @_hide_form

    @on 'ajax:success', '.remove', @_hide_form
    @on 'ajax:success', '.rate-edit', @_hide_form
    @on 'rate:change', @_change_score

    super

  # handlers
  _toggle_list: (e) =>
    if @_is_persisted() && e.currentTarget.classList.contains('edit-trigger')
      if @form_html
        @_hide_form()
      else
        @_fetch_form()
    else
      super

  _fetch_form: ->
    @_ajax_before()
    $.get("/user_rates/#{@user_rate.id}/edit")
      .complete(@_ajax_complete)
      .success(@_show_form)

  _show_form: (html) =>
    @form_html = html
    @_render()
    @$('.remove-container.bottom').addClass 'hidden'
    @$('.remove-container.top').removeClass 'hidden'

  _hide_form: =>
    @form_html = null
    @_render()

  _change_score: (e, score) =>
    @$('input[name="user_rate[score]"]').val score
    @$('form').submit()

  # functions
  _extended_html: ->
    @form_html || @_render_extended() if @_is_persisted()

  _render_extended: ->
    JST[EXTENDED_TEMPLATE](
      entry: @entry
      user_rate: @user_rate
      increment_url: "/api/v2/user_rates/#{@user_rate.id}/increment" if @_is_persisted()
      rate_html: JST[SCORE_TEMPLATE](score: @user_rate.score)
    )

  _render: ->
    super
    @$('.b-rate').rateable()