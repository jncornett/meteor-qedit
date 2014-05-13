encapsulate = ($, window) ->
	pluginName = 'qedit'
	$ = jQuery

	# # Constants

	# ### Bootstrap
	# Default fade transition time for Bootstrap's `.fade`
	FADE_TIME_MS = 150

	# ### KeyCodes
	KEYCODE_ESCAPE = 27
	KEYCODE_ENTER = 13

	# ### Events
	# This plugin makes several hooks available:
	# 
	# - `qedit.before.open` and `qedit.after.open`
	#     - Triggered before and after the widget opens
	#     - Callback: `function(event, pluginObject)`
	# - `qedit.before.close` and `qedit.after.close`
	#     - Triggered before and after the widget closes
	#       due to an `qedit.ok` or `qedit.cancel` event.
	#     - Callback: `function(event, pluginObject, mode)` 
	#       where `mode` is either "ok" or "cancel".

	BEFORE_OPEN_EVENT = "#{pluginName}.before.open"
	AFTER_OPEN_EVENT = "#{pluginName}.after.open"
	BEFORE_CLOSE_EVENT = "#{pluginName}.before.close"
	AFTER_CLOSE_EVENT = "#{pluginName}.after.close"
	TRIGGER_OPEN = "#{pluginName}.open"
	TRIGGER_OK = "#{pluginName}.ok"
	TRIGGER_CANCEL = "#{pluginName}.cancel"

	# ### Widget specific constants
	DEFAULT_TEMPLATE = "
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

	# The format of input date's `value` property
	INPUT_DATE_FORMAT = "YYYY-MM-DD"
	INPUT_MONTH_FORMAT = "YYYY-MM"

	# # Helpers

	{format, curry, after, slice, Extendable, guid} = utils

	# # Classes

	# ## Base
	# All widgets descend from this class
	class Base extends Extendable
		template: DEFAULT_TEMPLATE
		defaults:
			widget: null

		# ### constructor
		constructor: (@el, options) ->
			@cache = new Extendable
			$el = @cache.$el = $ @el
			@extend @defaults, $el.data(), options

			@oldClasses = slice @el.classList, 0
			@build()
			@attachCallbacks()

			$el.data "#{pluginName}-data", @

		# ### build
		build: ->
			$el = @cache.$el
			$edit = @cache.$edit = $ format @template, @
			.insertAfter $el

			@cache.extend
				$widget: $edit.find ".#{pluginName}-widget"
				$ok: $edit.find ".#{pluginName}-ok"
				$cancel: $edit.find ".#{pluginName}-cancel"

			$el.addClass "fade in"

		# ### destroy
		destroy: ->
			# Remove any classes that were applied to `el` by
			# this plugin.
			# Any classes added to `el` (by this plugin, or 
			# by any other code) after initializing will be
			# removed. Set the `doNotRevert` option to `true`
			# to avoid this behavior. 
			if not @doNotRevert
				@el.className = @oldClasses.join ' '

			# Remove all callbacks attached to `el` and the 
			# document. We don't have to worry about the callbacks 
			# attached to any created elements as we'll be removing
			# those next...
			@detachCallbacks()

			# Remove the created element from the DOM
			@cache.$edit.remove()

			# Remove `this` from `el` data.
			@cache.$el.removeData "#{pluginName}-data"

		# ### attachCallbacks
		attachCallbacks: ->
			self = @
			{$el, $edit, $widget, $ok, $cancel} = @cache
			fxQueue = @fxQueue
			$window = $ window

			trigger = (eventName, args...) ->
				$el.trigger eventName, args

			# __Trigger helpers:__
			_before_open = curry trigger, BEFORE_OPEN_EVENT
			_after_open = curry trigger, AFTER_OPEN_EVENT
			_before_close = curry trigger, BEFORE_CLOSE_EVENT
			_after_close = curry trigger, AFTER_CLOSE_EVENT
			_open = curry trigger, TRIGGER_OPEN
			_ok = curry trigger, TRIGGER_OK
			_cancel = curry trigger, TRIGGER_CANCEL

			# __Misc:__
			@detachWindowCallbacks = _detach_window_callbacks = ->
				# We call `off()` with functions as arguments so that
				# other widgets with the same plugin can safely
				# use the same namespace.			
				$window
				.off "click.#{pluginName}", _ok
				.off "click.#{pluginName}", _cancel

			close = (callback) ->
				$edit.removeClass "in"

				after FADE_TIME_MS, ->
					$edit.hide()
					$el
					.show()
					.addClass "in"

					after FADE_TIME_MS, ->
						callback()

			# __Event Handlers:__
			onOpen = ->
				switch self.dismissOnClickOutside
					when 'save'
						$window.on "click.#{pluginName}", _ok
					when 'cancel'
						$window.on "click.#{pluginName}", _cancel

				_before_open self
	
				self.setWidgetValue()

				$el
				.one TRIGGER_OK, onOk
				.one TRIGGER_CANCEL, onCancel

				$el
				.removeClass "in"
				
				after FADE_TIME_MS, ->
					$el.hide()
					$edit
					.show()
					.addClass "in"

					after FADE_TIME_MS, ->
						_after_open self

			onOk = ->
				# Stop listening for the other events
				_detach_window_callbacks()
				$el.off TRIGGER_CANCEL

				_before_close self, 'ok'
				self.saveCallback.call self, self.getWidgetValue()
				close -> _after_close self, 'ok'

			onCancel = ->
				# Stop listening for the other events
				_detach_window_callbacks()	
				$el.off TRIGGER_OK

				_before_close self, 'cancel'
				close -> _after_close self, 'cancel'

			# __Attachment:__
			$el.on TRIGGER_OPEN, onOpen

			$edit
			.on "click.#{pluginName}", (e) -> e.stopPropagation()

			$ok
			.on "click.#{pluginName}", _ok

			$cancel
			.on "click.#{pluginName}", _cancel

			$el
			.on "click.#{pluginName}", (e) -> e.stopPropagation()
			.on "click.#{pluginName}", _open

			if self.cancelOnEscape
				$edit
				.on "keydown.#{pluginName}", (e) ->
					_cancel() if e.which is KEYCODE_ESCAPE

			if self.saveOnEnter
				$edit
				.on "keydown.#{pluginName}", (e) ->
					_ok() if e.which is KEYCODE_ENTER

		# ### detachCallbacks
		detachCallbacks: ->
			$el
			.off "click.#{pluginName}"
			.off [TRIGGER_OPEN, TRIGGER_OK, TRIGGER_CANCEL].join ' '
			.off [BEFORE_OPEN_EVENT, AFTER_OPEN_EVENT, BEFORE_CLOSE_EVENT, AFTER_CLOSE_EVENT].join ' '
			@detachWindowCallbacks()

		# ### getWidgetValue
		getWidgetValue: -> 
			@cache.$widget.val()

		# ### setWidgetValue
		setWidgetValue: ->
			@cache.$widget.val @cache.$el.text()

		# ### method
		method: (name, options) ->
			@[name] options

		open: ->
			@cache.$el.trigger TRIGGER_OPEN

		save: ->
			@cache.$el.trigger TRIGGER_OK

		close: ->
			@cache.$el.trigger TRIGGER_CANCEL

	# ## InputText
	class InputText extends Base
		defaults:
			widget: "<input type='text' class='form-control #{pluginName}-widget' />"

		attachCallbacks: ->
			super()
			$widget = @cache.$widget
			@cache.$el
			.on AFTER_OPEN_EVENT, ->
				$widget.focus().select()

	# ## Select
	class Select extends Base
		defaults:
			widget: "<select class='form-control #{pluginName}-widget'></select>"
			itemWidget: "<option value='{value}'>{text}</text>"
			saveOnSelect: false

		build: ->
			super()
			@populate @source

		populate: (data, callback) ->
			if typeof data is 'string'
				cb = (data) =>
					@populate data, callback

				$.getJSON data, cb
			else if Array.isArray data
				$widget = @cache.$widget
				_template = @itemWidget
				for item in data
					do (item) ->
						$widget.append format _template,
							value: item.value or item
							text: item.text or item

				callback() if callback?
			else if data?
				{data, callback} = data
				@populate data, callback

		attachCallbacks: ->
			super()
			if @saveOnSelect
				{$widget, $el} = @cache
				$widget.on "change.#{pluginName}", ->
					$el.trigger TRIGGER_OK

	# ## List
	class List extends Base
		defaults:
			widget: "<input type='text' class='form-control #{pluginName}-widget' list='{listId}' />
				<datalist id='{listId}'></datalist>"
			itemWidget: "<option label='{text}' value='{value}'>"
			saveOnSelect: false

		constructor: (el, options) ->
			@uuid = guid()
			@defaults.widget = format @defaults.widget, listId: "#{pluginName}-list-#{@uuid}"
			super el, options

		build: ->
			super()
			@cache.$list = $ "##{pluginName}-list-#{@uuid}"
			@populate @source

		populate: (data, callback) ->
			if typeof data is 'string'
				cb = (data) =>
					@populate data, callback

				$.getJSON data, cb

			else if Array.isArray data
				$list = @cache.$list
				_template = @itemWidget
				for item in data
					do (item) ->
						$list.append format _template,
							value: item.value or item
							text: item.text or item

				callback() if callback?

			else if data?
				{data, callback} = data
				@populate data, callback

		attachCallbacks: ->
			super()
			if @saveOnSelect
				{$widget, $el} = @cache
				$widget.on "input.#{pluginName}", ->
					$el.trigger TRIGGER_OK

	# ## InputDate
	class InputDate extends Base
		defaults:
			widget: "<input type='date' class='form-control #{pluginName}-widget' />"
			widgetFormat: INPUT_DATE_FORMAT
			format: INPUT_DATE_FORMAT

		build: ->
			super()
			@viewformat ?= @format
			@saveformat ?= @format

		setWidgetValue: ->
			formatted = moment @cache.$el.text(), @viewformat
			.format @widgetFormat
			@cache.$widget.val formatted

		getWidgetValue: ->
			moment @cache.$widget.val(), @widgetFormat
			.format @saveformat

	class InputMonth extends InputDate
		defaults:
			widget: "<input type='month' class='form-control #{pluginName}-widget' />"
			widgetFormat: INPUT_MONTH_FORMAT
			format: INPUT_MONTH_FORMAT

	# # Initialization
	# Initialize the jQuery plugin
	initPlugin = ->
		$.fn[pluginName] = (options, options2 = null) ->
			self = @

			if typeof options is 'string'
				@each ->
					if helper = $(self).data("#{pluginName}-data")
						helper.method options, options2
			else
				options = $.extend {}, $.fn[pluginName].defaults, options
				@each ->
					type = @getAttribute('data-type') or options.type
					new $.fn[pluginName].widgets[type] @, options

		$.extend $.fn[pluginName],
			widgets:
				text: InputText
				select: Select
				list: List
				date: InputDate
				month: InputMonth

			baseClass: Base
			extendable: Extendable

			registerWidget: (type, klass) ->
				@widgets[type] = klass

			defaults:
				dismissOnClickOutside: "cancel"
				saveOnEnter: true
				cancelOnEscape: true
				saveCallback: (value) ->
					console.log "saveCallback called with value #{value}"

	if Meteor?
		Meteor.startup -> initPlugin()

encapsulate jQuery, window