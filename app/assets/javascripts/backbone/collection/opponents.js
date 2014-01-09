var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player
});