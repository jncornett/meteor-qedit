pluginName = 'qedit'

FADE_TIME_MS = 150
KEYCODE_ESCAPE = 27
KEYCODE_ENTER = 13

OPEN_EVENT = "#{pluginName}.open"
DISMISS_EVENT = "#{pluginName}.dismiss"
SAVE_EVENT = "#{pluginName}.save"
CLOSE_EVENT = "#{pluginName}.close"

DATE_FORMAT = "YYYY-MM-DD"

format = (string, args...) ->
	index = 0
	object = args[0]
	string.replace /{({*)([\w$]*)(}*)}/g, (sub, l, key, r) ->
		if l or r
			sub.slice 1, -1
		else if not key
			args[index++] or sub
		else
			object[key] or sub

curry = (fn, args...) ->
	(args2...) ->
		fn.apply @, args.concat(args2)

close = (fn, args...) ->
	() ->
		fn.apply @, args

# ## Base
# All editable widgets inherit from this class
class Base
	DEFAULTS: 
		widget: null

	template: "
	  <div class='input-group input-group-sm #{pluginName}-edit fade'>
	  	{widget}
	  	<div class='input-group-btn'>
	  		<button type='button' class='btn btn-primary #{pluginName}-ok'>
	  			<span class='glyphicon glyphicon-ok'></span>
	  		</button>
	  		<button type='button' class='btn btn-default #{pluginName}-cancel'>
	  			<span class='glyphicon glyphicon-remove'></span>
	  		</button>
	  	</div>
	  </div>
		"

	constructor: (@el, options) ->
		@cache =
			$view: $ @el

		@options = $.extend {}, @DEFAULTS, options

		# Note: Any classes added by external code after initialization
		# will also be removed on a call to `destroy()`. `@oldClasses`
		# only saves the classes attached to the element at initialization time.
		@oldClasses = Array.prototype.slice.call @el.classList, 0
		@getData()
		@constructWidget()
		@attachCallbacks()

	getData: ->
		# Get the settings from the data object
		@data = @cache.$view.data()

	constructWidget: ->
		$view = @cache.$view
		$edit = @cache.$edit = $ format @template, @options
		$view.after $edit
		@cache.$widget = $edit.find ".#{pluginName}-widget"
		@cache.$ok = $edit.find ".#{pluginName}-ok"
		@cache.$cancel = $edit.find ".#{pluginName}-cancel"
		#Attach self to `$edit` data
		$view.data "#{pluginName}", @

		$view.addClass "fade in"

	destroy: ->
		# 1. Remove any classes applied to `el`.
		@el.className = @oldClasses.join ' '
		# 2. Remove any event bindings from `$view`.
		@detachCallbacks()
		# 3. Remove any data from `$view`.
		$view.removeData "#{pluginName}"
		# 2. Remove `$edit`.
		$edit.remove()

	attachCallbacks: -> 
		self = @
		{$view, $edit, $widget, $ok, $cancel} = @cache

		{dismissOnClickOutside,
		 dismissOnEscape,
		 dismissOnLoseFocus,
		 saveOnDismiss,
		 saveOnEnter,
		 saveCallback} = @options

		trigger = (event, data) -> $view.trigger event, data

		_open = close trigger, OPEN_EVENT
		_dismiss = close trigger, DISMISS_EVENT
		_save = curry trigger, SAVE_EVENT
		_close = close trigger, CLOSE_EVENT

		#_dismiss = ->
		#	$view.trigger DISMISS_EVENT

		onPluginOpen = ->
			$view.one DISMISS_EVENT, onPluginDismiss

			$view
			.removeClass "in"
			.delay FADE_TIME_MS
			.hide()

			$edit
			.delay FADE_TIME_MS
			.show()
			.addClass "in"

			try
				$widget
				.val $view.text()
				.focus()
				.select()
			catch e
				null

			if dismissOnClickOutside
				$ window
				.on "click.#{pluginName}", _dismiss

		onPluginDismiss = ->
			if saveOnDismiss
				_save [self.getValue()]

			_close()

		onPluginSave = (e, value) ->
			saveCallback.call self, e, value

		onPluginClose = ->
			$edit
			.removeClass "in"
			.delay FADE_TIME_MS
			.hide()

			$view
			.delay FADE_TIME_MS
			.show()
			.addClass "in"

			$ window
			.off "click.#{pluginName}", _dismiss

		saveAndClose = ->
			_save [self.getValue()]
			_close()

		$view.on OPEN_EVENT, onPluginOpen
		$view.on SAVE_EVENT, onPluginSave
		$view.on CLOSE_EVENT, onPluginClose

		$view.on "click.#{pluginName}", (e) -> e.stopPropagation()
		$edit.on "click.#{pluginName}", (e) -> e.stopPropagation()

		if dismissOnLoseFocus
			$widget.on "blur.#{pluginName}", _dismiss

		if dismissOnEscape
			$edit.on "keydown.#{pluginName}", (e) ->
				_dismiss() if e.which is KEYCODE_ESCAPE

		if saveOnEnter
			$edit.on "keydown.#{pluginName}", (e) ->
				saveAndClose() if e.which is KEYCODE_ENTER

		$ok.on "click.#{pluginName}", saveAndClose
		$cancel.on "click.#{pluginName}", _close
		$view.on "click.#{pluginName}", _open

	detachCallbacks: ->
		$view.off [OPEN_EVENT, CLOSE_EVENT, SAVE_EVENT, DISMISS_EVENT].join " "
		$view.off "click.#{pluginName}"

	getValue: ->
		@cache.$widget.val()

