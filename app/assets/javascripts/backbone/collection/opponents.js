var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.url=$('#table').data('table_id')+'/players_info';
		this.fetch();
	}
});