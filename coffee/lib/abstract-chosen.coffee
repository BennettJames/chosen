class AbstractChosen

  constructor: (@form_field, @options={}) ->
    return unless AbstractChosen.browser_is_supported()
    @is_multiple = @form_field.multiple
    this.set_default_text()
    this.set_default_values()

    this.setup()

    this.set_up_html()
    this.register_observers()

  set_default_values: ->
    @click_test_action = (evt) => this.test_active_click(evt)
    @activate_action = (evt) => this.activate_field(evt)
    @active_field = false
    @mouse_on_container = false
    @results_showing = false
    @result_highlighted = null
    @allow_single_deselect = if @options.allow_single_deselect? and @form_field.options[0]? and @form_field.options[0].text is "" then @options.allow_single_deselect else false
    @disable_search_threshold = @options.disable_search_threshold || 0
    @disable_search = @options.disable_search || false
    @enable_split_word_search = if @options.enable_split_word_search? then @options.enable_split_word_search else true
    @group_search = if @options.group_search? then @options.group_search else true
    @search_contains = @options.search_contains || false
    @single_backstroke_delete = if @options.single_backstroke_delete? then @options.single_backstroke_delete else true
    @max_selected_options = @options.max_selected_options || Infinity
    @inherit_select_classes = @options.inherit_select_classes || false
    @display_selected_options = if @options.display_selected_options? then @options.display_selected_options else true
    @display_disabled_options = if @options.display_disabled_options? then @options.display_disabled_options else true
    @search_miss_rate = if @options.search_miss_rate? then @options.search_miss_rate else 0.3 

  set_default_text: ->
    if @form_field.getAttribute("data-placeholder")
      @default_text = @form_field.getAttribute("data-placeholder")
    else if @is_multiple
      @default_text = @options.placeholder_text_multiple || @options.placeholder_text || AbstractChosen.default_multiple_text
    else
      @default_text = @options.placeholder_text_single || @options.placeholder_text || AbstractChosen.default_single_text

    @results_none_found = @form_field.getAttribute("data-no_results_text") || @options.no_results_text || AbstractChosen.default_no_result_text

  mouse_enter: -> @mouse_on_container = true
  mouse_leave: -> @mouse_on_container = false

  input_focus: (evt) ->
    if @is_multiple
      setTimeout (=> this.container_mousedown()), 50 unless @active_field
    else
      @activate_field() unless @active_field

  input_blur: (evt) ->
    if not @mouse_on_container
      @active_field = false
      setTimeout (=> this.blur_test()), 100

  results_update_field: ->
    this.set_default_text()
    this.results_reset_cleanup() if not @is_multiple
    this.result_clear_highlight()
    this.results_build()
    this.winnow_results() if @results_showing

  reset_single_select_options: () ->
    for result in @results_data
      result.selected = false if result.selected

  results_toggle: ->
    if @results_showing
      this.results_hide()
    else
      this.results_show()

  results_search: (evt) ->
    if @results_showing
      this.winnow_results()
    else
      this.results_show()

  initialize_selected_option: (option) ->
    if @is_multiple
      @choice_build option
    else
      @single_set_selected_text option.text
      

  results_option_build: ->
    frag = document.createDocumentFragment()
    for d in @results_data when @include_option_in_results(d)
      frag.appendChild(@make_option_element(d))
    return frag

  make_option_element: (option, text) ->
    newLi = document.createElement("li")
    text ||= if option.group then option.label else option.html
    newLi.innerHTML = text

    if option.group
      newLi.className = "group-result"
      return newLi  

    classes = []
    if !(option.selected and @is_multiple)
      classes.push(if option.disabled then "disable-result" else "active-result")
    classes.push "result-selected" if option.selected
    classes.push "group-option" if option.group_array_index?
    classes.push option.classes if option.classes != ""
    
    newLi.className = classes.join(" ")
    newLi.style.cssText = option.style
    newLi.setAttribute "data-option-array-index", option.array_index

    return newLi
    
  # Returns an object representing the grouped structure of option indexes.
  # The keys are indexes of optgroups and ungrouped options. The values are
  # arrays of any options that belong in a given group.
  get_groups: (data) ->
    groups = {}
    for option in data
      if @include_option_in_results(option) and not option.group_array_index?
        groups[option.array_index] ||= []
    for option in data
      if @include_option_in_results(option) and option.group_array_index?
        if groups[option.group_array_index]?
          groups[option.group_array_index].push option.array_index
    return groups

  get_matches: (data, pattern) ->
    matches = []
    searcher = @make_search_function(pattern)

    for i, groupIndexes of @get_groups(data)
      option = data[i]
      [found, text] = searcher(option)

      groupElements = [@make_option_element(option, text)]
      for j in groupIndexes
        [f, t] = searcher(data[j])
        if found or f
          groupElements.push @make_option_element(data[j], t)

      if found or groupElements.length > 1
        matches.push(el) for el in groupElements
      
    return matches

  winnow_results: ->
    searchText = @get_search_text()
    results = @get_matches(@results_data, searchText)

    @no_results_clear()
    @result_clear_highlight()

    if results.length < 1 and searchText.length
      @update_results_content("")
      @no_results(searchText)
    else
      resFragment = document.createDocumentFragment()
      resFragment.appendChild(r) for r in results

      @update_results_content(resFragment)
      @winnow_results_set_highlight()

  # Decides which search function to build. 
  make_search_function: (searchText) ->
    if @search_miss_rate > 0
      return @make_fuzzy_search(searchText)
    else
      return @make_regex_search(searchText)

  make_regex_search: (searchText) ->
    escapedSearchText = searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")
    regexAnchor = if @search_contains then "" else "^"
    regex = new RegExp(regexAnchor + escapedSearchText, 'i')
    zregex = new RegExp(escapedSearchText, 'i')

    return (option) =>
      text = option.label || option.html
      matchIndex = text.search(regex)
      
      if matchIndex < 0 and @enable_split_word_search and (
          text.indexOf(" ") >= 0 or text.indexOf("[") == 0)
        parts = text.replace(/\[|\]/g, "").split(" ")
        if parts.length
          for part in parts
            if regex.test(part)
              matchIndex = text.search(zregex)
              break

      resText = @emphasize_substr(text, matchIndex, searchText.length)
      return [matchIndex >= 0, resText]

  # Generates a function to test whether an option matches a pattern. Pass
  # in the pattern to generate the function. The resultant function returns
  # two values on being passed an option: whether or not the pattern was
  # matched in the option, and the text to display in the list if it was
  # found. 
  make_fuzzy_search: (pattern) ->
    pattern = pattern.toLowerCase()
    return (option) =>
      text = (option.label || option.html)
      [mIndex, mLen] = fuzzyTextSearch(text.toLowerCase(), pattern, @search_miss_rate)
      return [mIndex >= 0, @emphasize_substr(text, mIndex, mLen)]

  emphasize_substr: (str, index, length) ->
    return str if index < 0 || length <= 0
    return str.substr(0, index) +
      "<em>" + str.substr(index, length) + "</em>" +
      str.substr(index + length)
  
  choices_count: ->
    return @selected_option_count if @selected_option_count?

    @selected_option_count = 0
    for option in @form_field.options
      @selected_option_count += 1 if option.selected
    
    return @selected_option_count

  choices_click: (evt) ->
    evt.preventDefault()
    this.results_show() unless @results_showing or @is_disabled

  keyup_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    switch stroke
      when 8
        if @is_multiple and @backstroke_length < 1 and this.choices_count() > 0
          this.keydown_backstroke()
        else if not @pending_backstroke
          this.result_clear_highlight()
          this.results_search()
      when 13
        evt.preventDefault()
        this.result_select(evt) if this.results_showing
      when 27
        this.results_hide() if @results_showing
        return true
      when 9, 38, 40, 16, 91, 17
        # don't do anything on these keys
      else this.results_search()

  container_width: ->
    return if @options.width? then @options.width else "#{@form_field.offsetWidth}px"

  include_option_in_results: (option) ->
    return false if @is_multiple and (not @display_selected_options and option.selected)
    return false if not @display_disabled_options and option.disabled
    return false if option.empty

    return true

  search_results_touchstart: (evt) ->
    @touch_started = true
    this.search_results_mouseover(evt)

  search_results_touchmove: (evt) ->
    @touch_started = false
    this.search_results_mouseout(evt)

  search_results_touchend: (evt) ->
    this.search_results_mouseup(evt) if @touch_started

  # class methods and variables ============================================================ 

  @browser_is_supported: ->
    if window.navigator.appName == "Microsoft Internet Explorer"
      return document.documentMode >= 8
    if /iP(od|hone)/i.test(window.navigator.userAgent)
      return false
    if /Android/i.test(window.navigator.userAgent)
      return false if /Mobile/i.test(window.navigator.userAgent)
    return true

  @default_multiple_text: "Select Some Options"
  @default_single_text: "Select an Option"
  @default_no_result_text: "No results match"

