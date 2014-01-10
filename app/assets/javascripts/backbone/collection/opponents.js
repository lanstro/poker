var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.data={},
		this.url=$('#table').data('table_id')+'/players_info'
	},
	update: function(){
		self=this;
		self.fetch({
			success: function(model, response){
				self.data=model;
				self.trigger("opponents:updated");
			}
		});
	}
});