class InputText extends Base
	DEFAULTS:
		widget: "<input type='text' class='form-control #{pluginName}-widget' />"

class Select extends Base
	DEFAULTS:
		widget: "<select class='form-control #{pluginName}-widget'></select>"
		widgetItem: "<option value='{value}'>{text}</option>"

	getData: ->
		super()

		self = @

		if 'source' not of @data
			@data.source = @options.source

	constructWidget: ->
		super()
		if Array.isArray @data.source
			@data.items = @data.source
			@populateSelect()
		else
			$.getJSON @data.source, @populateSelect.bind @

	populateSelect: (data) -> 
		@data.items = if Array.isArray data then data else []
		$widget = @cache.$widget
		template = @options.widgetItem
		@data.items.forEach (item) ->
			$widget.append format template, 
				value: item.value or item
				text: item.text or item

class InputDate extends Base
	DEFAULTS:
		widget: "<input type='date' class='form-control #{pluginName}-widget' />"

	getData: ->
		super()
		@data.viewformat ?= @data.format
		@data.saveformat ?= @data.format

	getValue: ->
		m = moment @cache.$widget.val(), DATE_FORMAT
		.format @data.saveformat


Meteor.startup ->
	jQuery.fn[pluginName] = (options, options2 = null) ->
		if typeof options is "string"
			@each ->
				if helper = @.data "#{pluginName}"
					helper.cmd options, options2

		else
			options = $.extend {}, jQuery.fn[pluginName].DEFAULTS, options
			@each ->
				type = @getAttribute("data-type") or options.type
				new options.types[type] @, options


	jQuery.fn[pluginName].DEFAULTS =
		saveCallback: (event, value) ->
			@cache.$view.text value

		readyCallback: (source) -> null
		saveOnDismiss: false
		saveOnEnter: true

		# Note: this setting can be problematic.
		# If the user clicks the OK button, the dismiss event
		# is triggered prior to the click event. If `saveOnDismiss`
		# is `true`, the save callback will be called twice
		dismissOnLoseFocus: false
		dismissOnClickOutside: true
		dismissOnEscape: true

		saveOnSelect: false

		types:
			text: InputText
			select: Select
			date: InputDate