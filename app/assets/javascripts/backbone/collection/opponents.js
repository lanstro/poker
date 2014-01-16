var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.data={};
		this.url=$('#table').data('table_id')+'/players_info';
		this.update();
		
		console.log("opponents collection initialized");
	},
	update: function(){
		self=this;
		self.fetch({
			success: function(model, response){
				self.data=model;
			}
		});
	}
});