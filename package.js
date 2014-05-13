Package.describe({
	summary: "A quick and dirty inline editor similar to x-editable."
});

Package.on_use(function(api) {
	api.use(["coffeescript", "jquery", "moment"], "client");
	api.add_files("lib/utils.coffee", "client");
	api.add_files("lib/qedit.coffee", "client");
});