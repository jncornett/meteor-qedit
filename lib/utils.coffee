@utils = 
	# # Helpers

	# ### format
	# Replaces `{handlebars}` values within `string`
	# with
	# 
	# - positional arguments
	# - object key-values
	#
	# #### Usage:
	#     
	#     // outputs "Hello world"
	#     format("Hello {name}", {name: "world"});
	#
	#     // outputs "First, second, third"
	#     format("{}, {}, {}", "First", "second", "third");
	#
	#     // outputs "First, third, second"
	#     format("{0}, {2}, {1}", "First", "second", "third");
	#
	#     // outputs "{escaped}"
	#     format("{{escaped}}")
	#
	#     // outputs "Replace replaced, but not {B}"
	#     format("Replace {A}, but not {B}", {A: "replaced"});
	#
	format: (string, args...) ->
		index = 0
		object = if args.length is 1 and typeof args[0] is 'object'
			args[0]
		else
			args

		string.replace /{({*)([^}]*)(}*)}/g, (sub, l, key, r) ->
			if l or r
				sub.slice 1, -1
			else if key
				object[key] or sub
			else
				object[index++] or sub

	# ### curry
	# Curries a function with positional arguments.
	#
	# #### Usage:
	#
	#     f = function() { return arguments; };
	#     g = curry(f, 1, 2, 3);
	#
	#	    // outputs [1, 2, 3, 4]
	#     g(4, 5); 
	#    
	curry: (fn, args...) ->
		(args2...) ->
			fn.apply @, args.concat args2

	# ### after
	# Reverse the arguments to `setTimeout` so it's easier to use with CoffeeScript anonymous functions.
	# 
	# Instead of this:
	# 
	#     myFunction = () -> doStuff()
	#	    setTimeout myFunction, 5000
	# 
	# We can now do this:
	#
	#     after 5000, -> doStuff()
	#
	# Now that looks a hell of a lot nicer :)
	after: (timeout, fn) ->
		setTimeout fn, timeout

	# ### slice
	# Call slice on an array-like object which doesn't have a `slice` method.
	# (such as `arguments` or `HTMLElement.classList`)
	slice: (arrayLike, args...) ->
		Array.prototype.slice.call arrayLike, args...

	# ### Extendable
	# Class with the ability to `extend` itself.
	Extendable: class Extendable
		extend: (sources...) ->
			$.extend @, sources...

	# ### guid
	# Generate unique id's that are time separated. That is, two calls to `guid()` that
	# are separated in time by > 1ms are guaranteed to be different. 
	guid: (n = 7) ->
		space = Math.pow 10, n
		Date.now() * space + Math.floor Math.random() * space
		.toString 16

